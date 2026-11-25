// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CimonRegistry} from "../src/CimonRegistry.sol";
import {ICimonRegistry} from "../src/interfaces/ICimonRegistry.sol";

contract CimonRegistryTest is Test {
    CimonRegistry internal registry;

    address internal owner = makeAddr("owner");
    address internal attestor = makeAddr("attestor");
    address internal recorder = makeAddr("recorder");
    address internal acme = makeAddr("acme");
    address internal jane = makeAddr("jane");
    address internal stranger = makeAddr("stranger");

    bytes32 internal constant REG_HASH = keccak256("RC-123456");

    event PayeeRegistered(
        address indexed payee, string legalName, string tradeName, string domain, bytes32 registrationHash
    );
    event ProfileUpdated(
        address indexed payee, string legalName, string tradeName, string domain, bytes32 registrationHash
    );
    event TierSet(
        address indexed payee,
        ICimonRegistry.VerificationTier oldTier,
        ICimonRegistry.VerificationTier newTier,
        address indexed by
    );
    event PayeeFlagged(address indexed payee, bool flagged, string reason, address indexed by);
    event PaymentRecorded(address indexed payee, uint256 newCount, address indexed recorder);
    event AttestorSet(address indexed attestor, bool enabled);
    event RecorderSet(address indexed recorder, bool enabled);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        registry = new CimonRegistry(owner);
        vm.startPrank(owner);
        registry.setAttestor(attestor, true);
        registry.setRecorder(recorder, true);
        vm.stopPrank();
    }

    function _registerAcme() internal {
        vm.prank(acme);
        registry.registerPayee("Acme Corp Ltd", "Acme Labs", "acmelabs.com", REG_HASH);
    }

    // ------------------------------------------------------------------
    // Construction and ownership
    // ------------------------------------------------------------------

    function test_constructor_setsOwner() public view {
        assertEq(registry.owner(), owner);
    }

    function test_constructor_revertsOnZeroOwner() public {
        vm.expectRevert(CimonRegistry.ZeroAddress.selector);
        new CimonRegistry(address(0));
    }

    function test_ownership_twoStepTransfer() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferStarted(owner, stranger);
        registry.transferOwnership(stranger);
        assertEq(registry.owner(), owner, "owner unchanged until accepted");
        assertEq(registry.pendingOwner(), stranger);

        vm.prank(stranger);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, stranger);
        registry.acceptOwnership();
        assertEq(registry.owner(), stranger);
        assertEq(registry.pendingOwner(), address(0));
    }

    function test_ownership_onlyPendingOwnerCanAccept() public {
        vm.prank(owner);
        registry.transferOwnership(stranger);
        vm.prank(attestor);
        vm.expectRevert(CimonRegistry.NotPendingOwner.selector);
        registry.acceptOwnership();
    }

    function test_ownership_transferRequiresOwnerAndNonZero() public {
        vm.prank(stranger);
        vm.expectRevert(CimonRegistry.NotOwner.selector);
        registry.transferOwnership(stranger);

        vm.prank(owner);
        vm.expectRevert(CimonRegistry.ZeroAddress.selector);
        registry.transferOwnership(address(0));
    }

    function test_setAttestor_onlyOwner() public {
        vm.prank(attestor);
        vm.expectRevert(CimonRegistry.NotOwner.selector);
        registry.setAttestor(stranger, true);

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit AttestorSet(stranger, true);
        registry.setAttestor(stranger, true);
        assertTrue(registry.attestors(stranger));
    }

    function test_setRecorder_onlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(CimonRegistry.NotOwner.selector);
        registry.setRecorder(stranger, true);

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit RecorderSet(stranger, true);
        registry.setRecorder(stranger, true);
        assertTrue(registry.recorders(stranger));
    }

    function test_setAttestorAndRecorder_rejectZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(CimonRegistry.ZeroAddress.selector);
        registry.setAttestor(address(0), true);
        vm.expectRevert(CimonRegistry.ZeroAddress.selector);
        registry.setRecorder(address(0), true);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // Registration
    // ------------------------------------------------------------------

    function test_registerPayee_storesProfile() public {
        vm.warp(1_800_000_000);
        vm.expectEmit(true, false, false, true);
        emit PayeeRegistered(acme, "Acme Corp Ltd", "Acme Labs", "acmelabs.com", REG_HASH);
        _registerAcme();

        ICimonRegistry.PayeeProfile memory p = registry.getProfile(acme);
        assertEq(p.legalName, "Acme Corp Ltd");
        assertEq(p.tradeName, "Acme Labs");
        assertEq(p.domain, "acmelabs.com");
        assertEq(p.registrationHash, REG_HASH);
        assertEq(p.payoutAddress, acme);
        assertEq(uint8(p.tier), uint8(ICimonRegistry.VerificationTier.BASIC_USER));
        assertEq(p.registeredAt, 1_800_000_000);
        assertFalse(p.isFlagged);
        assertEq(p.successfulTxCount, 0);
        assertEq(registry.totalPayees(), 1);
        assertTrue(registry.isRegistered(acme));
    }

    function test_registerPayee_allowsEmptyOptionalFields() public {
        vm.prank(jane);
        registry.registerPayee("Jane Doe", "", "", bytes32(0));
        assertTrue(registry.isRegistered(jane));
    }

    function test_registerPayee_revertsWhenAlreadyRegistered() public {
        _registerAcme();
        vm.prank(acme);
        vm.expectRevert(CimonRegistry.AlreadyRegistered.selector);
        registry.registerPayee("Other", "", "", bytes32(0));
    }

    function test_registerPayee_revertsOnEmptyLegalName() public {
        vm.prank(jane);
        vm.expectRevert(CimonRegistry.InvalidName.selector);
        registry.registerPayee("", "", "", bytes32(0));
    }

    function test_registerPayee_revertsOnTooLongNames() public {
        string memory tooLong = _repeat("a", 129);
        vm.startPrank(jane);
        vm.expectRevert(CimonRegistry.InvalidName.selector);
        registry.registerPayee(tooLong, "", "", bytes32(0));
        vm.expectRevert(CimonRegistry.InvalidName.selector);
        registry.registerPayee("Jane", tooLong, "", bytes32(0));
        vm.expectRevert(CimonRegistry.InvalidDomain.selector);
        registry.registerPayee("Jane", "", _repeat("d", 254), bytes32(0));
        vm.stopPrank();
    }

    function test_registerPayee_acceptsMaxLengths() public {
        vm.prank(jane);
        registry.registerPayee(_repeat("a", 128), _repeat("b", 128), _repeat("d", 253), bytes32(0));
        assertTrue(registry.isRegistered(jane));
    }

    function test_registerPayee_rejectsControlCharacters() public {
        vm.startPrank(jane);
        vm.expectRevert(CimonRegistry.InvalidName.selector);
        registry.registerPayee("Jane\nDoe", "", "", bytes32(0));
        vm.expectRevert(CimonRegistry.InvalidName.selector);
        registry.registerPayee("Jane", "Evil\x1b[31m", "", bytes32(0));
        vm.expectRevert(CimonRegistry.InvalidDomain.selector);
        registry.registerPayee("Jane", "", "a\x00b.com", bytes32(0));
        vm.expectRevert(CimonRegistry.InvalidName.selector);
        registry.registerPayee("Jane\x7f", "", "", bytes32(0));
        vm.stopPrank();
    }

    function test_registerPayee_preservesExistingFlag() public {
        vm.prank(attestor);
        registry.setFlagged(acme, true, "reported scam");
        _registerAcme();
        assertTrue(registry.getProfile(acme).isFlagged);
        assertTrue(registry.isFlagged(acme));
    }

    // ------------------------------------------------------------------
    // Profile updates
    // ------------------------------------------------------------------

    function test_updateProfile_basicUserKeepsTier() public {
        _registerAcme();
        vm.prank(acme);
        vm.expectEmit(true, false, false, true);
        emit ProfileUpdated(acme, "Acme Corporation Ltd", "Acme Labs", "acmelabs.com", REG_HASH);
        registry.updateProfile("Acme Corporation Ltd", "Acme Labs", "acmelabs.com", REG_HASH);

        ICimonRegistry.PayeeProfile memory p = registry.getProfile(acme);
        assertEq(p.legalName, "Acme Corporation Ltd");
        assertEq(uint8(p.tier), uint8(ICimonRegistry.VerificationTier.BASIC_USER));
        assertEq(p.registeredAt, block.timestamp, "registration time kept");
    }

    function test_updateProfile_identityChangeResetsVerifiedTier() public {
        _registerAcme();
        vm.prank(attestor);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.VERIFIED_BUSINESS);

        vm.prank(acme);
        vm.expectEmit(true, false, false, true);
        emit TierSet(
            acme, ICimonRegistry.VerificationTier.VERIFIED_BUSINESS, ICimonRegistry.VerificationTier.BASIC_USER, acme
        );
        registry.updateProfile("Totally Different Ltd", "Acme Labs", "acmelabs.com", REG_HASH);

        assertEq(uint8(registry.getProfile(acme).tier), uint8(ICimonRegistry.VerificationTier.BASIC_USER));
    }

    function test_updateProfile_eachIdentityFieldResetsTier() public {
        string[4] memory variants = ["legal", "trade", "domain", "hash"];
        for (uint256 i; i < variants.length; ++i) {
            address who = makeAddr(string.concat("payee", variants[i]));
            vm.prank(who);
            registry.registerPayee("Acme Corp Ltd", "Acme Labs", "acmelabs.com", REG_HASH);
            vm.prank(attestor);
            registry.setVerificationTier(who, ICimonRegistry.VerificationTier.VERIFIED_BUSINESS);

            vm.prank(who);
            if (i == 0) registry.updateProfile("Acme Corp Ltd 2", "Acme Labs", "acmelabs.com", REG_HASH);
            if (i == 1) registry.updateProfile("Acme Corp Ltd", "Acme Labs 2", "acmelabs.com", REG_HASH);
            if (i == 2) registry.updateProfile("Acme Corp Ltd", "Acme Labs", "acmelabs.io", REG_HASH);
            if (i == 3) registry.updateProfile("Acme Corp Ltd", "Acme Labs", "acmelabs.com", bytes32(uint256(1)));

            assertEq(
                uint8(registry.getProfile(who).tier), uint8(ICimonRegistry.VerificationTier.BASIC_USER), variants[i]
            );
        }
    }

    function test_updateProfile_noopKeepsVerifiedTier() public {
        _registerAcme();
        vm.prank(attestor);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.VERIFIED_BUSINESS);
        vm.prank(acme);
        registry.updateProfile("Acme Corp Ltd", "Acme Labs", "acmelabs.com", REG_HASH);
        assertEq(uint8(registry.getProfile(acme).tier), uint8(ICimonRegistry.VerificationTier.VERIFIED_BUSINESS));
    }

    function test_updateProfile_revertsWhenUnregistered() public {
        vm.prank(stranger);
        vm.expectRevert(CimonRegistry.NotRegistered.selector);
        registry.updateProfile("X", "", "", bytes32(0));
    }

    function test_updateProfile_validatesText() public {
        _registerAcme();
        vm.prank(acme);
        vm.expectRevert(CimonRegistry.InvalidName.selector);
        registry.updateProfile("", "", "", bytes32(0));
    }

    // ------------------------------------------------------------------
    // Tiers
    // ------------------------------------------------------------------

    function test_setVerificationTier_attestorCanVerifyBusiness() public {
        _registerAcme();
        vm.prank(attestor);
        vm.expectEmit(true, true, false, true);
        emit TierSet(
            acme,
            ICimonRegistry.VerificationTier.BASIC_USER,
            ICimonRegistry.VerificationTier.VERIFIED_BUSINESS,
            attestor
        );
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.VERIFIED_BUSINESS);
        assertEq(uint8(registry.getProfile(acme).tier), uint8(ICimonRegistry.VerificationTier.VERIFIED_BUSINESS));
    }

    function test_setVerificationTier_ownerIsImplicitAttestor() public {
        _registerAcme();
        vm.prank(owner);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.VERIFIED_BUSINESS);
        assertEq(uint8(registry.getProfile(acme).tier), uint8(ICimonRegistry.VerificationTier.VERIFIED_BUSINESS));
    }

    function test_setVerificationTier_strangerReverts() public {
        _registerAcme();
        vm.prank(stranger);
        vm.expectRevert(CimonRegistry.NotAttestor.selector);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.VERIFIED_BUSINESS);
    }

    function test_setVerificationTier_selfVerificationBlocked() public {
        _registerAcme();
        vm.prank(acme);
        vm.expectRevert(CimonRegistry.NotAttestor.selector);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.GOV_VERIFIED);
    }

    function test_setVerificationTier_govVerifiedOnlyOwner() public {
        _registerAcme();
        vm.prank(attestor);
        vm.expectRevert(CimonRegistry.NotOwner.selector);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.GOV_VERIFIED);

        vm.prank(owner);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.GOV_VERIFIED);
        assertEq(uint8(registry.getProfile(acme).tier), uint8(ICimonRegistry.VerificationTier.GOV_VERIFIED));
    }

    function test_setVerificationTier_attestorCannotDowngradeGov() public {
        _registerAcme();
        vm.prank(owner);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.GOV_VERIFIED);

        vm.prank(attestor);
        vm.expectRevert(CimonRegistry.NotOwner.selector);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.BASIC_USER);

        vm.prank(owner);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.BASIC_USER);
        assertEq(uint8(registry.getProfile(acme).tier), uint8(ICimonRegistry.VerificationTier.BASIC_USER));
    }

    function test_setVerificationTier_cannotSetUnregistered() public {
        _registerAcme();
        vm.prank(attestor);
        vm.expectRevert(CimonRegistry.InvalidTier.selector);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.UNREGISTERED);
    }

    function test_setVerificationTier_requiresRegisteredPayee() public {
        vm.prank(attestor);
        vm.expectRevert(CimonRegistry.NotRegistered.selector);
        registry.setVerificationTier(stranger, ICimonRegistry.VerificationTier.VERIFIED_BUSINESS);
    }

    function test_revokedAttestorLosesRights() public {
        _registerAcme();
        vm.prank(owner);
        registry.setAttestor(attestor, false);
        vm.prank(attestor);
        vm.expectRevert(CimonRegistry.NotAttestor.selector);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.VERIFIED_BUSINESS);
    }

    // ------------------------------------------------------------------
    // Flags
    // ------------------------------------------------------------------

    function test_setFlagged_registeredPayee() public {
        _registerAcme();
        vm.prank(attestor);
        vm.expectEmit(true, true, false, true);
        emit PayeeFlagged(acme, true, "clipboard hijacker", attestor);
        registry.setFlagged(acme, true, "clipboard hijacker");

        assertTrue(registry.isFlagged(acme));
        assertTrue(registry.getProfile(acme).isFlagged);

        vm.prank(attestor);
        registry.setFlagged(acme, false, "cleared after review");
        assertFalse(registry.isFlagged(acme));
        assertFalse(registry.getProfile(acme).isFlagged);
    }

    function test_setFlagged_unregisteredAddress() public {
        vm.prank(attestor);
        registry.setFlagged(stranger, true, "lookalike address");
        assertTrue(registry.isFlagged(stranger));
        assertFalse(registry.isRegistered(stranger));
        assertTrue(registry.getProfile(stranger).isFlagged);
    }

    function test_setFlagged_accessAndInputChecks() public {
        vm.prank(stranger);
        vm.expectRevert(CimonRegistry.NotAttestor.selector);
        registry.setFlagged(acme, true, "nope");

        vm.startPrank(attestor);
        vm.expectRevert(CimonRegistry.ZeroAddress.selector);
        registry.setFlagged(address(0), true, "zero");
        vm.expectRevert(CimonRegistry.InvalidReason.selector);
        registry.setFlagged(acme, true, _repeat("r", 257));
        vm.expectRevert(CimonRegistry.InvalidReason.selector);
        registry.setFlagged(acme, true, "bad\nreason");
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // verifyPayee (Confirmation of Payee)
    // ------------------------------------------------------------------

    function test_verifyPayee_exactMatchOnLegalName() public {
        _registerAcme();
        (bool ok, ICimonRegistry.VerificationTier tier, bool flagged, string memory legal) =
            registry.verifyPayee(acme, "Acme Corp Ltd");
        assertTrue(ok);
        assertEq(uint8(tier), uint8(ICimonRegistry.VerificationTier.BASIC_USER));
        assertFalse(flagged);
        assertEq(legal, "Acme Corp Ltd");
    }

    function test_verifyPayee_matchesTradeName() public {
        _registerAcme();
        (bool ok,,,) = registry.verifyPayee(acme, "Acme Labs");
        assertTrue(ok);
    }

    function test_verifyPayee_caseInsensitiveAndTrimmed() public {
        _registerAcme();
        (bool a,,,) = registry.verifyPayee(acme, "ACME CORP LTD");
        (bool b,,,) = registry.verifyPayee(acme, "  acme corp ltd   ");
        (bool c,,,) = registry.verifyPayee(acme, "aCmE lAbS");
        assertTrue(a && b && c);
    }

    function test_verifyPayee_mismatch() public {
        _registerAcme();
        (bool a,,,) = registry.verifyPayee(acme, "Acme Corp");
        (bool b,,,) = registry.verifyPayee(acme, "Acme  Corp Ltd"); // inner double space
        (bool c,,,) = registry.verifyPayee(acme, "Acme Corp Ltd.");
        (bool d,,,) = registry.verifyPayee(acme, "Acrne Corp Ltd"); // rn lookalike
        assertFalse(a);
        assertFalse(b);
        assertFalse(c);
        assertFalse(d);
    }

    function test_verifyPayee_emptyExpectedNameNeverMatches() public {
        vm.prank(jane);
        registry.registerPayee("Jane Doe", "", "", bytes32(0)); // empty trade name too
        (bool a,,,) = registry.verifyPayee(jane, "");
        (bool b,,,) = registry.verifyPayee(jane, "    ");
        assertFalse(a, "empty must not match empty trade name");
        assertFalse(b, "spaces-only must not match");
    }

    function test_verifyPayee_unregisteredAddress() public view {
        (bool ok, ICimonRegistry.VerificationTier tier, bool flagged, string memory legal) =
            registry.verifyPayee(stranger, "Anyone");
        assertFalse(ok);
        assertEq(uint8(tier), uint8(ICimonRegistry.VerificationTier.UNREGISTERED));
        assertFalse(flagged);
        assertEq(bytes(legal).length, 0);
    }

    function test_verifyPayee_reportsFlagForUnregistered() public {
        vm.prank(attestor);
        registry.setFlagged(stranger, true, "scam");
        (,, bool flagged,) = registry.verifyPayee(stranger, "Anyone");
        assertTrue(flagged);
    }

    function test_verifyPayee_impersonatorMatchesNameButNotTier() public {
        _registerAcme();
        vm.prank(attestor);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.VERIFIED_BUSINESS);

        address impostor = makeAddr("impostor");
        vm.prank(impostor);
        registry.registerPayee("Acme Corp Ltd", "", "acme-labs.com", bytes32(0));

        (bool realOk, ICimonRegistry.VerificationTier realTier,,) = registry.verifyPayee(acme, "Acme Corp Ltd");
        (bool fakeOk, ICimonRegistry.VerificationTier fakeTier,,) = registry.verifyPayee(impostor, "Acme Corp Ltd");

        assertTrue(realOk && fakeOk, "both match on name");
        assertEq(uint8(realTier), uint8(ICimonRegistry.VerificationTier.VERIFIED_BUSINESS));
        assertEq(uint8(fakeTier), uint8(ICimonRegistry.VerificationTier.BASIC_USER), "tier tells them apart");
    }

    // ------------------------------------------------------------------
    // recordSuccessfulPayment
    // ------------------------------------------------------------------

    function test_recordSuccessfulPayment_incrementsForRegistered() public {
        _registerAcme();
        vm.expectEmit(true, true, false, true);
        emit PaymentRecorded(acme, 1, recorder);
        vm.prank(recorder);
        registry.recordSuccessfulPayment(acme);
        vm.prank(recorder);
        registry.recordSuccessfulPayment(acme);
        assertEq(registry.getProfile(acme).successfulTxCount, 2);
    }

    function test_recordSuccessfulPayment_noopForUnregistered() public {
        vm.prank(recorder);
        registry.recordSuccessfulPayment(stranger);
        assertEq(registry.getProfile(stranger).successfulTxCount, 0);
    }

    function test_recordSuccessfulPayment_onlyRecorder() public {
        _registerAcme();
        vm.prank(stranger);
        vm.expectRevert(CimonRegistry.NotRecorder.selector);
        registry.recordSuccessfulPayment(acme);

        vm.prank(attestor);
        vm.expectRevert(CimonRegistry.NotRecorder.selector);
        registry.recordSuccessfulPayment(acme);

        vm.prank(owner);
        vm.expectRevert(CimonRegistry.NotRecorder.selector);
        registry.recordSuccessfulPayment(acme);
    }

    // ------------------------------------------------------------------
    // Fuzz
    // ------------------------------------------------------------------

    /// Any clean ASCII name registers and matches itself regardless of surrounding spaces.
    function testFuzz_selfNameAlwaysMatches(uint8 len, uint256 seed, uint8 padL, uint8 padR) public {
        len = uint8(bound(len, 1, 100));
        bytes memory b = new bytes(len);
        for (uint256 i; i < len; ++i) {
            // printable ASCII excluding space (0x21..0x7e) so trimming is well defined
            b[i] = bytes1(uint8(0x21 + (uint256(keccak256(abi.encode(seed, i))) % 0x5e)));
        }
        string memory name = string(b);

        address who = makeAddr("fuzzPayee");
        vm.prank(who);
        registry.registerPayee(name, "", "", bytes32(0));

        string memory padded = string.concat(_repeat(" ", padL % 8), name, _repeat(" ", padR % 8));
        (bool ok,,,) = registry.verifyPayee(who, padded);
        assertTrue(ok);
    }

    function testFuzz_strangersCannotChangeTierOrFlags(address caller) public {
        vm.assume(caller != owner && caller != attestor);
        _registerAcme();
        vm.startPrank(caller);
        vm.expectRevert(CimonRegistry.NotAttestor.selector);
        registry.setVerificationTier(acme, ICimonRegistry.VerificationTier.VERIFIED_BUSINESS);
        vm.expectRevert(CimonRegistry.NotAttestor.selector);
        registry.setFlagged(acme, true, "x");
        vm.stopPrank();
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
