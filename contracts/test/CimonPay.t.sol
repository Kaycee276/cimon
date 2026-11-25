// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {CimonRegistry} from "../src/CimonRegistry.sol";
import {CimonPay} from "../src/CimonPay.sol";
import {ICimonRegistry} from "../src/interfaces/ICimonRegistry.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {NoReturnERC20} from "./mocks/NoReturnERC20.sol";
import {FalseReturnERC20} from "./mocks/FalseReturnERC20.sol";
import {FeeOnTransferERC20} from "./mocks/FeeOnTransferERC20.sol";
import {ReentrantERC20} from "./mocks/ReentrantERC20.sol";

contract CimonPayTest is Test {
    CimonRegistry internal registry;
    CimonPay internal pay;
    MockERC20 internal token;

    address internal owner = makeAddr("owner");
    address internal attestor = makeAddr("attestor");
    address internal merchant = makeAddr("merchant");
    address internal payer = makeAddr("payer");
    address internal acme = makeAddr("acme"); // verified payee
    address internal stranger = makeAddr("stranger");

    uint256 internal constant AMOUNT = 250e6; // 250 tUSD8
    uint256 internal constant DELAY = 900; // 15 minutes
    uint256 internal constant T0 = 1_800_000_000;
    string internal constant ACME = "Acme Corp Ltd";

    function setUp() public {
        vm.warp(T0);

        vm.startPrank(owner);
        registry = new CimonRegistry(owner);
        token = new MockERC20();
        pay = new CimonPay(IERC20(address(token)), ICimonRegistry(address(registry)));
        registry.setRecorder(address(pay), true);
        registry.setAttestor(attestor, true);
        vm.stopPrank();

        token.mint(payer, 10_000e6);
        vm.prank(payer);
        token.approve(address(pay), type(uint256).max);

        vm.prank(acme);
        registry.registerPayee(ACME, "Acme Labs", "acmelabs.com", keccak256("RC-1"));
        vm.prank(attestor);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.VERIFIED_BUSINESS);
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function _invoice(uint256 delay) internal returns (bytes32 id) {
        vm.prank(merchant);
        id = pay.createInvoiceWithName(acme, AMOUNT, "Order #1001", delay, ACME);
    }

    function _pay(bytes32 id) internal {
        vm.prank(payer);
        pay.payInvoice(id);
    }

    function _status(bytes32 id) internal view returns (CimonPay.InvoiceStatus) {
        return pay.getInvoice(id).status;
    }

    function _risk(bytes32 id) internal view returns (CimonPay.RiskLevel) {
        return pay.copCheck(id).risk;
    }

    // ------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------

    function test_constructor_setsImmutables() public view {
        assertEq(address(pay.token()), address(token));
        assertEq(address(pay.registry()), address(registry));
    }

    function test_constructor_revertsOnZeroAddresses() public {
        vm.expectRevert(CimonPay.ZeroAddress.selector);
        new CimonPay(IERC20(address(0)), ICimonRegistry(address(registry)));
        vm.expectRevert(CimonPay.ZeroAddress.selector);
        new CimonPay(IERC20(address(token)), ICimonRegistry(address(0)));
    }

    // ------------------------------------------------------------------
    // Invoice creation
    // ------------------------------------------------------------------

    function test_createInvoice_storesAllFields() public {
        bytes32 id = _invoice(DELAY);
        CimonPay.Invoice memory inv = pay.getInvoice(id);

        assertEq(inv.id, id);
        assertEq(inv.merchant, merchant);
        assertEq(inv.expectedPayee, acme);
        assertEq(inv.amount, AMOUNT);
        assertEq(inv.memo, "Order #1001");
        assertEq(inv.safetyDelay, DELAY);
        assertEq(inv.paidAt, 0);
        assertEq(uint8(inv.status), uint8(CimonPay.InvoiceStatus.PENDING));
        assertEq(inv.actualPayer, address(0));
        assertEq(pay.getExpectedName(id), ACME);
    }

    function test_createInvoice_specSignatureHasNoExpectedName() public {
        vm.prank(merchant);
        bytes32 id = pay.createInvoice(acme, AMOUNT, "No name", 0);
        assertEq(pay.getExpectedName(id), "");
        assertEq(pay.getInvoice(id).merchant, merchant);
    }

    function test_createInvoice_emitsEvent() public {
        bytes32 expectedId = keccak256(abi.encode(block.chainid, address(pay), merchant, uint256(0)));
        vm.expectEmit(true, true, true, true);
        emit CimonPay.InvoiceCreated(expectedId, merchant, acme, AMOUNT, DELAY, "Order #1001", ACME);
        vm.prank(merchant);
        bytes32 id = pay.createInvoiceWithName(acme, AMOUNT, "Order #1001", DELAY, ACME);
        assertEq(id, expectedId);
    }

    function test_createInvoice_uniqueIdsAndNonce() public {
        bytes32 a = _invoice(0);
        bytes32 b = _invoice(0);
        assertTrue(a != b);
        assertEq(pay.merchantNonce(merchant), 2);

        vm.prank(stranger);
        bytes32 c = pay.createInvoice(acme, AMOUNT, "x", 0);
        assertTrue(c != a && c != b);
    }

    function test_createInvoice_revertsOnZeroPayee() public {
        vm.prank(merchant);
        vm.expectRevert(CimonPay.ZeroAddress.selector);
        pay.createInvoice(address(0), AMOUNT, "x", 0);
    }

    function test_createInvoice_revertsWhenPayeeIsThisContract() public {
        vm.prank(merchant);
        vm.expectRevert(CimonPay.ZeroAddress.selector);
        pay.createInvoice(address(pay), AMOUNT, "x", 0);
    }

    function test_createInvoice_revertsOnZeroAmount() public {
        vm.prank(merchant);
        vm.expectRevert(CimonPay.ZeroAmount.selector);
        pay.createInvoice(acme, 0, "x", 0);
    }

    function test_createInvoice_safetyDelayBounds() public {
        vm.startPrank(merchant);
        vm.expectRevert(CimonPay.InvalidSafetyDelay.selector);
        pay.createInvoice(acme, AMOUNT, "x", 1);
        vm.expectRevert(CimonPay.InvalidSafetyDelay.selector);
        pay.createInvoice(acme, AMOUNT, "x", 59);
        vm.expectRevert(CimonPay.InvalidSafetyDelay.selector);
        pay.createInvoice(acme, AMOUNT, "x", 7 days + 1);

        pay.createInvoice(acme, AMOUNT, "x", 0);
        pay.createInvoice(acme, AMOUNT, "x", 60);
        pay.createInvoice(acme, AMOUNT, "x", 7 days);
        vm.stopPrank();
    }

    function test_createInvoice_memoAndNameLimits() public {
        vm.startPrank(merchant);
        pay.createInvoiceWithName(acme, AMOUNT, _repeat("m", 280), 0, _repeat("n", 128));

        vm.expectRevert(CimonPay.MemoTooLong.selector);
        pay.createInvoice(acme, AMOUNT, _repeat("m", 281), 0);
        vm.expectRevert(CimonPay.NameTooLong.selector);
        pay.createInvoiceWithName(acme, AMOUNT, "x", 0, _repeat("n", 129));
        vm.stopPrank();
    }

    function test_createInvoice_revertsForFlaggedPayee() public {
        vm.prank(attestor);
        registry.setFlagged(stranger, true, "scam");
        vm.prank(merchant);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.PayeeFlagged.selector, stranger));
        pay.createInvoice(stranger, AMOUNT, "x", 0);
    }

    function test_getInvoice_revertsWhenMissing() public {
        vm.expectRevert(CimonPay.InvoiceNotFound.selector);
        pay.getInvoice(bytes32(uint256(123)));
        vm.expectRevert(CimonPay.InvoiceNotFound.selector);
        pay.copCheck(bytes32(uint256(123)));
        vm.expectRevert(CimonPay.InvoiceNotFound.selector);
        pay.getExpectedName(bytes32(uint256(123)));
        vm.expectRevert(CimonPay.InvoiceNotFound.selector);
        pay.releaseTime(bytes32(uint256(123)));
    }

    // ------------------------------------------------------------------
    // Confirmation of Payee verdicts
    // ------------------------------------------------------------------

    function test_cop_verifiedBusinessWithMatchingName() public {
        bytes32 id = _invoice(0);
        CimonPay.CopResult memory r = pay.copCheck(id);
        assertEq(uint8(r.risk), uint8(CimonPay.RiskLevel.VERIFIED));
        assertTrue(r.registered);
        assertTrue(r.nameChecked);
        assertTrue(r.exactMatch);
        assertEq(uint8(r.tier), uint8(ICimonRegistry.VerificationTier.VERIFIED_BUSINESS));
        assertFalse(r.isFlagged);
        assertEq(r.legalName, ACME);
        assertEq(r.successfulTxCount, 0);
    }

    function test_cop_tradeNameAlsoMatches() public {
        vm.prank(merchant);
        bytes32 id = pay.createInvoiceWithName(acme, AMOUNT, "x", 0, "ACME LABS");
        assertEq(uint8(_risk(id)), uint8(CimonPay.RiskLevel.VERIFIED));
    }

    function test_cop_verifiedWithoutExpectedNameIsVerified() public {
        vm.prank(merchant);
        bytes32 id = pay.createInvoice(acme, AMOUNT, "x", 0);
        CimonPay.CopResult memory r = pay.copCheck(id);
        assertEq(uint8(r.risk), uint8(CimonPay.RiskLevel.VERIFIED));
        assertFalse(r.nameChecked);
    }

    function test_cop_govVerifiedIsVerified() public {
        vm.prank(owner);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.GOV_VERIFIED);
        assertEq(uint8(_risk(_invoice(0))), uint8(CimonPay.RiskLevel.VERIFIED));
    }

    function test_cop_basicUserWithMatchingNameIsCaution() public {
        address jane = makeAddr("jane");
        vm.prank(jane);
        registry.registerPayee("Jane Doe", "", "", bytes32(0));
        vm.prank(merchant);
        bytes32 id = pay.createInvoiceWithName(jane, AMOUNT, "x", 0, "jane doe");
        CimonPay.CopResult memory r = pay.copCheck(id);
        assertEq(uint8(r.risk), uint8(CimonPay.RiskLevel.CAUTION));
        assertTrue(r.exactMatch);
    }

    function test_cop_unregisteredPayeeIsCaution() public {
        vm.prank(merchant);
        bytes32 id = pay.createInvoiceWithName(stranger, AMOUNT, "x", 0, "Some Shop");
        CimonPay.CopResult memory r = pay.copCheck(id);
        assertEq(uint8(r.risk), uint8(CimonPay.RiskLevel.CAUTION));
        assertFalse(r.registered);
        assertEq(bytes(r.legalName).length, 0);
        assertEq(uint8(r.tier), uint8(ICimonRegistry.VerificationTier.UNREGISTERED));
    }

    function test_cop_registeredNameMismatchIsHighRisk() public {
        vm.prank(merchant);
        bytes32 id = pay.createInvoiceWithName(acme, AMOUNT, "x", 0, "Globex Inc");
        CimonPay.CopResult memory r = pay.copCheck(id);
        assertEq(uint8(r.risk), uint8(CimonPay.RiskLevel.HIGH_RISK));
        assertFalse(r.exactMatch);
        assertEq(r.legalName, ACME, "UI can show who the address really belongs to");
    }

    function test_cop_flaggedIsHighRisk() public {
        bytes32 id = _invoice(0);
        vm.prank(attestor);
        registry.setFlagged(acme, true, "compromised key");
        CimonPay.CopResult memory r = pay.copCheck(id);
        assertEq(uint8(r.risk), uint8(CimonPay.RiskLevel.HIGH_RISK));
        assertTrue(r.isFlagged);
    }

    function test_cop_reportsSuccessfulTxCount() public {
        _pay(_invoice(0));
        _pay(_invoice(0));
        assertEq(pay.copCheck(_invoice(0)).successfulTxCount, 2);
    }

    function test_cop_followsRegistryChangesLive() public {
        bytes32 id = _invoice(0);
        assertEq(uint8(_risk(id)), uint8(CimonPay.RiskLevel.VERIFIED));
        vm.prank(attestor);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.BASIC_USER);
        assertEq(uint8(_risk(id)), uint8(CimonPay.RiskLevel.CAUTION));
    }

    function test_copCheckAddress_withoutInvoice() public view {
        CimonPay.CopResult memory ok = pay.copCheckAddress(acme, "Acme Corp Ltd");
        assertEq(uint8(ok.risk), uint8(CimonPay.RiskLevel.VERIFIED));

        CimonPay.CopResult memory bad = pay.copCheckAddress(acme, "Somebody Else");
        assertEq(uint8(bad.risk), uint8(CimonPay.RiskLevel.HIGH_RISK));

        CimonPay.CopResult memory unknown = pay.copCheckAddress(stranger, "");
        assertEq(uint8(unknown.risk), uint8(CimonPay.RiskLevel.CAUTION));
    }

    // ------------------------------------------------------------------
    // Instant payment
    // ------------------------------------------------------------------

    function test_pay_instantSettlesDirectlyToPayee() public {
        bytes32 id = _invoice(0);
        uint256 payerBefore = token.balanceOf(payer);

        vm.expectEmit(true, true, true, true);
        emit CimonPay.InvoicePaid(id, payer, acme, AMOUNT);
        _pay(id);

        CimonPay.Invoice memory inv = pay.getInvoice(id);
        assertEq(uint8(inv.status), uint8(CimonPay.InvoiceStatus.SETTLED));
        assertEq(inv.actualPayer, payer);
        assertEq(inv.paidAt, T0);
        assertEq(token.balanceOf(acme), AMOUNT);
        assertEq(token.balanceOf(payer), payerBefore - AMOUNT);
        assertEq(token.balanceOf(address(pay)), 0, "nothing held for instant invoices");
    }

    function test_pay_instantEmitsSettledWithReceipt() public {
        bytes32 id = _invoice(0);
        vm.recordLogs();
        _pay(id);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == CimonPay.InvoiceSettled.selector) {
                found = true;
                assertEq(logs[i].topics[1], id);
                (uint256 amount, bytes32 receiptHash) = abi.decode(logs[i].data, (uint256, bytes32));
                assertEq(amount, AMOUNT);
                assertEq(receiptHash, pay.getReceipt(id).receiptHash);
            }
        }
        assertTrue(found, "InvoiceSettled emitted");
    }

    function test_pay_incrementsRegistryTxCount() public {
        _pay(_invoice(0));
        assertEq(registry.getProfile(acme).successfulTxCount, 1);
    }

    function test_pay_tracksPayerAndMerchantLists() public {
        bytes32 a = _invoice(0);
        bytes32 b = _invoice(DELAY);
        _pay(a);
        _pay(b);
        assertEq(pay.merchantInvoiceCount(merchant), 2);
        assertEq(pay.payerInvoiceCount(payer), 2);
        bytes32[] memory ids = pay.getPayerInvoiceIds(payer, 0, 10);
        assertEq(ids.length, 2);
        assertEq(ids[0], a);
        assertEq(ids[1], b);
    }

    function test_pay_toUnregisteredPayeeWorksAndSkipsRecord() public {
        vm.prank(merchant);
        bytes32 id = pay.createInvoice(stranger, AMOUNT, "x", 0);
        _pay(id);
        assertEq(token.balanceOf(stranger), AMOUNT);
        assertEq(registry.getProfile(stranger).successfulTxCount, 0);
    }

    function test_pay_revertsWhenAlreadyPaid() public {
        bytes32 id = _invoice(0);
        _pay(id);
        vm.prank(payer);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.InvalidStatus.selector, CimonPay.InvoiceStatus.SETTLED));
        pay.payInvoice(id);
    }

    function test_pay_revertsWhenCancelled() public {
        bytes32 id = _invoice(0);
        vm.prank(merchant);
        pay.cancelInvoice(id);
        vm.prank(payer);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.InvalidStatus.selector, CimonPay.InvoiceStatus.CANCELLED));
        pay.payInvoice(id);
    }

    function test_pay_revertsOnUnknownInvoice() public {
        vm.prank(payer);
        vm.expectRevert(CimonPay.InvoiceNotFound.selector);
        pay.payInvoice(bytes32(uint256(1)));
    }

    function test_pay_revertsWhenPayeePaysSelf() public {
        bytes32 id = _invoice(0);
        token.mint(acme, AMOUNT);
        vm.startPrank(acme);
        token.approve(address(pay), AMOUNT);
        vm.expectRevert(CimonPay.SelfPayment.selector);
        pay.payInvoice(id);
        vm.stopPrank();
    }

    function test_pay_revertsWithoutAllowance() public {
        bytes32 id = _invoice(0);
        vm.prank(payer);
        token.approve(address(pay), 0);
        vm.prank(payer);
        vm.expectRevert(CimonPay.TokenTransferFailed.selector);
        pay.payInvoice(id);
        assertEq(uint8(_status(id)), uint8(CimonPay.InvoiceStatus.PENDING), "state rolled back");
    }

    function test_pay_revertsWithoutBalance() public {
        address poor = makeAddr("poor");
        vm.prank(poor);
        token.approve(address(pay), type(uint256).max);
        bytes32 id = _invoice(0);
        vm.prank(poor);
        vm.expectRevert(CimonPay.TokenTransferFailed.selector);
        pay.payInvoice(id);
    }

    function test_pay_blockedForFlaggedPayee() public {
        bytes32 id = _invoice(0);
        vm.prank(attestor);
        registry.setFlagged(acme, true, "reported");
        vm.prank(payer);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.PayeeFlagged.selector, acme));
        pay.payInvoice(id);
        assertEq(token.balanceOf(acme), 0);
    }

    function test_pay_flagClearedAllowsPaymentAgain() public {
        bytes32 id = _invoice(0);
        vm.startPrank(attestor);
        registry.setFlagged(acme, true, "reported");
        registry.setFlagged(acme, false, "false alarm");
        vm.stopPrank();
        _pay(id);
        assertEq(uint8(_status(id)), uint8(CimonPay.InvoiceStatus.SETTLED));
    }

    // ------------------------------------------------------------------
    // Risk cap (check-then-pay protection)
    // ------------------------------------------------------------------

    function test_riskCap_verifiedPaymentPassesStrictCap() public {
        bytes32 id = _invoice(0);
        vm.prank(payer);
        pay.payInvoiceWithRiskCap(id, CimonPay.RiskLevel.VERIFIED);
        assertEq(uint8(_status(id)), uint8(CimonPay.InvoiceStatus.SETTLED));
    }

    function test_riskCap_revertsIfRegistryDowngradedAfterPreflight() public {
        bytes32 id = _invoice(0);
        assertEq(uint8(_risk(id)), uint8(CimonPay.RiskLevel.VERIFIED)); // what the UI showed

        vm.prank(attestor);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.BASIC_USER); // changes before tx

        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                CimonPay.RiskExceedsLimit.selector, CimonPay.RiskLevel.CAUTION, CimonPay.RiskLevel.VERIFIED
            )
        );
        pay.payInvoiceWithRiskCap(id, CimonPay.RiskLevel.VERIFIED);
        assertEq(token.balanceOf(acme), 0);
    }

    function test_riskCap_cautionAcceptedWhenCapIsCaution() public {
        vm.prank(merchant);
        bytes32 id = pay.createInvoice(stranger, AMOUNT, "x", 0);
        vm.prank(payer);
        pay.payInvoiceWithRiskCap(id, CimonPay.RiskLevel.CAUTION);
        assertEq(token.balanceOf(stranger), AMOUNT);
    }

    function test_riskCap_nameMismatchBlockedAtCautionCap() public {
        vm.prank(merchant);
        bytes32 id = pay.createInvoiceWithName(acme, AMOUNT, "x", 0, "Globex Inc");
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                CimonPay.RiskExceedsLimit.selector, CimonPay.RiskLevel.HIGH_RISK, CimonPay.RiskLevel.CAUTION
            )
        );
        pay.payInvoiceWithRiskCap(id, CimonPay.RiskLevel.CAUTION);
    }

    function test_riskCap_flaggedBlockedEvenAtHighRiskCap() public {
        bytes32 id = _invoice(0);
        vm.prank(attestor);
        registry.setFlagged(acme, true, "x");
        vm.prank(payer);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.PayeeFlagged.selector, acme));
        pay.payInvoiceWithRiskCap(id, CimonPay.RiskLevel.HIGH_RISK);
    }

    // ------------------------------------------------------------------
    // Escrow with safety delay
    // ------------------------------------------------------------------

    function test_escrow_payHoldsFunds() public {
        bytes32 id = _invoice(DELAY);
        vm.expectEmit(true, false, false, true);
        emit CimonPay.EscrowHeld(id, T0 + DELAY);
        _pay(id);

        assertEq(uint8(_status(id)), uint8(CimonPay.InvoiceStatus.ESCROWED));
        assertEq(token.balanceOf(address(pay)), AMOUNT);
        assertEq(token.balanceOf(acme), 0);
        assertEq(pay.releaseTime(id), T0 + DELAY);
        assertEq(registry.getProfile(acme).successfulTxCount, 0, "not counted until settled");
        assertEq(pay.getReceipt(id).receiptHash, bytes32(0));
    }

    function test_escrow_claimBeforeDelayReverts() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.warp(T0 + DELAY - 1);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.EscrowNotReleasable.selector, T0 + DELAY));
        pay.claimEscrow(id);
    }

    function test_escrow_claimAtExactReleaseTimeSucceeds() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.warp(T0 + DELAY);
        pay.claimEscrow(id);
        assertEq(token.balanceOf(acme), AMOUNT);
        assertEq(token.balanceOf(address(pay)), 0);
        assertEq(uint8(_status(id)), uint8(CimonPay.InvoiceStatus.SETTLED));
        assertEq(registry.getProfile(acme).successfulTxCount, 1);
        assertEq(pay.releaseTime(id), 0);
    }

    function test_escrow_anyoneCanTriggerClaimButFundsGoToPayee() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.warp(T0 + DELAY + 1 days);
        vm.expectEmit(true, true, false, false);
        emit CimonPay.InvoiceSettled(id, acme, AMOUNT, bytes32(0));
        vm.prank(stranger);
        pay.claimEscrow(id);
        assertEq(token.balanceOf(acme), AMOUNT);
        assertEq(token.balanceOf(stranger), 0);
    }

    function test_escrow_claimTwiceReverts() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.warp(T0 + DELAY);
        pay.claimEscrow(id);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.InvalidStatus.selector, CimonPay.InvoiceStatus.SETTLED));
        pay.claimEscrow(id);
    }

    function test_escrow_claimOnPendingReverts() public {
        bytes32 id = _invoice(DELAY);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.InvalidStatus.selector, CimonPay.InvoiceStatus.PENDING));
        pay.claimEscrow(id);
    }

    function test_escrow_payerCanCancelWithinWindow() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        uint256 balanceAfterPay = token.balanceOf(payer);

        vm.warp(T0 + DELAY - 1);
        vm.expectEmit(true, true, false, true);
        emit CimonPay.EscrowRefunded(id, payer, AMOUNT);
        vm.prank(payer);
        pay.disputeOrCancel(id);

        assertEq(uint8(_status(id)), uint8(CimonPay.InvoiceStatus.REFUNDED));
        assertEq(token.balanceOf(payer), balanceAfterPay + AMOUNT);
        assertEq(token.balanceOf(address(pay)), 0);
        assertEq(token.balanceOf(acme), 0);
        assertEq(registry.getProfile(acme).successfulTxCount, 0);
    }

    function test_escrow_cancelRightAfterPayment() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.prank(payer);
        pay.disputeOrCancel(id);
        assertEq(uint8(_status(id)), uint8(CimonPay.InvoiceStatus.REFUNDED));
    }

    function test_escrow_cancelAtExactWindowEndReverts() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.warp(T0 + DELAY);
        vm.prank(payer);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.DisputeWindowClosed.selector, T0 + DELAY));
        pay.disputeOrCancel(id);
    }

    function test_escrow_windowsNeverOverlap() public {
        // At every second around the boundary exactly one of claim / cancel is possible.
        for (uint256 dt = DELAY - 2; dt <= DELAY + 2; ++dt) {
            uint256 snap = vm.snapshotState();
            bytes32 id = _invoice(DELAY);
            _pay(id);
            vm.warp(T0 + dt);

            bool canClaim;
            try pay.claimEscrow(id) {
                canClaim = true;
            } catch {}
            bool canCancel;
            if (!canClaim) {
                vm.prank(payer);
                try pay.disputeOrCancel(id) {
                    canCancel = true;
                } catch {}
            }
            assertTrue(canClaim != canCancel, "exactly one path must be open");
            assertEq(canClaim, dt >= DELAY);
            vm.revertToState(snap);
        }
    }

    function test_escrow_onlyPayerCanCancel() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);

        vm.prank(merchant);
        vm.expectRevert(CimonPay.NotPayer.selector);
        pay.disputeOrCancel(id);

        vm.prank(acme);
        vm.expectRevert(CimonPay.NotPayer.selector);
        pay.disputeOrCancel(id);

        vm.prank(stranger);
        vm.expectRevert(CimonPay.NotPayer.selector);
        pay.disputeOrCancel(id);
    }

    function test_escrow_cancelAfterClaimReverts() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.warp(T0 + DELAY);
        pay.claimEscrow(id);
        vm.prank(payer);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.InvalidStatus.selector, CimonPay.InvoiceStatus.SETTLED));
        pay.disputeOrCancel(id);
    }

    function test_escrow_claimAfterRefundReverts() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.prank(payer);
        pay.disputeOrCancel(id);
        vm.warp(T0 + DELAY);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.InvalidStatus.selector, CimonPay.InvoiceStatus.REFUNDED));
        pay.claimEscrow(id);
    }

    function test_escrow_doubleRefundReverts() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.startPrank(payer);
        pay.disputeOrCancel(id);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.InvalidStatus.selector, CimonPay.InvoiceStatus.REFUNDED));
        pay.disputeOrCancel(id);
        vm.stopPrank();
    }

    function test_escrow_disputeOnPendingReverts() public {
        bytes32 id = _invoice(DELAY);
        vm.prank(payer);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.InvalidStatus.selector, CimonPay.InvoiceStatus.PENDING));
        pay.disputeOrCancel(id);
    }

    function test_escrow_flaggedPayeeCannotClaim() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.prank(attestor);
        registry.setFlagged(acme, true, "turned out to be a scam");
        vm.warp(T0 + DELAY);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.PayeeFlagged.selector, acme));
        pay.claimEscrow(id);
        assertEq(token.balanceOf(address(pay)), AMOUNT, "funds stay locked, not lost");
    }

    function test_escrow_payerCanReclaimAfterWindowIfPayeeFlagged() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.warp(T0 + DELAY + 3 days);
        vm.prank(attestor);
        registry.setFlagged(acme, true, "late discovery");

        uint256 before = token.balanceOf(payer);
        vm.prank(payer);
        pay.disputeOrCancel(id);
        assertEq(token.balanceOf(payer), before + AMOUNT);
        assertEq(uint8(_status(id)), uint8(CimonPay.InvoiceStatus.REFUNDED));
    }

    function test_escrow_unflaggedPayeeCanClaimAfterFlagCleared() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.startPrank(attestor);
        registry.setFlagged(acme, true, "x");
        registry.setFlagged(acme, false, "cleared");
        vm.stopPrank();
        vm.warp(T0 + DELAY);
        pay.claimEscrow(id);
        assertEq(token.balanceOf(acme), AMOUNT);
    }

    function test_escrow_rejectsFeeOnTransferToken() public {
        FeeOnTransferERC20 fot = new FeeOnTransferERC20();
        CimonPay p = new CimonPay(IERC20(address(fot)), ICimonRegistry(address(registry)));
        fot.mint(payer, 1_000e6);
        vm.prank(payer);
        fot.approve(address(p), type(uint256).max);

        vm.prank(merchant);
        bytes32 id = p.createInvoice(acme, AMOUNT, "x", DELAY);
        vm.prank(payer);
        vm.expectRevert(CimonPay.UnexpectedTokenAmount.selector);
        p.payInvoice(id);
        assertEq(uint8(p.getInvoice(id).status), uint8(CimonPay.InvoiceStatus.PENDING));
    }

    // ------------------------------------------------------------------
    // Merchant cancellation
    // ------------------------------------------------------------------

    function test_cancelInvoice_merchantCancelsPending() public {
        bytes32 id = _invoice(0);
        vm.expectEmit(true, true, false, false);
        emit CimonPay.InvoiceCancelled(id, merchant);
        vm.prank(merchant);
        pay.cancelInvoice(id);
        assertEq(uint8(_status(id)), uint8(CimonPay.InvoiceStatus.CANCELLED));
    }

    function test_cancelInvoice_onlyMerchant() public {
        bytes32 id = _invoice(0);
        vm.prank(stranger);
        vm.expectRevert(CimonPay.NotMerchant.selector);
        pay.cancelInvoice(id);

        vm.prank(acme);
        vm.expectRevert(CimonPay.NotMerchant.selector);
        pay.cancelInvoice(id);
    }

    function test_cancelInvoice_cannotCancelPaid() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.prank(merchant);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.InvalidStatus.selector, CimonPay.InvoiceStatus.ESCROWED));
        pay.cancelInvoice(id);
    }

    function test_cancelInvoice_cannotCancelTwice() public {
        bytes32 id = _invoice(0);
        vm.startPrank(merchant);
        pay.cancelInvoice(id);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.InvalidStatus.selector, CimonPay.InvoiceStatus.CANCELLED));
        pay.cancelInvoice(id);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // Receipts
    // ------------------------------------------------------------------

    function test_receipt_instantMatchesIndependentComputation() public {
        bytes32 id = _invoice(0);
        _pay(id);

        bytes32 expected = keccak256(
            abi.encode(
                block.chainid, address(pay), id, merchant, acme, payer, AMOUNT, keccak256(bytes("Order #1001")), T0, T0
            )
        );
        CimonPay.Receipt memory r = pay.getReceipt(id);
        assertEq(r.settledAt, T0);
        assertEq(r.receiptHash, expected);
        assertEq(pay.computeReceiptHash(id), expected);
    }

    function test_receipt_escrowUsesSettlementTime() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.warp(T0 + DELAY + 77);
        pay.claimEscrow(id);

        CimonPay.Receipt memory r = pay.getReceipt(id);
        assertEq(r.settledAt, T0 + DELAY + 77);
        assertEq(pay.computeReceiptHash(id), r.receiptHash);
    }

    function test_receipt_differsBetweenInvoices() public {
        bytes32 a = _invoice(0);
        bytes32 b = _invoice(0);
        _pay(a);
        _pay(b);
        assertTrue(pay.getReceipt(a).receiptHash != pay.getReceipt(b).receiptHash);
    }

    function test_receipt_computeRevertsWhenNotSettled() public {
        bytes32 id = _invoice(0);
        vm.expectRevert(abi.encodeWithSelector(CimonPay.InvalidStatus.selector, CimonPay.InvoiceStatus.PENDING));
        pay.computeReceiptHash(id);
    }

    function test_receipt_noneForRefunded() public {
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.prank(payer);
        pay.disputeOrCancel(id);
        assertEq(pay.getReceipt(id).receiptHash, bytes32(0));
        assertEq(pay.getReceipt(id).settledAt, 0);
    }

    // ------------------------------------------------------------------
    // Pagination
    // ------------------------------------------------------------------

    function test_pagination_merchantInvoices() public {
        bytes32[] memory made = new bytes32[](5);
        for (uint256 i; i < 5; ++i) {
            made[i] = _invoice(0);
        }
        assertEq(pay.merchantInvoiceCount(merchant), 5);

        bytes32[] memory page = pay.getMerchantInvoiceIds(merchant, 1, 2);
        assertEq(page.length, 2);
        assertEq(page[0], made[1]);
        assertEq(page[1], made[2]);

        bytes32[] memory tail = pay.getMerchantInvoiceIds(merchant, 3, 100);
        assertEq(tail.length, 2);
        assertEq(tail[1], made[4]);

        assertEq(pay.getMerchantInvoiceIds(merchant, 5, 10).length, 0);
        assertEq(pay.getMerchantInvoiceIds(merchant, 99, 10).length, 0);
        assertEq(pay.getMerchantInvoiceIds(merchant, 0, type(uint256).max).length, 5, "no overflow on huge limit");
        assertEq(pay.getMerchantInvoiceIds(stranger, 0, 10).length, 0);
    }

    // ------------------------------------------------------------------
    // Registry resilience
    // ------------------------------------------------------------------

    function test_pay_succeedsEvenIfPayIsNotARecorder() public {
        vm.prank(owner);
        registry.setRecorder(address(pay), false);
        bytes32 id = _invoice(0);
        _pay(id);
        assertEq(uint8(_status(id)), uint8(CimonPay.InvoiceStatus.SETTLED));
        assertEq(token.balanceOf(acme), AMOUNT);
        assertEq(registry.getProfile(acme).successfulTxCount, 0);
    }

    // ------------------------------------------------------------------
    // Token behaviours
    // ------------------------------------------------------------------

    function test_token_noReturnValueTokenWorks() public {
        NoReturnERC20 usdt = new NoReturnERC20();
        CimonPay p = new CimonPay(IERC20(address(usdt)), ICimonRegistry(address(registry)));
        usdt.mint(payer, 1_000e6);
        vm.prank(payer);
        usdt.approve(address(p), type(uint256).max);

        vm.prank(merchant);
        bytes32 instant = p.createInvoice(acme, AMOUNT, "a", 0);
        vm.prank(merchant);
        bytes32 escrowed = p.createInvoice(acme, AMOUNT, "b", DELAY);

        vm.startPrank(payer);
        p.payInvoice(instant);
        p.payInvoice(escrowed);
        vm.stopPrank();
        assertEq(usdt.balanceOf(acme), AMOUNT);
        assertEq(usdt.balanceOf(address(p)), AMOUNT);

        vm.warp(T0 + DELAY);
        p.claimEscrow(escrowed);
        assertEq(usdt.balanceOf(acme), 2 * AMOUNT);
    }

    function test_token_falseReturnRevertsInsteadOfSilentlySucceeding() public {
        FalseReturnERC20 bad = new FalseReturnERC20();
        CimonPay p = new CimonPay(IERC20(address(bad)), ICimonRegistry(address(registry)));
        vm.prank(merchant);
        bytes32 id = p.createInvoice(acme, AMOUNT, "x", 0);
        vm.prank(payer);
        vm.expectRevert(CimonPay.TokenTransferFailed.selector);
        p.payInvoice(id);
        assertEq(uint8(p.getInvoice(id).status), uint8(CimonPay.InvoiceStatus.PENDING));
    }

    function test_token_noCodeAddressReverts() public {
        CimonPay p = new CimonPay(IERC20(makeAddr("notAToken")), ICimonRegistry(address(registry)));
        vm.prank(merchant);
        bytes32 id = p.createInvoice(acme, AMOUNT, "x", 0);
        vm.prank(payer);
        vm.expectRevert(CimonPay.TokenTransferFailed.selector);
        p.payInvoice(id);
    }

    // ------------------------------------------------------------------
    // Reentrancy
    // ------------------------------------------------------------------

    function _reentrantSetup() internal returns (CimonPay p, ReentrantERC20 rt, CimonRegistry reg) {
        reg = new CimonRegistry(owner);
        vm.prank(owner);
        rt = new ReentrantERC20();
        p = new CimonPay(IERC20(address(rt)), ICimonRegistry(address(reg)));
        rt.mint(payer, 1_000e6);
        vm.prank(payer);
        rt.approve(address(p), type(uint256).max);
    }

    function test_reentrancy_payInvoiceCannotBeReentered() public {
        (CimonPay p, ReentrantERC20 rt,) = _reentrantSetup();
        vm.prank(merchant);
        bytes32 id = p.createInvoice(acme, AMOUNT, "x", 0);

        // During transferFrom the token tries to pay the same invoice again.
        rt.arm(address(p), abi.encodeCall(CimonPay.payInvoice, (id)), true);
        vm.prank(payer);
        p.payInvoice(id);

        assertEq(rt.reentryAttempts(), 1);
        assertFalse(rt.reentrySucceeded());
        assertEq(bytes4(rt.reentryReturn()), CimonPay.Reentrancy.selector);
        assertEq(rt.balanceOf(acme), AMOUNT, "paid exactly once");
        assertEq(rt.balanceOf(payer), 1_000e6 - AMOUNT);
    }

    function test_reentrancy_claimEscrowCannotBeReentered() public {
        (CimonPay p, ReentrantERC20 rt,) = _reentrantSetup();
        vm.prank(merchant);
        bytes32 id = p.createInvoice(acme, AMOUNT, "x", DELAY);
        vm.prank(payer);
        p.payInvoice(id);

        vm.warp(T0 + DELAY);
        rt.arm(address(p), abi.encodeCall(CimonPay.claimEscrow, (id)), false);
        p.claimEscrow(id);

        assertEq(rt.reentryAttempts(), 1);
        assertFalse(rt.reentrySucceeded());
        assertEq(bytes4(rt.reentryReturn()), CimonPay.Reentrancy.selector);
        assertEq(rt.balanceOf(acme), AMOUNT, "released exactly once");
        assertEq(rt.balanceOf(address(p)), 0);
    }

    function test_reentrancy_refundCannotBeReentered() public {
        (CimonPay p, ReentrantERC20 rt,) = _reentrantSetup();
        vm.prank(merchant);
        bytes32 id = p.createInvoice(acme, AMOUNT, "x", DELAY);
        vm.prank(payer);
        p.payInvoice(id);

        rt.arm(address(p), abi.encodeCall(CimonPay.disputeOrCancel, (id)), false);
        vm.prank(payer);
        p.disputeOrCancel(id);

        assertEq(rt.reentryAttempts(), 1);
        assertFalse(rt.reentrySucceeded());
        assertEq(bytes4(rt.reentryReturn()), CimonPay.Reentrancy.selector);
        assertEq(rt.balanceOf(payer), 1_000e6, "refunded exactly once");
        assertEq(rt.balanceOf(address(p)), 0);
    }

    function test_reentrancy_crossFunctionCreateIsUnaffected() public {
        // The lock covers state-changing payment paths; creating invoices from a hook is harmless
        // but must not corrupt accounting of the invoice being paid.
        (CimonPay p, ReentrantERC20 rt,) = _reentrantSetup();
        vm.prank(merchant);
        bytes32 id = p.createInvoice(acme, AMOUNT, "x", 0);
        rt.arm(address(p), abi.encodeCall(CimonPay.cancelInvoice, (id)), true);
        vm.prank(payer);
        p.payInvoice(id);
        assertFalse(rt.reentrySucceeded());
        assertEq(uint8(p.getInvoice(id).status), uint8(CimonPay.InvoiceStatus.SETTLED));
    }

    // ------------------------------------------------------------------
    // Fuzz
    // ------------------------------------------------------------------

    function testFuzz_instantPaymentMovesExactAmount(uint96 amount) public {
        amount = uint96(bound(amount, 1, 10_000e6));
        vm.prank(merchant);
        bytes32 id = pay.createInvoiceWithName(acme, amount, "fuzz", 0, ACME);

        uint256 supply = token.totalSupply();
        uint256 payerBefore = token.balanceOf(payer);
        _pay(id);

        assertEq(token.balanceOf(acme), amount);
        assertEq(token.balanceOf(payer), payerBefore - amount);
        assertEq(token.totalSupply(), supply);
        assertEq(token.balanceOf(address(pay)), 0);
    }

    function testFuzz_escrowEitherSettlesOrRefundsNeverBoth(uint96 amount, uint32 delay, uint32 wait, bool cancel)
        public
    {
        amount = uint96(bound(amount, 1, 10_000e6));
        uint256 d = bound(delay, pay.MIN_SAFETY_DELAY(), pay.MAX_SAFETY_DELAY());
        uint256 w = bound(wait, 0, 8 days);

        vm.prank(merchant);
        bytes32 id = pay.createInvoice(acme, amount, "fuzz", d);
        _pay(id);
        vm.warp(T0 + w);

        uint256 payerBefore = token.balanceOf(payer);
        if (cancel) {
            vm.prank(payer);
            if (w < d) {
                pay.disputeOrCancel(id);
                assertEq(token.balanceOf(payer), payerBefore + amount);
                assertEq(token.balanceOf(acme), 0);
            } else {
                vm.expectRevert(abi.encodeWithSelector(CimonPay.DisputeWindowClosed.selector, T0 + d));
                pay.disputeOrCancel(id);
                assertEq(token.balanceOf(address(pay)), amount);
            }
        } else {
            if (w >= d) {
                pay.claimEscrow(id);
                assertEq(token.balanceOf(acme), amount);
                assertEq(token.balanceOf(payer), payerBefore);
            } else {
                vm.expectRevert(abi.encodeWithSelector(CimonPay.EscrowNotReleasable.selector, T0 + d));
                pay.claimEscrow(id);
                assertEq(token.balanceOf(address(pay)), amount);
            }
        }
        // Conservation: nothing is ever created or destroyed.
        assertEq(token.balanceOf(payer) + token.balanceOf(acme) + token.balanceOf(address(pay)), 10_000e6);
    }

    function testFuzz_onlyExpectedPayeeOrPayerEverReceiveFunds(address caller) public {
        vm.assume(caller != address(0) && caller != address(pay) && caller != payer && caller != acme);
        vm.assume(caller != address(token) && caller != address(registry) && caller.code.length == 0);
        bytes32 id = _invoice(DELAY);
        _pay(id);
        vm.warp(T0 + DELAY);

        vm.prank(caller);
        pay.claimEscrow(id);

        assertEq(token.balanceOf(caller), 0, "a third party cannot divert funds");
        assertEq(token.balanceOf(acme), AMOUNT);
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function _repeat(string memory s, uint256 n) internal pure returns (string memory out) {
        for (uint256 i; i < n; ++i) {
            out = string.concat(out, s);
        }
    }
}
