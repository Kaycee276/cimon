'use client';
import { createConfig, http } from 'wagmi';
import { injected } from '@wagmi/core';
import { aevumTestnet } from '../lib/aevum-chain';
export const wagmiConfig = createConfig({
  chains: [aevumTestnet],
  connectors: [injected()],
  transports: { [aevumTestnet.id]: http() },
  ssr: true,
});
