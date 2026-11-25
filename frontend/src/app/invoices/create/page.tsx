'use client';
import { useEffect, useState } from 'react';
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useSwitchChain,
  useWaitForTransactionReceipt,
  useWriteContract,
} from 'wagmi';
import { decodeEventLog, isAddress, parseUnits } from 'viem';
import {
  ArrowLeft,
  ArrowRight,
  Check,
  Copy,
  ExternalLink,
  LoaderCircle,
  QrCode,
  ShieldAlert,
  ShieldCheck,
  TriangleAlert,
} from 'lucide-react';
import { QRCodeSVG } from 'qrcode.react';
import Link from 'next/link';
import { payAbi, payAddress } from '../../../config/contracts';
import { aevumTestnet } from '../../../lib/aevum-chain';
import { truncateAddress } from '../../../lib/utils';
import type { CopResult } from '../../../components/cop-preflight-card';
export default function CreateInvoicePage() {
  const { address, chainId } = useAccount();
  const { switchChain } = useSwitchChain();
  const publicClient = usePublicClient();
  const [payee, setPayee] = useState('');
  const [name, setName] = useState('');
  const [amount, setAmount] = useState('');
  const [memo, setMemo] = useState('');
  const [delay, setDelay] = useState(0);
  const [createdId, setCreatedId] = useState('');
  const [copied, setCopied] = useState(false);
  const canCheck = !!payAddress && isAddress(payee) && !!name.trim();
  const copQuery = useReadContract({
    address: payAddress,
    abi: payAbi,
    functionName: 'copCheckAddress',
    args: [payee as `0x${string}`, name],
    query: { enabled: canCheck },
  });
  const cop = copQuery.data as CopResult | undefined;
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const tx = useWaitForTransactionReceipt({ hash });
  useEffect(() => {
    if (!tx.isSuccess || !hash || !publicClient || !payAddress) return;
    publicClient.getTransactionReceipt({ hash }).then((r) => {
      for (const log of r.logs) {
        try {
          const d = decodeEventLog({
            abi: payAbi,
            eventName: 'InvoiceCreated',
            data: log.data,
            topics: log.topics,
          });
          setCreatedId(String((d.args as { id?: string }).id));
          return;
        } catch {}
      }
    });
  }, [tx.isSuccess, hash, publicClient]);
  useEffect(() => {
    if (!address) setPayee('');
    else setPayee((p) => p || address);
  }, [address]);
  const amountValid = !!amount && Number(amount) > 0 && /^\d+(\.\d{0,6})?$/.test(amount);
  function submit() {
    if (!address || !payAddress || !isAddress(payee) || !amountValid || !name.trim()) return;
    writeContract({
      address: payAddress,
      abi: payAbi,
      functionName: 'createInvoiceWithName',
      args: [payee as `0x${string}`, parseUnits(amount, 6), memo, BigInt(delay), name.trim()],
      chainId: aevumTestnet.id,
    });
  }
  async function copyUrl() {
    await navigator.clipboard.writeText(`${window.location.origin}/pay/${createdId}`);
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  }
  if (!payAddress)
    return (
      <div className="product-page wrap">
        <div className="state-page">
          <h1>Contract addresses required</h1>
          <p>
            Set the CimonPay and CimonRegistry addresses in frontend/.env.local to create invoices
            on-chain.
          </p>
        </div>
      </div>
    );
  return (
    <div className="product-page wrap">
      <div className="page-back">
        <Link href="/invoices">
          <ArrowLeft size={14} />
          Invoices
        </Link>
        <span className="chain-label">
          <span className="live-dot" />
          Aevum Testnet
        </span>
      </div>
      <div className="page-title-row">
        <div>
          <span className="eyebrow">MERCHANT TOOLS / INVOICE BUILDER</span>
          <h1>Create a verified invoice.</h1>
          <p>
            Set the destination and expected business name. CIMON checks both before a payer
            approves settlement.
          </p>
        </div>
        <span className="page-number">
          01 <span>/</span> 03
        </span>
      </div>
      {!createdId ? (
        <div className="builder-layout">
          <section className="builder-card">
            <div className="form-section-title">
              <span className="section-index">A</span>
              <div>
                <h2>Recipient & invoice</h2>
                <p>Who should receive the payment?</p>
              </div>
            </div>
            <label className="field-label">
              PAYOUT ADDRESS <span>Required</span>
            </label>
            <div className="input-with-action">
              <input
                value={payee}
                onChange={(e) => setPayee(e.target.value)}
                placeholder="0x…"
                className="mono-input"
              />
              <button
                type="button"
                onClick={() => address && setPayee(address)}
                disabled={!address}
              >
                Use connected wallet
              </button>
            </div>
            {payee && !isAddress(payee) && (
              <span className="field-error">Enter a valid EVM address.</span>
            )}
            <label className="field-label">
              EXPECTED BUSINESS NAME <span>Required</span>
            </label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Name the payer should see"
            />
            <div className="field-grid">
              <div>
                <label className="field-label">
                  AMOUNT <span>tUSD8</span>
                </label>
                <div className="amount-input">
                  <input
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    inputMode="decimal"
                    placeholder="0.00"
                  />
                  <span>tUSD8</span>
                </div>
              </div>
              <div>
                <label className="field-label">ORDER REFERENCE</label>
                <input
                  value={memo}
                  onChange={(e) => setMemo(e.target.value.slice(0, 280))}
                  placeholder="INV-2026-001"
                  maxLength={280}
                />
              </div>
            </div>
            <label className="field-label">SETTLEMENT PROTECTION</label>
            <div className="delay-options">
              {[
                { value: 0, label: 'Instant', sub: 'Direct transfer' },
                { value: 900, label: '15 minutes', sub: 'Safety escrow' },
                { value: 86400, label: '24 hours', sub: 'Milestone escrow' },
              ].map((x) => (
                <button
                  type="button"
                  key={x.value}
                  onClick={() => setDelay(x.value)}
                  className={`delay-option ${delay === x.value ? 'active' : ''}`}
                >
                  <span>{x.label}</span>
                  <small>{x.sub}</small>
                </button>
              ))}
            </div>
            <button
              onClick={submit}
              disabled={
                !address ||
                chainId !== 44005 ||
                !isAddress(payee) ||
                !amountValid ||
                !name.trim() ||
                writeContract === undefined
              }
              className="button button-primary full-button builder-submit"
            >
              {!address
                ? 'Connect wallet to continue'
                : chainId !== 44005
                  ? 'Switch to Aevum to continue'
                  : isPending
                    ? 'Confirm in wallet'
                    : 'Create invoice on-chain'}
              <ArrowRight size={15} />
            </button>
            {address && chainId !== 44005 && (
              <button
                className="chain-inline"
                onClick={() => switchChain({ chainId: aevumTestnet.id })}
              >
                Switch network to Aevum Testnet
              </button>
            )}
            {error && <p className="form-error">{error.message.slice(0, 180)}</p>}
            {tx.isLoading && (
              <p className="tx-pending">
                <LoaderCircle size={15} className="spin" />
                Waiting for transaction confirmation…
              </p>
            )}
          </section>
          <aside className="builder-aside">
            <div className="preview-card">
              <div className="preview-top">
                <span className="eyebrow">LIVE PRE-FLIGHT</span>
                <span className="preview-live">
                  <span className="live-dot" />
                  ON-CHAIN CHECK
                </span>
              </div>
              <h2>Payee identity</h2>
              {copQuery.isFetching ? (
                <div className="preview-placeholder">
                  <LoaderCircle className="spin" size={18} />
                  Checking CimonRegistry…
                </div>
              ) : cop ? (
                <div className={`mini-verdict verdict-${cop.risk}`}>
                  <div className="mini-verdict-icon">
                    {cop.risk === 0 ? (
                      <ShieldCheck size={19} />
                    ) : cop.risk === 1 ? (
                      <TriangleAlert size={19} />
                    ) : (
                      <ShieldAlert size={19} />
                    )}
                  </div>
                  <div>
                    <strong>{['VERIFIED', 'CAUTION', 'HIGH RISK'][cop.risk]}</strong>
                    <span>{cop.legalName || 'No registered identity'}</span>
                  </div>
                </div>
              ) : (
                <div className="preview-placeholder">
                  Enter an address and expected name to run the on-chain check.
                </div>
              )}
              <div className="preview-divider" />
              <div className="preview-line">
                <span>Destination</span>
                <code>{truncateAddress(payee, 8)}</code>
              </div>
              <div className="preview-line">
                <span>Expected name</span>
                <strong>{name || '—'}</strong>
              </div>
              <div className="preview-line">
                <span>Amount</span>
                <strong>{amount || '0.00'} tUSD8</strong>
              </div>
              <div className="preview-line">
                <span>Escrow window</span>
                <strong>{delay === 0 ? 'Instant' : `${delay / 60} min`}</strong>
              </div>
              <div className="preview-note">
                The payer sees this verification again before payment. Invoice creation does not
                move funds.
              </div>
            </div>
            <div className="aside-footnote">
              <ShieldCheck size={14} />
              <span>Only the connected wallet can cancel its pending invoices.</span>
            </div>
          </aside>
        </div>
      ) : (
        <section className="created-panel">
          <div className="created-icon">
            <Check size={23} />
          </div>
          <span className="eyebrow">INVOICE RECORDED ON AEVUM</span>
          <h2>Your payment link is ready.</h2>
          <p>
            Share this link with your customer. They’ll see the live CoP verdict before approving
            tUSD8.
          </p>
          <div className="share-link">
            <code>
              {typeof window !== 'undefined'
                ? `${window.location.origin}/pay/${createdId}`
                : `/pay/${createdId}`}
            </code>
            <button onClick={copyUrl}>
              <Copy size={14} />
              {copied ? 'Copied' : 'Copy'}
            </button>
          </div>
          <div className="created-actions">
            <Link className="button button-primary" href={`/pay/${createdId}`}>
              Open checkout <ArrowRight size={15} />
            </Link>
            <a
              className="button button-outline"
              href={`https://explorer-test.qday.info/tx/${hash}`}
              target="_blank"
              rel="noreferrer"
            >
              View transaction <ExternalLink size={14} />
            </a>
          </div>
          <div className="qr-block">
            <QRCodeSVG
              value={
                typeof window !== 'undefined'
                  ? `${window.location.origin}/pay/${createdId}`
                  : createdId
              }
              size={108}
              bgColor="#f4f6fa"
              fgColor="#11131b"
              level="M"
            />
            <span>
              <QrCode size={14} /> QR payment link
            </span>
          </div>
        </section>
      )}
    </div>
  );
}
