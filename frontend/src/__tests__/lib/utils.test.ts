import { describe, it, expect } from 'vitest';
import {
  cn,
  truncateAddress,
  formatToken,
  validAddress,
  explorerTx,
  explorerAddress,
} from '@/lib/utils';

describe('Frontend Utils', () => {
  describe('cn', () => {
    it('merges class names correctly', () => {
      expect(cn('base-class', 'extra-class')).toBe('base-class extra-class');
    });

    it('handles conditional classes and falsy values', () => {
      expect(cn('btn', false && 'hidden', null, undefined, 'btn-primary')).toBe('btn btn-primary');
    });

    it('resolves conflicting tailwind classes cleanly', () => {
      expect(cn('px-2 py-1', 'px-4')).toBe('py-1 px-4');
    });
  });

  describe('truncateAddress', () => {
    it('truncates standard 42-char EVM address with custom head and 4-char tail', () => {
      const addr = '0x456569838f1d43009A91ebA4263147Afd7233483';
      expect(truncateAddress(addr)).toBe('0x4565…3483');
      expect(truncateAddress(addr, 8)).toBe('0x456569…3483');
    });

    it('returns fallback dash if undefined or empty', () => {
      expect(truncateAddress(undefined)).toBe('—');
      expect(truncateAddress('')).toBe('—');
    });
  });

  describe('formatToken', () => {
    it('formats 6-decimal stablecoin values to 2 decimal places with separators', () => {
      // 100 tUSD8 (100 * 10^6)
      expect(formatToken(100_000_000n)).toBe('100.00');
      // 2.50 tUSD8
      expect(formatToken(2_500_000n)).toBe('2.50');
      // 1,234,567.89 tUSD8
      expect(formatToken(1_234_567_890_000n)).toBe('1,234,567.89');
      // 0 tUSD8
      expect(formatToken(0n)).toBe('0.00');
    });

    it('returns fallback dash for undefined values', () => {
      expect(formatToken(undefined)).toBe('—');
    });
  });

  describe('validAddress', () => {
    it('validates proper EVM address strings', () => {
      expect(validAddress('0x456569838f1d43009A91ebA4263147Afd7233483')).toBe(true);
      expect(validAddress('0x0000000000000000000000000000000000000000')).toBe(true);
    });

    it('rejects invalid address strings', () => {
      expect(validAddress('not-an-address')).toBe(false);
      expect(validAddress('0x123')).toBe(false);
      expect(validAddress('')).toBe(false);
    });
  });

  describe('explorer links', () => {
    it('generates the correct transaction URL', () => {
      const hash = '0xabcdef1234567890';
      expect(explorerTx(hash)).toBe('https://explorer-test.qday.info/tx/0xabcdef1234567890');
    });

    it('generates the correct address URL', () => {
      const addr = '0x456569838f1d43009A91ebA4263147Afd7233483';
      expect(explorerAddress(addr)).toBe(
        'https://explorer-test.qday.info/address/0x456569838f1d43009A91ebA4263147Afd7233483'
      );
    });
  });
});
