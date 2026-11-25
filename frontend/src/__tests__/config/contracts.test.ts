import { describe, it, expect } from 'vitest';
import { tokenAddress, payAbi, registryAbi, erc20Abi } from '@/config/contracts';

describe('Contracts Configuration', () => {
  it('defines the official tUSD8 token address on Aevum Testnet', () => {
    expect(tokenAddress).toBe('0x456569838f1d43009A91ebA4263147Afd7233483');
  });

  it('exports valid erc20Abi with standard methods', () => {
    const fnNames = erc20Abi
      .filter((item) => item.type === 'function')
      .map((item) => (item as { name: string }).name);
    expect(fnNames).toContain('allowance');
    expect(fnNames).toContain('approve');
    expect(fnNames).toContain('balanceOf');
    expect(fnNames).toContain('decimals');
  });

  it('exports payAbi with core CimonPay functions and events', () => {
    const fnNames = payAbi
      .filter((item) => item.type === 'function')
      .map((item) => (item as { name: string }).name);
    expect(fnNames).toContain('getInvoice');
    expect(fnNames).toContain('getExpectedName');
    expect(fnNames).toContain('copCheck');
    expect(fnNames).toContain('copCheckAddress');
    expect(fnNames).toContain('createInvoiceWithName');
    expect(fnNames).toContain('payInvoiceWithRiskCap');
    expect(fnNames).toContain('getMerchantInvoiceIds');
    expect(fnNames).toContain('getPayerInvoiceIds');
    expect(fnNames).toContain('releaseTime');
    expect(fnNames).toContain('claimEscrow');
    expect(fnNames).toContain('disputeOrCancel');
    expect(fnNames).toContain('cancelInvoice');
    expect(fnNames).toContain('getReceipt');

    const eventNames = payAbi
      .filter((item) => item.type === 'event')
      .map((item) => (item as { name: string }).name);
    expect(eventNames).toContain('InvoiceCreated');
  });

  it('exports registryAbi with CimonRegistry functions', () => {
    const fnNames = registryAbi
      .filter((item) => item.type === 'function')
      .map((item) => (item as { name: string }).name);
    expect(fnNames).toContain('getProfile');
    expect(fnNames).toContain('registerPayee');
    expect(fnNames).toContain('updateProfile');
  });
});
