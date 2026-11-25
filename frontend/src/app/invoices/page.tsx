'use client';
import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import {
  useAccount,
  usePublicClient,
  useSwitchChain,
  useWaitForTransactionReceipt,
  useWriteContract,
} from 'wagmi';
import {
  ArrowRight,
  ArrowUpRight,
  Clock3,
  FilePlus2,
  LoaderCircle,
  RefreshCw,
  ShieldCheck,
} from 'lucide-react';
import { payAbi, payAddress } from '../../config/contracts';
import { aevumTestnet } from '../../lib/aevum-chain';
import { formatToken, truncateAddress } from '../../lib/utils';
type Inv = {
  id: `0x${string}`;
  merchant: `0x${string}`;
  expectedPayee: `0x${string}`;
  amount: bigint;
  memo: string;
  safetyDelay: bigint;
  paidAt: bigint;
  status: number;
  actualPayer: `0x${string}`;
  expectedName?: string;
  releaseAt?: bigint;
};
export default function InvoicesPage() {
  const { address, chainId } = useAccount();
  const client = usePublicClient();
  const { switchChain } = useSwitchChain();
  const [tab, setTab] = useState<'incoming' | 'outgoing'>('incoming');
  const [rows, setRows] = useState<Inv[]>([]);
  const [loading, setLoading] = useState(false);
  const [now, setNow] = useState(0);
  const { writeContract, data: hash, isPending } = useWriteContract();
  const tx = useWaitForTransactionReceipt({ hash });
  const refresh = useCallback(async () => {
    if (!address || !client || !payAddress) return;
    setLoading(true);
    try {
      const fn = tab === 'incoming' ? 'getMerchantInvoiceIds' : 'getPayerInvoiceIds';
      const ids = (await client.readContract({
        address: payAddress,
        abi: payAbi,
        functionName: fn,
        args: [address, 0n, 50n],
      })) as `0x${string}`[];
      const list = await Promise.all(
        ids.map(async (id) => {
          const [invoice, expectedName, releaseAt] = await Promise.all([
            client.readContract({
              address: payAddress!,
              abi: payAbi,
              functionName: 'getInvoice',
              args: [id],
            }),
            client
              .readContract({
                address: payAddress!,
                abi: payAbi,
                functionName: 'getExpectedName',
                args: [id],
              })
              .catch(() => ''),
            client
              .readContract({
                address: payAddress!,
                abi: payAbi,
                functionName: 'releaseTime',
                args: [id],
              })
              .catch(() => 0n),
          ]);
          return { ...invoice, id, expectedName, releaseAt } as Inv;
        })
      );
      setRows(list.reverse());
    } catch {
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [address, client, tab]);
  useEffect(() => {
    refresh();
  }, [refresh, tx.isSuccess]);
  useEffect(() => {
    setNow(Date.now());
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);
  const act = (
    functionName: 'claimEscrow' | 'disputeOrCancel' | 'cancelInvoice',
    id: `0x${string}`
  ) =>
    writeContract({
      address: payAddress!,
      abi: payAbi,
      functionName,
      args: [id],
      chainId: aevumTestnet.id,
    });
  if (!payAddress)
    return (
      <div className="product-page wrap">
        <div className="state-page">
          <h1>Contract addresses required</h1>
          <p>Configure the CimonPay address in frontend/.env.local to load on-chain invoices.</p>
        </div>
      </div>
    );
  const status = ['PENDING', 'ESCROWED', 'SETTLED', 'CANCELLED', 'REFUNDED'];
  return (
    <div className="product-page wrap">
      <div className="page-back">
        <Link href="/">
          <ArrowRight size={14} className="arrow-back" />
          Dashboard
        </Link>
        <span className="chain-label">
          <span className="live-dot" />
          Aevum Testnet
        </span>
      </div>
      <div className="page-title-row">
        <div>
          <span className="eyebrow">CIMON PAY / ACTIVITY</span>
          <h1>Invoice activity.</h1>
          <p>Track incoming invoices, outgoing payments and active escrow windows.</p>
        </div>
        <Link className="button button-primary" href="/invoices/create">
          <FilePlus2 size={15} />
          Create invoice
        </Link>
      </div>
      <div className="dashboard-toolbar">
        <div className="dashboard-tabs">
          <button onClick={() => setTab('incoming')} className={tab === 'incoming' ? 'active' : ''}>
            Incoming <span>Merchant</span>
          </button>
          <button onClick={() => setTab('outgoing')} className={tab === 'outgoing' ? 'active' : ''}>
            Outgoing <span>Payer</span>
          </button>
        </div>
        <button className="refresh-button" onClick={refresh} disabled={loading}>
          <RefreshCw size={14} className={loading ? 'spin' : ''} />
          Refresh
        </button>
      </div>
      {!address ? (
        <div className="empty-state">
          <div className="empty-icon">
            <ShieldCheck size={22} />
          </div>
          <h2>Connect your wallet to view invoices.</h2>
          <p>
            Your invoice history is queried directly from CimonPay using your connected address.
          </p>
        </div>
      ) : chainId !== 44005 ? (
        <div className="empty-state">
          <h2>Switch to QDay Aevum Testnet.</h2>
          <p>Invoice activity is indexed on chain 44005.</p>
          <button
            className="button button-primary"
            onClick={() => switchChain({ chainId: aevumTestnet.id })}
          >
            Switch network
          </button>
        </div>
      ) : loading ? (
        <div className="empty-state">
          <LoaderCircle className="spin" />
          <p>Loading on-chain invoices…</p>
        </div>
      ) : rows.length === 0 ? (
        <div className="empty-state">
          <div className="empty-icon">
            <ShieldCheck size={22} />
          </div>
          <h2>No {tab} invoices yet.</h2>
          <p>
            {tab === 'incoming'
              ? 'Create an invoice to request a tUSD8 payment.'
              : 'Invoices you pay will appear here.'}
          </p>
          {tab === 'incoming' && (
            <Link className="button button-primary" href="/invoices/create">
              Create an invoice <ArrowRight size={14} />
            </Link>
          )}
        </div>
      ) : (
        <div className="invoice-list">
          {rows.map((inv) => {
            const remaining =
              inv.releaseAt && inv.releaseAt > BigInt(Math.floor(now / 1000))
                ? Number(inv.releaseAt) - Math.floor(now / 1000)
                : 0;
            const time = remaining
              ? `${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, '0')}`
              : '';
            return (
              <article key={inv.id} className="invoice-row">
                <div className="invoice-row-main">
                  <div className="invoice-file">
                    <FilePlus2 size={17} />
                  </div>
                  <div className="invoice-name">
                    <strong>{inv.memo || 'Payment invoice'}</strong>
                    <span>
                      {tab === 'incoming' ? 'Payer' : 'Payee'} ·{' '}
                      {truncateAddress(tab === 'incoming' ? inv.actualPayer : inv.expectedPayee, 7)}{' '}
                      <i>·</i> {inv.id.slice(0, 10)}…
                    </span>
                  </div>
                </div>
                <div className="invoice-row-amount">
                  <strong>
                    {formatToken(inv.amount)} <small>tUSD8</small>
                  </strong>
                  <span>{inv.expectedName || 'Unspecified payee name'}</span>
                </div>
                <div className="invoice-row-status">
                  <span
                    className={`status-chip status-${['pending', 'escrowed', 'complete', 'cancelled', 'refunded'][inv.status] || 'pending'}`}
                  >
                    {status[inv.status]}
                  </span>
                  {remaining > 0 && (
                    <span className="timer">
                      <Clock3 size={12} />
                      {time} remaining
                    </span>
                  )}
                </div>
                <div className="invoice-row-actions">
                  <Link href={`/pay/${inv.id}`} className="icon-button" title="Open invoice">
                    <ArrowUpRight size={16} />
                  </Link>
                  {inv.status === 0 && tab === 'incoming' && (
                    <button
                      onClick={() => act('cancelInvoice', inv.id)}
                      disabled={isPending}
                      className="row-text-button"
                    >
                      Cancel
                    </button>
                  )}
                  {inv.status === 1 && tab === 'outgoing' && remaining > 0 && (
                    <button
                      onClick={() => act('disputeOrCancel', inv.id)}
                      disabled={isPending}
                      className="row-text-button danger-text"
                    >
                      Dispute
                    </button>
                  )}
                  {inv.status === 1 && remaining === 0 && (
                    <button
                      onClick={() => act('claimEscrow', inv.id)}
                      disabled={isPending}
                      className="row-text-button"
                    >
                      Claim escrow
                    </button>
                  )}
                </div>
              </article>
            );
          })}
        </div>
      )}
      {hash && (
        <div className="dashboard-tx">
          Transaction sent ·{' '}
          <a href={`https://explorer-test.qday.info/tx/${hash}`} target="_blank" rel="noreferrer">
            View in explorer <ArrowUpRight size={12} />
          </a>
          {tx.isSuccess && <span>Confirmed</span>}
        </div>
      )}
    </div>
  );
}
