# CIMON

**Confirmation of Payee (CoP) & Verified Invoicing Protocol for QDay Aevum Testnet**

[![CI](https://github.com/Kaycee276/cimon/actions/workflows/ci.yml/badge.svg)](https://github.com/Kaycee276/cimon/actions/workflows/ci.yml)
[![Live App](https://img.shields.io/badge/Live%20App-cimon.izuaba.xyz-00E599?style=flat&logo=vercel)](https://cimon.izuaba.xyz/)
[![Network](https://img.shields.io/badge/QDay%20Aevum%20Testnet-Chain%20ID%2044005-7C3AED)](https://explorer-test.qday.info)

CIMON brings banking-grade **Confirmation of Payee (CoP)** to decentralized stablecoin commerce on the QDay Aevum Layer-1 blockchain. Before transferring funds, payers run on-chain pre-flight identity verifications to prevent misdirected payments, impersonation, and fraud. Payments settle in **tUSD8** with built-in escrow windows and programmable safety delays.

Built for the **[QDay Aevum Builder Challenge #1](https://qday.io/builder-challenge)**.

---

## Live Deployment

- **Live Frontend**: [https://cimon.izuaba.xyz/](https://cimon.izuaba.xyz/)
- **Repository**: [github.com/Kaycee276/cimon](https://github.com/Kaycee276/cimon)
- **Chain ID**: `44005` (QDay Aevum Testnet)
- **Settlement Token (tUSD8)**: [`0x456569838f1d43009A91ebA4263147Afd7233483`](https://explorer-test.qday.info/address/0x456569838f1d43009A91ebA4263147Afd7233483)

---

## Core Protocol Architecture

```
                       ┌────────────────────────────┐
                       │       CimonRegistry        │
                       │ ────────────────────────── │
                       │ • Payee identity profiles  │
                       │ • Legal & trade names      │
                       │ • Identity tiers (0 to 3)  │
                       │ • Fraud flags & blacklist  │
                       └─────────────▲──────────────┘
                                     │ verifies
                                     │ payee identity
┌──────────────┐       ┌─────────────┴──────────────┐       ┌──────────────┐
│    Payer     ├──────►│          CimonPay          ├──────►│   Merchant   │
│              │       │ ────────────────────────── │       │              │
│ • CoP verify │       │ • Pre-flight check (verdict│       │ • Invoice    │
│ • Risk cap   │       │ • tUSD8 escrow mechanism   │       │   generation │
│ • Settle /   │       │ • Programmable safety delay│       │ • Claim funds│
│   Dispute    │       │ • Cryptographic receipt hash│       │ • Cancel     │
└──────────────┘       └────────────────────────────┘       └──────────────┘
```

### 1. `CimonRegistry.sol`
- **Identity Registry**: Maps payee wallet addresses to registered legal names, trade names, verified domains, and official registration hashes.
- **Hierarchical Identity Tiers**:
  - `0`: `UNREGISTERED`
  - `1`: `BASIC_USER` (self-asserted)
  - `2`: `VERIFIED_BUSINESS` (attestor / challenge verified)
  - `3`: `GOV_VERIFIED` (owner / authority verified)
- **Demotion on Edit**: Modifying identity fields drops verified status back to `BASIC_USER` until re-verified.
- **Flagging**: Blacklisted or reported malicious addresses are flagged on-chain.

### 2. `CimonPay.sol`
- **Confirmation of Payee (CoP)**: Pre-flight function `copCheck(invoiceId)` and `copCheckAddress(payee, expectedName)` returns a real-time risk verdict:
  - 🟢 **VERIFIED (0)**: Payee is registered at Tier 2+, name matches exactly, and no fraud flags exist.
  - 🟡 **CAUTION (1)**: Payee name does not match, or payee is self-asserted (Tier 1). Requires explicit user acknowledgement.
  - 🔴 **HIGH RISK (2)**: Payee is flagged for fraud or blacklisted. Reverts on-chain to block malicious drainers.
- **Risk-Capped Checkout**: `payInvoiceWithRiskCap(invoiceId, maxRisk)` ensures transactions automatically revert if the payee's status deteriorates between UI pre-flight and execution block.
- **Escrow & Safety Delays**: Payers are protected by programmable delays (e.g., 24 hours). Funds can be claimed by payee after release time, or reclaimed by payer in dispute scenarios.
- **On-chain Settlement Proof**: Settled payments generate unique cryptographic receipt hashes read via `getReceipt(invoiceId)`.

---

## Verification & Test Suites (171 Total Tests)

### Smart Contracts (133 Tests via Foundry)
```bash
cd contracts
forge test -vvv
```
- **82 Integration Tests**: Every invoice state transition (`Created` ➔ `Paid` ➔ `Claimed` / `Disputed` / `Cancelled`).
- **47 Registry Tests**: Name normalization, case-insensitive comparison, tier promotions, and access controls.
- **4 Stateful Fuzz Invariant Tests**:
  - `invariant_balanceEqualsEscrowedAmounts`: Contract balance strictly matches sum of active escrows.
  - `invariant_tokenConservation`: No tokens created or lost during operations.
  - `invariant_payeeBalancesMatchSettledInvoices`: Exact accounting of settled funds.
  - `invariant_receiptsOnlyForSettled`: Receipts exist exclusively for settled invoices.

### Frontend (38 Tests via Vitest & React Testing Library)
```bash
pnpm --filter cimon-frontend test
```
- Component tests for Confirmation of Payee pre-flight cards (`cop-preflight-card.test.tsx`), receipt modals (`receipt-modal.test.tsx`), navbar drawer (`navbar.test.tsx`), and responsive footer (`footer.test.tsx`).
- Unit tests for formatting, address validation, contract ABIs, and Aevum chain definitions.
- Route tests for `/api/receipt/[id]`.

---

## Continuous Integration (CI/CD)

Every commit and pull request is automatically tested through [GitHub Actions](.github/workflows/ci.yml):
- **Contracts CI**: Automated Foundry install, `forge fmt --check`, `forge build --sizes`, and full test execution.
- **Frontend CI**: Node 22 + pnpm 11, Prettier format check, ESLint clean pass, TypeScript strict typecheck, Vitest test suite, and Next.js production build.

---

## Local Development

### Prerequisites
- [Foundry](https://getfoundry.sh/) (`forge`)
- [Node.js](https://nodejs.org/) (v22+)
- [pnpm](https://pnpm.io/) (`pnpm@11.18.0`)

### Quick Start
```bash
# 1. Clone repository
git clone https://github.com/Kaycee276/cimon.git && cd cimon

# 2. Install workspace dependencies
pnpm install

# 3. Run all tests (contracts + frontend)
pnpm test

# 4. Start Next.js development server
pnpm dev
```

---

## License

MIT
