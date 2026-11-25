import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Footer } from '@/components/footer';

describe('Footer Component', () => {
  it('renders the large CIMON brand wordmark display', () => {
    render(<Footer />);
    const wordmark = screen.getByText('CIMON');
    expect(wordmark).toBeInTheDocument();
    expect(wordmark.className).toContain('font-display');
  });

  it('renders navigation links to Create Invoice, Invoices, and Register Payee', () => {
    render(<Footer />);
    expect(screen.getByRole('link', { name: 'Create Invoice' })).toHaveAttribute(
      'href',
      '/invoices/create'
    );
    expect(screen.getByRole('link', { name: 'Invoices' })).toHaveAttribute('href', '/invoices');
    expect(screen.getByRole('link', { name: 'Register Payee' })).toHaveAttribute(
      'href',
      '/register'
    );
  });

  it('renders external links with target _blank', () => {
    render(<Footer />);
    const qdayLink = screen.getByRole('link', { name: /QDay/i });
    expect(qdayLink).toHaveAttribute('href', 'https://qday.io');
    expect(qdayLink).toHaveAttribute('target', '_blank');

    const explorerLink = screen.getByRole('link', { name: /Explorer/i });
    expect(explorerLink).toHaveAttribute('href', 'https://explorer-test.qday.info');
    expect(explorerLink).toHaveAttribute('target', '_blank');

    const githubLink = screen.getByRole('link', { name: /GitHub/i });
    expect(githubLink).toHaveAttribute('href', 'https://github.com/Kaycee276/cimon');
    expect(githubLink).toHaveAttribute('target', '_blank');

    const challengeLink = screen.getByRole('link', { name: /Aevum Challenge/i });
    expect(challengeLink).toHaveAttribute('href', 'https://qday.io/builder-challenge');
    expect(challengeLink).toHaveAttribute('target', '_blank');
  });

  it('displays chain ID 44005 and settlement token tUSD8', () => {
    render(<Footer />);
    expect(screen.getByText('QDay Aevum Testnet (44005)')).toBeInTheDocument();
    expect(screen.getByText('Settled in tUSD8')).toBeInTheDocument();
  });
});
