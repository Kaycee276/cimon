'use client';
import { Check, Download, ExternalLink, X } from 'lucide-react';
import { explorerTx } from '../lib/utils';

export interface ReceiptRecord {
  receiptHash?: string;
  settledAt?: bigint | number | string;
}

export interface ReceiptData {
  invoiceId?: string;
  receipt?: ReceiptRecord;
  transactionHash?: string;
}

export function ReceiptModal({
  open,
  onClose,
  data,
  transactionHash,
  onDownload,
}: {
  open: boolean;
  onClose: () => void;
  data?: ReceiptData | null;
  transactionHash?: string;
  onDownload: () => void;
}) {
  if (!open) return null;
  const receipt = data?.receipt?.receiptHash ? data.receipt : data?.receipt;
  return (
    <div
      className="modal-backdrop"
      role="presentation"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <section
        className="receipt-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="receipt-title"
      >
        <button className="modal-close" aria-label="Close receipt" onClick={onClose}>
          <X size={17} />
        </button>
        <div className="receipt-check">
          <Check size={19} />
        </div>
        <span className="eyebrow">ON-CHAIN SETTLEMENT PROOF</span>
        <h2 id="receipt-title">Payment confirmed.</h2>
        <p>CIMON receipt data read from the Aevum contract.</p>
        <div className="receipt-fields">
          <div>
            <span>INVOICE ID</span>
            <code>{data?.invoiceId || '—'}</code>
          </div>
          <div>
            <span>RECEIPT HASH</span>
            <code>{receipt?.receiptHash || 'Not settled'}</code>
          </div>
          <div>
            <span>SETTLED AT</span>
            <code>
              {receipt?.settledAt
                ? new Date(Number(receipt.settledAt) * 1000).toLocaleString()
                : '—'}
            </code>
          </div>
          <div>
            <span>NETWORK</span>
            <code>QDay Aevum · 44005</code>
          </div>
        </div>
        <div className="modal-actions">
          <button className="button button-primary" onClick={onDownload}>
            <Download size={14} />
            Download JSON
          </button>
          {transactionHash && (
            <a
              className="button button-outline"
              href={explorerTx(transactionHash)}
              target="_blank"
              rel="noreferrer"
            >
              View transaction <ExternalLink size={13} />
            </a>
          )}
        </div>
      </section>
    </div>
  );
}
