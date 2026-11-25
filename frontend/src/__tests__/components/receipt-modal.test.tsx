import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { ReceiptModal } from '@/components/receipt-modal';

describe('ReceiptModal', () => {
  const mockData = {
    invoiceId: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
    receipt: {
      receiptHash: '0x9999999999999999999999999999999999999999999999999999999999999999',
      settledAt: 1716000000n,
    },
    transactionHash: '0xaaaabbbbccccdddd1111222233334444555566667777888899990000aaaabbbb',
  };

  it('returns null when open is false', () => {
    const { container } = render(
      <ReceiptModal open={false} onClose={vi.fn()} onDownload={vi.fn()} />
    );
    expect(container.firstChild).toBeNull();
  });

  it('renders modal content when open is true', () => {
    render(
      <ReceiptModal
        open={true}
        onClose={vi.fn()}
        onDownload={vi.fn()}
        data={mockData}
        transactionHash={mockData.transactionHash}
      />
    );

    expect(screen.getByText('Payment confirmed.')).toBeInTheDocument();
    expect(screen.getByText('ON-CHAIN SETTLEMENT PROOF')).toBeInTheDocument();
    expect(screen.getByText(mockData.invoiceId)).toBeInTheDocument();
    expect(screen.getByText(mockData.receipt.receiptHash)).toBeInTheDocument();
    expect(screen.getByText('QDay Aevum · 44005')).toBeInTheDocument();
  });

  it('calls onClose when close button is clicked', () => {
    const handleClose = vi.fn();
    render(<ReceiptModal open={true} onClose={handleClose} onDownload={vi.fn()} data={mockData} />);

    const closeBtn = screen.getByLabelText('Close receipt');
    fireEvent.click(closeBtn);
    expect(handleClose).toHaveBeenCalledTimes(1);
  });

  it('calls onDownload when Download JSON button is clicked', () => {
    const handleDownload = vi.fn();
    render(
      <ReceiptModal open={true} onClose={vi.fn()} onDownload={handleDownload} data={mockData} />
    );

    const downloadBtn = screen.getByText('Download JSON');
    fireEvent.click(downloadBtn);
    expect(handleDownload).toHaveBeenCalledTimes(1);
  });

  it('renders transaction explorer link when transactionHash is provided', () => {
    render(
      <ReceiptModal
        open={true}
        onClose={vi.fn()}
        onDownload={vi.fn()}
        data={mockData}
        transactionHash={mockData.transactionHash}
      />
    );

    const txLink = screen.getByText(/View transaction/i).closest('a');
    expect(txLink).toHaveAttribute(
      'href',
      `https://explorer-test.qday.info/tx/${mockData.transactionHash}`
    );
  });
});
