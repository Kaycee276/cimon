import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { CopPreflightCard, type CopResult } from '@/components/cop-preflight-card';

describe('CopPreflightCard', () => {
  const verifiedResult: CopResult = {
    risk: 0,
    registered: true,
    nameChecked: true,
    exactMatch: true,
    tier: 2, // Verified business
    isFlagged: false,
    legalName: 'Acme Global Corp',
    successfulTxCount: 42n,
    domain: 'acme.com',
  };

  const cautionResult: CopResult = {
    risk: 1,
    registered: true,
    nameChecked: true,
    exactMatch: false,
    tier: 1, // Basic user
    isFlagged: false,
    legalName: 'Acme Individual',
    successfulTxCount: 3n,
    domain: 'acme-indiv.org',
  };

  const highRiskResult: CopResult = {
    risk: 2,
    registered: false,
    nameChecked: true,
    exactMatch: false,
    tier: 0, // Unregistered
    isFlagged: true,
    legalName: '',
    successfulTxCount: 0n,
  };

  it('renders VERIFIED badge and verified business tier for low-risk payee', () => {
    render(
      <CopPreflightCard
        result={verifiedResult}
        expectedName="Acme Global Corp"
        payee="0x1111111111111111111111111111111111111111"
        domain="acme.com"
      />
    );

    expect(screen.getByText('VERIFIED')).toBeInTheDocument();
    expect(screen.getAllByText('Verified business').length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText('Exact match')).toBeInTheDocument();
    expect(screen.getByText('Acme Global Corp')).toBeInTheDocument();
    expect(screen.getByText('42')).toBeInTheDocument();
    expect(screen.getByText('No active flags')).toBeInTheDocument();
  });

  it('renders CAUTION badge when risk is 1 and name does not match exactly', () => {
    render(
      <CopPreflightCard
        result={cautionResult}
        expectedName="Acme Corp"
        payee="0x2222222222222222222222222222222222222222"
        domain="acme-indiv.org"
      />
    );

    expect(screen.getByText('CAUTION')).toBeInTheDocument();
    expect(screen.getAllByText('Basic user').length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText('Does not match')).toBeInTheDocument();
  });

  it('renders HIGH RISK badge and flagged warning for flagged/unregistered payee', () => {
    render(
      <CopPreflightCard
        result={highRiskResult}
        expectedName="Target Corp"
        payee="0x3333333333333333333333333333333333333333"
      />
    );

    expect(screen.getByText('HIGH RISK')).toBeInTheDocument();
    expect(screen.getAllByText('Unregistered').length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText('Address flagged')).toBeInTheDocument();
  });

  it('triggers onCopy handler when copy icon is clicked', () => {
    const handleCopy = vi.fn();
    render(
      <CopPreflightCard
        result={verifiedResult}
        expectedName="Acme Global Corp"
        payee="0x1111111111111111111111111111111111111111"
        onCopy={handleCopy}
      />
    );

    const copyBtn = screen.getByLabelText('Copy payee address');
    fireEvent.click(copyBtn);
    expect(handleCopy).toHaveBeenCalledTimes(1);
  });
});
