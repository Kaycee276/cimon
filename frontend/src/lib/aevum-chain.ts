import { defineChain } from 'viem';
export const aevumTestnet = defineChain({
  id: 44005,
  name: 'QDay Aevum Testnet',
  nativeCurrency: { decimals: 18, name: 'tQDAY', symbol: 'tQDAY' },
  rpcUrls: { default: { http: ['https://rpc-test.qday.info'] } },
  blockExplorers: { default: { name: 'Aevum Explorer', url: 'https://explorer-test.qday.info' } },
  testnet: true,
});
