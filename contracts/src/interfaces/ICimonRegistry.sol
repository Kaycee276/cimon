// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICimonRegistry
/// @notice Interface of the CIMON payee identity registry. Also hosts the shared
///         enum and struct definitions so that CimonPay and the frontend ABI agree.
interface ICimonRegistry {
    /// @notice Trust level of a payee. Ordering matters: higher value means more trust.
    enum VerificationTier {
        UNREGISTERED,
        BASIC_USER,
        VERIFIED_BUSINESS,
        GOV_VERIFIED
    }

    /// @notice Public identity profile of a payee.
    struct PayeeProfile {
        string legalName; // e.g. "Acme Corp Ltd" or "Jane Doe"
        string tradeName; // e.g. "Acme Labs"
        string domain; // e.g. "acmelabs.com"
        bytes32 registrationHash; // hash of legal entity ID (salted) or any salt
        address payoutAddress; // primary recipient address
        VerificationTier tier; // current trust level
        uint256 registeredAt; // unix timestamp
        bool isFlagged; // safety circuit breaker
        uint256 successfulTxCount; // settled invoices paid to this payee
    }

    function registerPayee(
        string calldata legalName,
        string calldata tradeName,
        string calldata domain,
        bytes32 registrationHash
    ) external;

    function updateProfile(
        string calldata legalName,
        string calldata tradeName,
        string calldata domain,
        bytes32 registrationHash
    ) external;

    function setVerificationTier(address payee, VerificationTier tier) external;

    function setFlagged(address payee, bool flagged, string calldata reason) external;

    function recordSuccessfulPayment(address payee) external;

    function verifyPayee(address payee, string memory expectedName)
        external
        view
        returns (bool exactMatch, VerificationTier tier, bool flagged, string memory legalName);

    function getProfile(address payee) external view returns (PayeeProfile memory);

    function isRegistered(address payee) external view returns (bool);

    function isFlagged(address payee) external view returns (bool);
}
