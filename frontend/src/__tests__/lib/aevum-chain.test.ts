import { describe, it, expect } from 'vitest';
import { aevumTestnet } from '@/lib/aevum-chain';

describe('Aevum Testnet Chain Definition', () => {
  it('has the correct chain ID and name', () => {
    expect(aevumTestnet.id).toBe(44005);
    expect(aevumTestnet.name).toBe('QDay Aevum Testnet');
  });

  it('configures native currency as tQDAY with 18 decimals', () => {
    expect(aevumTestnet.nativeCurrency).toEqual({
      decimals: 18,
      name: 'tQDAY',
      symbol: 'tQDAY',
    });
  });

  it('configures public RPC and explorer endpoints', () => {
    expect(aevumTestnet.rpcUrls.default.http[0]).toBe('https://rpc-test.qday.info');
    expect(aevumTestnet.blockExplorers?.default.url).toBe('https://explorer-test.qday.info');
    expect(aevumTestnet.blockExplorers?.default.name).toBe('Aevum Explorer');
  });

  it('is marked as a testnet', () => {
    expect(aevumTestnet.testnet).toBe(true);
  });
});
