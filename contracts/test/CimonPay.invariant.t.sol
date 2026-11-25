// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {CimonRegistry} from "../src/CimonRegistry.sol";
import {CimonPay} from "../src/CimonPay.sol";
import {ICimonRegistry} from "../src/interfaces/ICimonRegistry.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @dev Drives random sequences of create / pay / claim / dispute / cancel / flag / time travel.
contract PayHandler is Test {
    CimonPay public pay;
    CimonRegistry public registry;
    MockERC20 public token;
    address public attestor;

    address[] public payers;
    address[] public payees;
    bytes32[] public ids;

    constructor(CimonPay pay_, CimonRegistry registry_, MockERC20 token_, address attestor_) {
        pay = pay_;
        registry = registry_;
        token = token_;
        attestor = attestor_;
        for (uint256 i; i < 3; ++i) {
            address p = makeAddr(string.concat("payer", vm.toString(i)));
            address r = makeAddr(string.concat("payee", vm.toString(i)));
            payers.push(p);
            payees.push(r);
            token.mint(p, 1_000_000e6);
            vm.prank(p);
            token.approve(address(pay), type(uint256).max);
        }
    }

    function idCount() external view returns (uint256) {
        return ids.length;
    }

    function create(uint256 payeeSeed, uint256 amount, uint256 delaySeed) external {
        address payee = payees[payeeSeed % payees.length];
        amount = bound(amount, 1, 5_000e6);
        uint256 delay = delaySeed % 3 == 0 ? 0 : bound(delaySeed, 60, 7 days);
        vm.prank(makeAddr("merchant"));
        try pay.createInvoice(payee, amount, "inv", delay) returns (bytes32 id) {
            ids.push(id);
        } catch {}
    }

    function payIt(uint256 idSeed, uint256 payerSeed) external {
        if (ids.length == 0) return;
        vm.prank(payers[payerSeed % payers.length]);
        try pay.payInvoice(ids[idSeed % ids.length]) {} catch {}
    }

    function claim(uint256 idSeed) external {
        if (ids.length == 0) return;
        try pay.claimEscrow(ids[idSeed % ids.length]) {} catch {}
    }

    function dispute(uint256 idSeed, uint256 payerSeed) external {
        if (ids.length == 0) return;
        vm.prank(payers[payerSeed % payers.length]);
        try pay.disputeOrCancel(ids[idSeed % ids.length]) {} catch {}
    }

    function cancel(uint256 idSeed) external {
        if (ids.length == 0) return;
        vm.prank(makeAddr("merchant"));
        try pay.cancelInvoice(ids[idSeed % ids.length]) {} catch {}
    }

    function flag(uint256 payeeSeed, bool on) external {
        vm.prank(attestor);
        registry.setFlagged(payees[payeeSeed % payees.length], on, "fuzz");
    }

    function warpTime(uint256 secs) external {
        vm.warp(block.timestamp + bound(secs, 0, 3 days));
    }

    function allPayers() external view returns (address[] memory) {
        return payers;
    }

    function allPayees() external view returns (address[] memory) {
        return payees;
    }
}

contract CimonPayInvariantTest is StdInvariant, Test {
    CimonRegistry internal registry;
    CimonPay internal pay;
    MockERC20 internal token;
    PayHandler internal handler;

    address internal owner = makeAddr("owner");
    address internal attestor = makeAddr("attestor");

    function setUp() public {
        vm.startPrank(owner);
        registry = new CimonRegistry(owner);
        token = new MockERC20();
        pay = new CimonPay(IERC20(address(token)), ICimonRegistry(address(registry)));
        registry.setRecorder(address(pay), true);
        registry.setAttestor(attestor, true);
        vm.stopPrank();

        handler = new PayHandler(pay, registry, token, attestor);
        targetContract(address(handler));
    }

    /// The contract holds exactly the sum of invoices currently in escrow, nothing more or less.
    function invariant_balanceEqualsEscrowedAmounts() public view {
        uint256 escrowed;
        uint256 n = handler.idCount();
        for (uint256 i; i < n; ++i) {
            CimonPay.Invoice memory inv = pay.getInvoice(handler.ids(i));
            if (inv.status == CimonPay.InvoiceStatus.ESCROWED) escrowed += inv.amount;
        }
        assertEq(token.balanceOf(address(pay)), escrowed);
    }

    /// Tokens are conserved across payers, payees and the escrow contract.
    function invariant_tokenConservation() public view {
        address[] memory ps = handler.allPayers();
        address[] memory rs = handler.allPayees();
        uint256 sum = token.balanceOf(address(pay));
        for (uint256 i; i < ps.length; ++i) {
            sum += token.balanceOf(ps[i]) + token.balanceOf(rs[i]);
        }
        assertEq(sum, token.totalSupply());
    }

    /// Every settled invoice has a receipt that recomputes, every other invoice has none.
    function invariant_receiptsOnlyForSettled() public view {
        uint256 n = handler.idCount();
        for (uint256 i; i < n; ++i) {
            bytes32 id = handler.ids(i);
            CimonPay.Invoice memory inv = pay.getInvoice(id);
            CimonPay.Receipt memory r = pay.getReceipt(id);
            if (inv.status == CimonPay.InvoiceStatus.SETTLED) {
                assertTrue(r.receiptHash != bytes32(0));
                assertEq(pay.computeReceiptHash(id), r.receiptHash);
            } else {
                assertEq(r.receiptHash, bytes32(0));
            }
        }
    }

    /// Payees only ever receive what settled invoices say they should.
    function invariant_payeeBalancesMatchSettledInvoices() public view {
        address[] memory rs = handler.allPayees();
        uint256 n = handler.idCount();
        for (uint256 j; j < rs.length; ++j) {
            uint256 expected;
            for (uint256 i; i < n; ++i) {
                CimonPay.Invoice memory inv = pay.getInvoice(handler.ids(i));
                if (inv.status == CimonPay.InvoiceStatus.SETTLED && inv.expectedPayee == rs[j]) {
                    expected += inv.amount;
                }
            }
            assertEq(token.balanceOf(rs[j]), expected);
        }
    }
}
