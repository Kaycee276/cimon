# CIMON Frontend

Next.js App Router frontend for confirmation of payee and verified tUSD8 invoicing on QDay Aevum Testnet.

## Setup

```bash
cp .env.example .env.local
# Replace the placeholder values with the deployed CimonPay and CimonRegistry addresses.
npm install
npm run dev
```

The app targets chain ID `44005` and uses the QDay testnet RPC. RainbowKit opens the browser wallet picker; connect with an installed injected EVM wallet and switch to Aevum Testnet when prompted. Wallet keys stay in the wallet and are never read from environment variables or stored by CIMON. The tUSD8 token is configured at `0x456569838f1d43009A91ebA4263147Afd7233483`.

Required environment variables:

- `NEXT_PUBLIC_CIMON_PAY_ADDRESS`
- `NEXT_PUBLIC_CIMON_REGISTRY_ADDRESS`

Both contracts must already be deployed to Aevum Testnet. Invoice creation, pre-flight checks, registration, checkout, and invoice activity remain unavailable until these values point to the deployed contracts.

## Routes

- `/` — product overview and interactive CoP simulator
- `/pay/[id]` — on-chain invoice review, tUSD8 approval, risk-capped payment, and receipt download
- `/invoices/create` — invoice builder, live CoP check, and QR payment link
- `/invoices` — incoming/outgoing invoice history and escrow actions
- `/register` — payee identity registration and profile update
- `/api/receipt/[id]` — read receipt and invoice data from Aevum

## Notes

The simulator uses illustrative sample data. Production verdicts are read from `CimonPay.copCheck` / `copCheckAddress`. The deployed `CopResult` does not expose a verified domain, so the app does not claim a domain has been attested. High risk caused by a flagged payee is blocked by the payment contract; a name mismatch can be continued only after explicit acknowledgement and only if the address is not flagged.
