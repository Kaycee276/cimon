// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICimonRegistry} from "./interfaces/ICimonRegistry.sol";

/// @title CimonRegistry
/// @author CIMON
/// @notice On-chain payee identity registry: the "Confirmation of Payee" source of truth.
///
///         Anyone can register a profile for their own address (self-asserted, tier BASIC_USER).
///         Only attestors can raise a profile to VERIFIED_BUSINESS, and only the owner can grant
///         GOV_VERIFIED. Attestors can also flag any address (registered or not) as suspect,
///         which acts as a circuit breaker inside CimonPay.
///
/// @dev    Security model and known limits:
///         - A self-registered profile proves nothing. Consumers MUST treat tier >= VERIFIED_BUSINESS
///           as the only trusted signal. An impersonator can register "Acme Corp Ltd" as BASIC_USER
///           and `verifyPayee` will report `exactMatch == true` for it, with a low tier.
///         - Changing any identity field of a profile via `updateProfile` resets a raised tier to
///           BASIC_USER, so a verified profile cannot be silently re-pointed at a new identity.
///         - Name matching is ASCII-only: it trims spaces and lowercases A-Z. It does not defend
///           against Unicode homoglyphs. Attestors are expected to review names before verifying,
///           and UIs should render names with the tier badge, not on their own.
///         - Control characters (< 0x20, 0x7f) are rejected in all text fields to prevent
///           newline or terminal-escape injection into UIs and logs.
contract CimonRegistry is ICimonRegistry {
    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    /// @notice Maximum byte length of legalName and tradeName.
    uint256 public constant MAX_NAME_LENGTH = 128;
    /// @notice Maximum byte length of a domain (DNS limit).
    uint256 public constant MAX_DOMAIN_LENGTH = 253;
    /// @notice Maximum byte length of a flag reason.
    uint256 public constant MAX_REASON_LENGTH = 256;

    // ---------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------

    /// @notice Contract owner. Can manage attestors and recorders and grant GOV_VERIFIED.
    address public owner;
    /// @notice Address nominated to become owner (two-step transfer).
    address public pendingOwner;

    /// @notice Addresses allowed to set VERIFIED_BUSINESS/BASIC_USER tiers and flags.
    ///         The owner is always an implicit attestor.
    mapping(address => bool) public attestors;

    /// @notice Contracts allowed to call `recordSuccessfulPayment` (e.g. CimonPay).
    mapping(address => bool) public recorders;

    /// @notice Number of registered payees.
    uint256 public totalPayees;

    mapping(address => PayeeProfile) private _profiles;
    mapping(address => bool) private _flagged;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event PayeeRegistered(
        address indexed payee, string legalName, string tradeName, string domain, bytes32 registrationHash
    );
    event ProfileUpdated(
        address indexed payee, string legalName, string tradeName, string domain, bytes32 registrationHash
    );
    event TierSet(address indexed payee, VerificationTier oldTier, VerificationTier newTier, address indexed by);
    event PayeeFlagged(address indexed payee, bool flagged, string reason, address indexed by);
    event PaymentRecorded(address indexed payee, uint256 newCount, address indexed recorder);
    event AttestorSet(address indexed attestor, bool enabled);
    event RecorderSet(address indexed recorder, bool enabled);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error NotOwner();
    error NotPendingOwner();
    error NotAttestor();
    error NotRecorder();
    error ZeroAddress();
    error AlreadyRegistered();
    error NotRegistered();
    error InvalidName();
    error InvalidDomain();
    error InvalidReason();
    error InvalidTier();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyAttestor() {
        if (msg.sender != owner && !attestors[msg.sender]) revert NotAttestor();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    /// @param initialOwner Address that becomes the owner (and implicit attestor).
    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    // ---------------------------------------------------------------------
    // Payee self-service
    // ---------------------------------------------------------------------

    /// @notice Register the caller as a payee. The caller's address becomes the payout address.
    /// @dev    New profiles start at BASIC_USER. If the address was flagged before it registered,
    ///         the flag is preserved.
    /// @param legalName Legal name of the entity or person (1 to 128 bytes).
    /// @param tradeName Optional trade/brand name (0 to 128 bytes).
    /// @param domain Optional verified-by-attestor domain, e.g. "acmelabs.com" (0 to 253 bytes).
    /// @param registrationHash Hash of a legal entity ID or a random salt. May be zero.
    function registerPayee(
        string calldata legalName,
        string calldata tradeName,
        string calldata domain,
        bytes32 registrationHash
    ) external {
        if (_profiles[msg.sender].tier != VerificationTier.UNREGISTERED) {
            revert AlreadyRegistered();
        }
        _validateProfileText(legalName, tradeName, domain);

        _profiles[msg.sender] = PayeeProfile({
            legalName: legalName,
            tradeName: tradeName,
            domain: domain,
            registrationHash: registrationHash,
            payoutAddress: msg.sender,
            tier: VerificationTier.BASIC_USER,
            registeredAt: block.timestamp,
            isFlagged: _flagged[msg.sender],
            successfulTxCount: 0
        });
        unchecked {
            ++totalPayees;
        }

        emit PayeeRegistered(msg.sender, legalName, tradeName, domain, registrationHash);
    }

    /// @notice Update the caller's own profile.
    /// @dev    If any identity field changes and the tier was above BASIC_USER, the tier is reset
    ///         to BASIC_USER so that attestations cannot be carried over to a different identity.
    function updateProfile(
        string calldata legalName,
        string calldata tradeName,
        string calldata domain,
        bytes32 registrationHash
    ) external {
        PayeeProfile storage p = _profiles[msg.sender];
        if (p.tier == VerificationTier.UNREGISTERED) revert NotRegistered();
        _validateProfileText(legalName, tradeName, domain);

        bool changed = keccak256(bytes(legalName)) != keccak256(bytes(p.legalName))
            || keccak256(bytes(tradeName)) != keccak256(bytes(p.tradeName))
            || keccak256(bytes(domain)) != keccak256(bytes(p.domain)) || registrationHash != p.registrationHash;

        p.legalName = legalName;
        p.tradeName = tradeName;
        p.domain = domain;
        p.registrationHash = registrationHash;

        if (changed && p.tier != VerificationTier.BASIC_USER) {
            VerificationTier old = p.tier;
            p.tier = VerificationTier.BASIC_USER;
            emit TierSet(msg.sender, old, VerificationTier.BASIC_USER, msg.sender);
        }

        emit ProfileUpdated(msg.sender, legalName, tradeName, domain, registrationHash);
    }

    // ---------------------------------------------------------------------
    // Attestor / owner actions
    // ---------------------------------------------------------------------

    /// @notice Set the verification tier of a registered payee.
    /// @dev    Attestors may set BASIC_USER or VERIFIED_BUSINESS. Only the owner may grant
    ///         GOV_VERIFIED, or change a profile that is currently GOV_VERIFIED.
    ///         UNREGISTERED cannot be set; flag the address instead.
    function setVerificationTier(address payee, VerificationTier tier) external onlyAttestor {
        if (tier == VerificationTier.UNREGISTERED) revert InvalidTier();
        PayeeProfile storage p = _profiles[payee];
        VerificationTier old = p.tier;
        if (old == VerificationTier.UNREGISTERED) revert NotRegistered();
        if ((tier == VerificationTier.GOV_VERIFIED || old == VerificationTier.GOV_VERIFIED) && msg.sender != owner) {
            revert NotOwner();
        }
        p.tier = tier;
        emit TierSet(payee, old, tier, msg.sender);
    }

    /// @notice Flag or unflag any address as suspect. Works for unregistered addresses too.
    /// @param payee Address to flag.
    /// @param flagged True to flag, false to clear.
    /// @param reason Short human-readable reason (0 to 256 bytes), emitted for auditability.
    function setFlagged(address payee, bool flagged, string calldata reason) external onlyAttestor {
        if (payee == address(0)) revert ZeroAddress();
        if (!_isCleanText(bytes(reason), MAX_REASON_LENGTH, true)) revert InvalidReason();
        _flagged[payee] = flagged;
        if (_profiles[payee].tier != VerificationTier.UNREGISTERED) {
            _profiles[payee].isFlagged = flagged;
        }
        emit PayeeFlagged(payee, flagged, reason, msg.sender);
    }

    /// @notice Record a successful settled payment for a payee. Callable only by recorders.
    /// @dev    A no-op for unregistered payees so that payments to them never revert here.
    function recordSuccessfulPayment(address payee) external {
        if (!recorders[msg.sender]) revert NotRecorder();
        PayeeProfile storage p = _profiles[payee];
        if (p.tier == VerificationTier.UNREGISTERED) return;
        uint256 newCount;
        unchecked {
            newCount = ++p.successfulTxCount;
        }
        emit PaymentRecorded(payee, newCount, msg.sender);
    }

    /// @notice Grant or revoke attestor rights.
    function setAttestor(address attestor, bool enabled) external onlyOwner {
        if (attestor == address(0)) revert ZeroAddress();
        attestors[attestor] = enabled;
        emit AttestorSet(attestor, enabled);
    }

    /// @notice Grant or revoke the right to call `recordSuccessfulPayment`.
    function setRecorder(address recorder, bool enabled) external onlyOwner {
        if (recorder == address(0)) revert ZeroAddress();
        recorders[recorder] = enabled;
        emit RecorderSet(recorder, enabled);
    }

    /// @notice Start a two-step ownership transfer.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /// @notice Complete the ownership transfer. Must be called by the pending owner.
    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        address previous = owner;
        owner = msg.sender;
        pendingOwner = address(0);
        emit OwnershipTransferred(previous, msg.sender);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    /// @notice Confirmation of Payee: does `expectedName` match the identity behind `payee`?
    /// @dev    Matching is case-insensitive (ASCII) and ignores leading/trailing spaces. The name
    ///         may match either the legal name or the trade name. An empty `expectedName` never
    ///         matches. Unregistered addresses never match and return an empty legal name.
    /// @param payee Address funds would be sent to.
    /// @param expectedName Name the payer believes they are paying.
    /// @return exactMatch True if the name matches the registered legal or trade name.
    /// @return tier Verification tier of the payee (UNREGISTERED if unknown).
    /// @return flagged True if the address is flagged as suspect.
    /// @return legalName Registered legal name, empty if unregistered.
    function verifyPayee(address payee, string memory expectedName)
        public
        view
        returns (bool exactMatch, VerificationTier tier, bool flagged, string memory legalName)
    {
        PayeeProfile storage p = _profiles[payee];
        tier = p.tier;
        flagged = _flagged[payee];
        if (tier == VerificationTier.UNREGISTERED) {
            return (false, tier, flagged, "");
        }
        legalName = p.legalName;
        bytes32 expected = _normalizedHash(expectedName);
        exactMatch = expected != bytes32(0)
            && (expected == _normalizedHash(p.legalName) || expected == _normalizedHash(p.tradeName));
    }

    /// @notice Full profile of a payee. For unregistered addresses all fields are zero except
    ///         `isFlagged`, which reflects the flag set on the address.
    function getProfile(address payee) external view returns (PayeeProfile memory profile) {
        profile = _profiles[payee];
        profile.isFlagged = _flagged[payee];
    }

    /// @notice Whether the address has registered a profile.
    function isRegistered(address payee) external view returns (bool) {
        return _profiles[payee].tier != VerificationTier.UNREGISTERED;
    }

    /// @notice Whether the address is flagged as suspect.
    function isFlagged(address payee) external view returns (bool) {
        return _flagged[payee];
    }

    // ---------------------------------------------------------------------
    // Internals
    // ---------------------------------------------------------------------

    function _validateProfileText(string calldata legalName, string calldata tradeName, string calldata domain)
        private
        pure
    {
        if (!_isCleanText(bytes(legalName), MAX_NAME_LENGTH, false)) revert InvalidName();
        if (!_isCleanText(bytes(tradeName), MAX_NAME_LENGTH, true)) revert InvalidName();
        if (!_isCleanText(bytes(domain), MAX_DOMAIN_LENGTH, true)) revert InvalidDomain();
    }

    /// @dev True if length is within bounds and no control characters are present.
    function _isCleanText(bytes memory b, uint256 maxLen, bool allowEmpty) private pure returns (bool) {
        uint256 len = b.length;
        if (len > maxLen) return false;
        if (len == 0) return allowEmpty;
        for (uint256 i; i < len; ++i) {
            bytes1 c = b[i];
            if (c < 0x20 || c == 0x7f) return false;
        }
        return true;
    }

    /// @dev Hash of the string after trimming spaces and lowercasing ASCII A-Z.
    ///      Returns bytes32(0) for strings that are empty after trimming.
    function _normalizedHash(string memory s) private pure returns (bytes32) {
        bytes memory b = bytes(s);
        uint256 start;
        uint256 end = b.length;
        while (start < end && b[start] == 0x20) ++start;
        while (end > start && b[end - 1] == 0x20) --end;
        if (start == end) return bytes32(0);

        bytes memory out = new bytes(end - start);
        for (uint256 i; i < out.length; ++i) {
            bytes1 c = b[start + i];
            if (c >= 0x41 && c <= 0x5a) {
                c = bytes1(uint8(c) + 32);
            }
            out[i] = c;
        }
        return keccak256(out);
    }
}
