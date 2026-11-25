'use client';
import Link from 'next/link';
import { useAccount, useConnect, useDisconnect, useSwitchChain } from 'wagmi';
import { aevumTestnet } from '../lib/aevum-chain';
import { truncateAddress } from '../lib/utils';
import { ArrowUpRight, ChevronDown, ShieldCheck } from 'lucide-react';
export function Navbar() {
  const { address, isConnected, chainId } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: switching } = useSwitchChain();
  const wrongChain = isConnected && chainId !== aevumTestnet.id;
  return <header className="topbar"><div className="topbar-inner">
    <Link href="/" className="brand"><span className="brand-mark"><ShieldCheck size={19}/></span><span>CIMON<span className="brand-period">.</span></span></Link>
    <nav className="main-nav"><Link href="/invoices">Invoices</Link><Link href="/invoices/create">Create invoice</Link><Link href="/register">Registry</Link></nav>
    <div className="top-actions"><a className="network-pill" href="https://explorer-test.qday.info" target="_blank" rel="noreferrer"><span className="live-dot"/>Aevum <span className="network-id">44005</span><ArrowUpRight size={12}/></a>
      {isConnected ? <div className="wallet-actions">{wrongChain && <button className="chain-warning" onClick={() => switchChain({ chainId: aevumTestnet.id })}>{switching ? 'Switching…' : 'Switch network'}</button>}<button className="wallet-button" onClick={() => disconnect()}><span className="wallet-indicator"/>{truncateAddress(address)}</button></div> : <button className="wallet-button connect" disabled={isPending} onClick={() => { const connector = connectors[0]; if (connector) connect({ connector }); }}>{isPending ? 'Connecting…' : 'Connect wallet'}<ChevronDown size={14}/></button>}
    </div>
  </div></header>;
}
