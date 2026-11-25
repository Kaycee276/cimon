import Link from 'next/link';
import { ArrowRight, ArrowUpRight } from 'lucide-react';
import { CopSimulator } from '../components/cop-simulator';
import { payAddress, registryAddress } from '../config/contracts';

export default function HomePage() {
  const configured = Boolean(payAddress && registryAddress);

  return (
    <>
      <section className="hero wrap">
        <div className="hero-copy">
          <div className="hero-kicker">
            <span className="kicker-rule" />
            PAYMENTS WITH PROOF <span className="kicker-slash">/</span> QDAY AEVUM
          </div>
          <h1>
            Know who
            <br />
            you’re <span>paying.</span>
          </h1>
          <p className="hero-lede">
            Confirmation of Payee for the post-quantum EVM. Verify the recipient’s on-chain identity
            before a single tUSD8 moves.
          </p>
          <div className="hero-ctas">
            <Link href="/invoices/create" className="button button-primary">
              Create an invoice <ArrowRight size={15} />
            </Link>
            <Link href="/register" className="button button-quiet">
              Register payee identity <ArrowUpRight size={14} />
            </Link>
          </div>
          <div className="hero-meta">
            <div className="hero-network">
              <span className="live-dot" />
              QDay Aevum Testnet <span className="meta-divider" /> Chain 44005
            </div>
            <span className="mono-small">SETTLEMENT IN tUSD8</span>
          </div>
        </div>
      </section>

      <div className="network-strip">
        <div className="wrap network-strip-inner">
          <span className="network-status">
            <span className="live-dot" />
            Network operational
          </span>
          <span>
            CHAIN <b>44005</b>
          </span>
          <span>
            ASSET <b>tUSD8 · 6 DECIMALS</b>
          </span>
          <span>
            REGISTRY <b>{configured ? 'CONNECTED' : 'AWAITING CONTRACT CONFIG'}</b>
          </span>
          <a href="https://explorer-test.qday.info" target="_blank" rel="noreferrer">
            Open explorer <ArrowUpRight size={13} />
          </a>
        </div>
      </div>

      <section className="section wrap">
        <div className="section-heading">
          <div>
            <span className="eyebrow">THE TRANSFER IS ONLY HALF THE STORY</span>
            <h2>
              Raw addresses leave
              <br />
              too much to chance.
            </h2>
          </div>
          <p>
            Crypto payments are final. CIMON adds an identity check in front of settlement, so an
            invoice can be verified before it is paid.
          </p>
        </div>
        <div className="compare-grid">
          <article className="compare-panel raw-panel">
            <div className="compare-head">
              <span className="verdict-mark verdict-mark-risk" />
              <span className="compare-label">WITHOUT CIMON</span>
              <span className="compare-tag">RAW TRANSFER</span>
            </div>
            <h3>Blind by default.</h3>
            <div className="raw-address">
              0x7a3f…9b21 <span>→</span> ???
            </div>
            <ul>
              <li>No recipient identity check</li>
              <li>Spoofed invoices look legitimate</li>
              <li>A typo can mean permanent loss</li>
            </ul>
          </article>
          <article className="compare-panel safe-panel">
            <div className="compare-head">
              <span className="verdict-mark verdict-mark-safe" />
              <span className="compare-label">WITH CIMON</span>
              <span className="compare-tag">PROTECTED FLOW</span>
            </div>
            <h3>Identity before value.</h3>
            <div className="verified-ribbon">
              <strong>Acme Labs Ltd</strong>
              <span>VERIFIED BUSINESS</span>
            </div>
            <ul>
              <li>On-chain identity and name match</li>
              <li>Risk verdict before approval</li>
              <li>Auditable receipt after settlement</li>
            </ul>
          </article>
        </div>
      </section>

      <section className="section simulator-section">
        <div className="wrap">
          <CopSimulator />
        </div>
      </section>

      <section className="section wrap flow-section">
        <div className="section-heading flow-heading">
          <div>
            <span className="eyebrow">A SAFER PAYMENT, IN THREE STEPS</span>
            <h2>Trust, then transfer.</h2>
          </div>
          <Link href="/invoices/create" className="text-link">
            Build an invoice <ArrowRight size={15} />
          </Link>
        </div>
        <div className="flow-grid">
          <article className="flow-step">
            <span className="flow-number">01</span>
            <h3>Register</h3>
            <p>
              A payee creates an identity profile on CimonRegistry. Attestors can verify business
              identities.
            </p>
            <span className="flow-contract">CIMON REGISTRY</span>
          </article>
          <article className="flow-step">
            <span className="flow-number">02</span>
            <h3>Pre-flight</h3>
            <p>
              The payer checks the registered name, verification tier and risk flags against the
              invoice.
            </p>
            <span className="flow-contract">COP CHECK</span>
          </article>
          <article className="flow-step">
            <span className="flow-number">03</span>
            <h3>Settle</h3>
            <p>Approve tUSD8, then pay directly or choose a time-delayed escrow window.</p>
            <span className="flow-contract">CIMON PAY</span>
          </article>
        </div>
      </section>

      <section className="closing-cta wrap">
        <div>
          <span className="eyebrow">START WITH A VERIFIED DESTINATION</span>
          <h2>
            Put a name before
            <br />
            every payment.
          </h2>
        </div>
        <div className="closing-actions">
          <Link href="/invoices/create" className="button button-primary">
            Create an invoice <ArrowRight size={15} />
          </Link>
          <Link href="/register" className="button button-outline">
            Register identity
          </Link>
        </div>
      </section>
    </>
  );
}
