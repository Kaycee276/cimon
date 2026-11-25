// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "./interfaces/IERC20.sol";
import {ICimonRegistry} from "./interfaces/ICimonRegistry.sol";

/// @title CimonPay
/// @author CIMON
/// @notice Verified invoicing and tUSD8 settlement with a Confirmation of Payee (CoP) pre-flight.
///
///         Flow:
///         1. A merchant creates an invoice naming the address that must be paid (`expectedPayee`),
///            optionally the business name the payer should expect, and an optional safety delay.
///         2. The payer's UI calls `copCheck(id)` to get a VERIFIED / CAUTION / HIGH_RISK verdict
///            computed from CimonRegistry, then pays with `payInvoiceWithRiskCap`.
///         3. With no safety delay, funds go straight from payer to payee. With a safety delay,
///            funds are held in escrow; the payer can cancel until the window ends, after which
///            anyone can release the funds to the payee.
///
/// @dev    Design notes:
///         - Funds can only ever go to `expectedPayee` (settlement) or back to `actualPayer`
///           (refund). The contract has no owner, no upgrade path and no admin withdrawal.
///         - A payee flagged in the registry is blocked from receiving payments. If a payee is
///           flagged while funds are escrowed, the payer may reclaim them even after the window.
///         - `payInvoiceWithRiskCap` closes the check-then-pay gap: if the registry changes
///           between the UI's pre-flight and the transaction, the payment reverts instead of
///           silently going through at a worse risk level.
///         - Escrow accounting rejects fee-on-transfer tokens by checking the balance delta.
///         - All state changes happen before external token calls and all mutating entry points
///           are guarded by a reentrancy lock.
///         - Registry bookkeeping (`recordSuccessfulPayment`) is best-effort and can never block
///           or revert a payment.
contract CimonPay {
    // ---------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------

    enum InvoiceStatus {
        PENDING,
        ESCROWED,
        SETTLED,
        CANCELLED,
        REFUNDED
    }

    /// @notice Pre-flight verdict. Ordered from safest to riskiest.
    enum RiskLevel {
        VERIFIED, // Tier 1: verified identity, name matches (or no name was specified)
        CAUTION, // Tier 2: unverified or new payee, identity cannot be confirmed
        HIGH_RISK // Tier 3: flagged address, or registered name contradicts the expected name
    }

    struct Invoice {
        bytes32 id;
        address merchant;
        address expectedPayee;
        uint256 amount; // tUSD8, 6 decimals
        string memo; // invoice description / order ID
        uint256 safetyDelay; // seconds; 0 = instant settlement
        uint256 paidAt; // timestamp of payment (0 until paid)
        InvoiceStatus status;
        address actualPayer;
    }

    /// @notice Cryptographic receipt issued when an invoice settles.
    struct Receipt {
        uint256 settledAt;
        bytes32 receiptHash;
    }

    /// @notice Result of a Confirmation of Payee check.
    struct CopResult {
        RiskLevel risk;
        bool registered;
        bool nameChecked; // false when the invoice carries no expected name
        bool exactMatch; // expected name matches registered legal or trade name
        ICimonRegistry.VerificationTier tier;
        bool isFlagged;
        string legalName; // registered legal name, empty if unregistered
        uint256 successfulTxCount;
    }

    // ---------------------------------------------------------------------
    // Constants and immutables
    // ---------------------------------------------------------------------

    uint256 public constant MIN_SAFETY_DELAY = 60 seconds;
    uint256 public constant MAX_SAFETY_DELAY = 7 days;
    uint256 public constant MAX_MEMO_LENGTH = 280;
    uint256 public constant MAX_NAME_LENGTH = 128;

    /// @notice Settlement token (tUSD8 on Aevum Testnet).
    IERC20 public immutable token;
    /// @notice Payee identity registry.
    ICimonRegistry public immutable registry;

    // ---------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------

    mapping(bytes32 => Invoice) private _invoices;
    mapping(bytes32 => string) private _expectedNames;
    mapping(bytes32 => Receipt) private _receipts;
    mapping(address => uint256) public merchantNonce;
    mapping(address => bytes32[]) private _merchantInvoices;
    mapping(address => bytes32[]) private _payerInvoices;

    uint256 private _lock = 1;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event InvoiceCreated(
        bytes32 indexed id,
        address indexed merchant,
        address indexed expectedPayee,
        uint256 amount,
        uint256 safetyDelay,
        string memo,
        string expectedName
    );
    event InvoicePaid(bytes32 indexed id, address indexed payer, address indexed payee, uint256 amount);
    event EscrowHeld(bytes32 indexed id, uint256 releaseTime);
    event InvoiceSettled(bytes32 indexed id, address indexed payee, uint256 amount, bytes32 receiptHash);
    event EscrowRefunded(bytes32 indexed id, address indexed payer, uint256 amount);
    event InvoiceCancelled(bytes32 indexed id, address indexed merchant);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error ZeroAddress();
    error ZeroAmount();
    error InvalidSafetyDelay();
    error MemoTooLong();
    error NameTooLong();
    error InvoiceNotFound();
    error InvalidStatus(InvoiceStatus current);
    error PayeeFlagged(address payee);
    error RiskExceedsLimit(RiskLevel actual, RiskLevel limit);
    error SelfPayment();
    error NotMerchant();
    error NotPayer();
    error EscrowNotReleasable(uint256 releaseTime);
    error DisputeWindowClosed(uint256 windowEnd);
    error TokenTransferFailed();
    error UnexpectedTokenAmount();
    error Reentrancy();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier nonReentrant() {
        if (_lock != 1) revert Reentrancy();
        _lock = 2;
        _;
        _lock = 1;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    /// @param token_ ERC-20 settlement token (tUSD8: 0x456569838f1d43009A91ebA4263147Afd7233483).
    /// @param registry_ CimonRegistry used for Confirmation of Payee checks.
    constructor(IERC20 token_, ICimonRegistry registry_) {
        if (address(token_) == address(0) || address(registry_) == address(0)) revert ZeroAddress();
        token = token_;
        registry = registry_;
    }

    // ---------------------------------------------------------------------
    // Invoice creation
    // ---------------------------------------------------------------------

    /// @notice Create an invoice without an expected business name.
    /// @param expectedPayee Address that must receive the funds.
    /// @param amount Amount in tUSD8 base units (6 decimals).
    /// @param memo Invoice description or order ID (max 280 bytes).
    /// @param safetyDelay 0 for instant settlement, otherwise 60 seconds to 7 days of escrow.
    /// @return invoiceId Unique invoice id.
    function createInvoice(address expectedPayee, uint256 amount, string memory memo, uint256 safetyDelay)
        external
        returns (bytes32 invoiceId)
    {
        return _create(expectedPayee, amount, memo, safetyDelay, "");
    }

    /// @notice Create an invoice that also carries the business name the payer should expect.
    ///         The name is what the CoP check compares against the registry.
    /// @param expectedName Name the payer expects to be paying (max 128 bytes).
    function createInvoiceWithName(
        address expectedPayee,
        uint256 amount,
        string memory memo,
        uint256 safetyDelay,
        string memory expectedName
    ) external returns (bytes32 invoiceId) {
        return _create(expectedPayee, amount, memo, safetyDelay, expectedName);
    }

    // ---------------------------------------------------------------------
    // Payment
    // ---------------------------------------------------------------------

    /// @notice Pay an invoice. Reverts if the payee is flagged. Accepts any non-flagged risk level;
    ///         prefer `payInvoiceWithRiskCap` from UIs.
    /// @dev    Requires prior ERC-20 approval of `amount` to this contract.
    function payInvoice(bytes32 invoiceId) external nonReentrant {
        _pay(invoiceId, RiskLevel.HIGH_RISK);
    }

    /// @notice Pay an invoice, reverting if the live CoP verdict is riskier than `maxRisk`.
    /// @param invoiceId Invoice to pay.
    /// @param maxRisk The riskiest verdict the payer accepted when they reviewed the pre-flight.
    function payInvoiceWithRiskCap(bytes32 invoiceId, RiskLevel maxRisk) external nonReentrant {
        _pay(invoiceId, maxRisk);
    }

    /// @notice Release escrowed funds to the payee once the safety delay has passed.
    ///         Callable by anyone; funds can only go to `expectedPayee`.
    function claimEscrow(bytes32 invoiceId) external nonReentrant {
        Invoice storage inv = _requireInvoice(invoiceId);
        if (inv.status != InvoiceStatus.ESCROWED) revert InvalidStatus(inv.status);

        uint256 releaseAt = inv.paidAt + inv.safetyDelay;
        if (block.timestamp < releaseAt) revert EscrowNotReleasable(releaseAt);

        address payee = inv.expectedPayee;
        if (registry.isFlagged(payee)) revert PayeeFlagged(payee);

        inv.status = InvoiceStatus.SETTLED;
        bytes32 receiptHash = _issueReceipt(invoiceId, inv);
        uint256 amount = inv.amount;

        _safeTransfer(payee, amount);
        _recordPayment(payee);

        emit InvoiceSettled(invoiceId, payee, amount, receiptHash);
    }

    /// @notice Payer cancels an escrowed payment and reclaims the funds.
    /// @dev    Allowed while the safety window is open, or at any time while the payee is flagged.
    function disputeOrCancel(bytes32 invoiceId) external nonReentrant {
        Invoice storage inv = _requireInvoice(invoiceId);
        if (inv.status != InvoiceStatus.ESCROWED) revert InvalidStatus(inv.status);
        if (msg.sender != inv.actualPayer) revert NotPayer();

        uint256 windowEnd = inv.paidAt + inv.safetyDelay;
        if (block.timestamp >= windowEnd && !registry.isFlagged(inv.expectedPayee)) {
            revert DisputeWindowClosed(windowEnd);
        }

        inv.status = InvoiceStatus.REFUNDED;
        uint256 amount = inv.amount;
        _safeTransfer(msg.sender, amount);

        emit EscrowRefunded(invoiceId, msg.sender, amount);
    }

    /// @notice Merchant cancels an invoice that has not been paid.
    function cancelInvoice(bytes32 invoiceId) external nonReentrant {
        Invoice storage inv = _requireInvoice(invoiceId);
        if (msg.sender != inv.merchant) revert NotMerchant();
        if (inv.status != InvoiceStatus.PENDING) revert InvalidStatus(inv.status);
        inv.status = InvoiceStatus.CANCELLED;
        emit InvoiceCancelled(invoiceId, msg.sender);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    /// @notice Full invoice data.
    function getInvoice(bytes32 invoiceId) external view returns (Invoice memory) {
        return _requireInvoice(invoiceId);
    }

    /// @notice Business name the invoice creator expects the payee to have (may be empty).
    function getExpectedName(bytes32 invoiceId) external view returns (string memory) {
        _requireInvoice(invoiceId);
        return _expectedNames[invoiceId];
    }

    /// @notice Pre-flight Confirmation of Payee check for an invoice.
    function copCheck(bytes32 invoiceId) external view returns (CopResult memory) {
        Invoice storage inv = _requireInvoice(invoiceId);
        return _assess(inv.expectedPayee, _expectedNames[invoiceId]);
    }

    /// @notice Pre-flight check for an arbitrary address and expected name, without an invoice.
    function copCheckAddress(address payee, string memory expectedName) external view returns (CopResult memory) {
        return _assess(payee, expectedName);
    }

    /// @notice Timestamp at which an escrowed invoice becomes claimable, or 0 if not escrowed.
    function releaseTime(bytes32 invoiceId) external view returns (uint256) {
        Invoice storage inv = _requireInvoice(invoiceId);
        if (inv.status != InvoiceStatus.ESCROWED) return 0;
        return inv.paidAt + inv.safetyDelay;
    }

    /// @notice Receipt of a settled invoice. Zero values if not settled.
    function getReceipt(bytes32 invoiceId) external view returns (Receipt memory) {
        return _receipts[invoiceId];
    }

    /// @notice Recompute the receipt hash of a settled invoice from live invoice data.
    /// @dev    hash = keccak256(abi.encode(chainId, thisContract, id, merchant, expectedPayee,
    ///                actualPayer, amount, keccak256(memo), paidAt, settledAt)).
    ///         Equals `getReceipt(id).receiptHash`; lets anyone audit a receipt off-chain.
    function computeReceiptHash(bytes32 invoiceId) external view returns (bytes32) {
        Invoice storage inv = _requireInvoice(invoiceId);
        if (inv.status != InvoiceStatus.SETTLED) revert InvalidStatus(inv.status);
        return _hashReceipt(inv, _receipts[invoiceId].settledAt);
    }

    function merchantInvoiceCount(address merchant) external view returns (uint256) {
        return _merchantInvoices[merchant].length;
    }

    function payerInvoiceCount(address payer) external view returns (uint256) {
        return _payerInvoices[payer].length;
    }

    /// @notice Paginated invoice ids created by `merchant`, oldest first.
    function getMerchantInvoiceIds(address merchant, uint256 offset, uint256 limit)
        external
        view
        returns (bytes32[] memory)
    {
        return _slice(_merchantInvoices[merchant], offset, limit);
    }

    /// @notice Paginated invoice ids paid (or escrowed) by `payer`, oldest first.
    function getPayerInvoiceIds(address payer, uint256 offset, uint256 limit) external view returns (bytes32[] memory) {
        return _slice(_payerInvoices[payer], offset, limit);
    }

    // ---------------------------------------------------------------------
    // Internals
    // ---------------------------------------------------------------------

    function _create(
        address expectedPayee,
        uint256 amount,
        string memory memo,
        uint256 safetyDelay,
        string memory expectedName
    ) private returns (bytes32 invoiceId) {
        if (expectedPayee == address(0) || expectedPayee == address(this)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (safetyDelay != 0 && (safetyDelay < MIN_SAFETY_DELAY || safetyDelay > MAX_SAFETY_DELAY)) {
            revert InvalidSafetyDelay();
        }
        if (bytes(memo).length > MAX_MEMO_LENGTH) revert MemoTooLong();
        if (bytes(expectedName).length > MAX_NAME_LENGTH) revert NameTooLong();
        if (registry.isFlagged(expectedPayee)) revert PayeeFlagged(expectedPayee);

        invoiceId = keccak256(abi.encode(block.chainid, address(this), msg.sender, merchantNonce[msg.sender]++));

        Invoice storage inv = _invoices[invoiceId];
        inv.id = invoiceId;
        inv.merchant = msg.sender;
        inv.expectedPayee = expectedPayee;
        inv.amount = amount;
        inv.memo = memo;
        inv.safetyDelay = safetyDelay;
        inv.status = InvoiceStatus.PENDING;

        if (bytes(expectedName).length != 0) {
            _expectedNames[invoiceId] = expectedName;
        }
        _merchantInvoices[msg.sender].push(invoiceId);

        emit InvoiceCreated(invoiceId, msg.sender, expectedPayee, amount, safetyDelay, memo, expectedName);
    }

    function _pay(bytes32 invoiceId, RiskLevel maxRisk) private {
        Invoice storage inv = _requireInvoice(invoiceId);
        if (inv.status != InvoiceStatus.PENDING) revert InvalidStatus(inv.status);

        address payee = inv.expectedPayee;
        if (msg.sender == payee) revert SelfPayment();

        CopResult memory cop = _assess(payee, _expectedNames[invoiceId]);
        if (cop.isFlagged) revert PayeeFlagged(payee);
        if (uint8(cop.risk) > uint8(maxRisk)) revert RiskExceedsLimit(cop.risk, maxRisk);

        uint256 amount = inv.amount;
        inv.actualPayer = msg.sender;
        inv.paidAt = block.timestamp;
        _payerInvoices[msg.sender].push(invoiceId);

        if (inv.safetyDelay == 0) {
            // Instant settlement: effects first, then a single transfer payer -> payee.
            inv.status = InvoiceStatus.SETTLED;
            bytes32 receiptHash = _issueReceipt(invoiceId, inv);

            _safeTransferFrom(msg.sender, payee, amount);
            _recordPayment(payee);

            emit InvoicePaid(invoiceId, msg.sender, payee, amount);
            emit InvoiceSettled(invoiceId, payee, amount, receiptHash);
        } else {
            // Escrow: pull funds into this contract and hold until the window passes.
            inv.status = InvoiceStatus.ESCROWED;

            uint256 balanceBefore = token.balanceOf(address(this));
            _safeTransferFrom(msg.sender, address(this), amount);
            if (token.balanceOf(address(this)) - balanceBefore != amount) revert UnexpectedTokenAmount();

            emit InvoicePaid(invoiceId, msg.sender, payee, amount);
            emit EscrowHeld(invoiceId, block.timestamp + inv.safetyDelay);
        }
    }

    function _assess(address payee, string memory expectedName) private view returns (CopResult memory r) {
        (bool exactMatch, ICimonRegistry.VerificationTier tier, bool flagged, string memory legalName) =
            registry.verifyPayee(payee, expectedName);

        r.exactMatch = exactMatch;
        r.tier = tier;
        r.isFlagged = flagged;
        r.legalName = legalName;
        r.registered = tier != ICimonRegistry.VerificationTier.UNREGISTERED;
        r.nameChecked = bytes(expectedName).length != 0;
        if (r.registered) {
            r.successfulTxCount = registry.getProfile(payee).successfulTxCount;
        }

        if (flagged || (r.registered && r.nameChecked && !exactMatch)) {
            r.risk = RiskLevel.HIGH_RISK;
        } else if (tier >= ICimonRegistry.VerificationTier.VERIFIED_BUSINESS && (!r.nameChecked || exactMatch)) {
            r.risk = RiskLevel.VERIFIED;
        } else {
            r.risk = RiskLevel.CAUTION;
        }
    }

    function _requireInvoice(bytes32 invoiceId) private view returns (Invoice storage inv) {
        inv = _invoices[invoiceId];
        if (inv.merchant == address(0)) revert InvoiceNotFound();
    }

    function _issueReceipt(bytes32 invoiceId, Invoice storage inv) private returns (bytes32 receiptHash) {
        receiptHash = _hashReceipt(inv, block.timestamp);
        _receipts[invoiceId] = Receipt({settledAt: block.timestamp, receiptHash: receiptHash});
    }

    function _hashReceipt(Invoice storage inv, uint256 settledAt) private view returns (bytes32) {
        bytes32 memoHash = keccak256(bytes(inv.memo));
        return keccak256(
            abi.encode(
                block.chainid,
                address(this),
                inv.id,
                inv.merchant,
                inv.expectedPayee,
                inv.actualPayer,
                inv.amount,
                memoHash,
                inv.paidAt,
                settledAt
            )
        );
    }

    /// @dev Best-effort reputation bookkeeping. Never reverts the payment.
    function _recordPayment(address payee) private {
        try registry.recordSuccessfulPayment(payee) {} catch {}
    }

    function _slice(bytes32[] storage arr, uint256 offset, uint256 limit) private view returns (bytes32[] memory out) {
        uint256 len = arr.length;
        if (offset >= len) return new bytes32[](0);
        uint256 end = offset + limit;
        if (end > len || end < offset) end = len;
        out = new bytes32[](end - offset);
        for (uint256 i; i < out.length; ++i) {
            out[i] = arr[offset + i];
        }
    }

    /// @dev Handles tokens that return nothing (USDT style) and tokens that return false.
    function _safeTransfer(address to, uint256 amount) private {
        _callToken(abi.encodeCall(IERC20.transfer, (to, amount)));
    }

    function _safeTransferFrom(address from, address to, uint256 amount) private {
        _callToken(abi.encodeCall(IERC20.transferFrom, (from, to, amount)));
    }

    function _callToken(bytes memory data) private {
        address t = address(token);
        if (t.code.length == 0) revert TokenTransferFailed();
        (bool ok, bytes memory ret) = t.call(data);
        if (!ok || (ret.length != 0 && (ret.length < 32 || !abi.decode(ret, (bool))))) {
            revert TokenTransferFailed();
        }
    }
}
