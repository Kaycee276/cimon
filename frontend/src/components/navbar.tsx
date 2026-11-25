'use client';
import Link from 'next/link';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { aevumTestnet } from '../lib/aevum-chain';
import { ArrowUpRight, ChevronDown } from 'lucide-react';
export function Navbar() {
  return <header className="topbar"><div className="topbar-inner">
    <Link href="/" className="brand"><span>CIMON<span className="brand-period">.</span></span></Link>
    <nav className="main-nav"><Link href="/invoices">Invoices</Link><Link href="/invoices/create">Create invoice</Link><Link href="/register">Registry</Link></nav>
    <div className="top-actions"><a className="network-pill" href="https://explorer-test.qday.info" target="_blank" rel="noreferrer"><span className="live-dot"/>Aevum <span className="network-id">44005</span><ArrowUpRight size={12}/></a>
      <ConnectButton.Custom>{({ account, chain, openAccountModal, openChainModal, openConnectModal, authenticationStatus, mounted }) => {
        const ready = mounted && authenticationStatus !== 'loading';
        const connected = ready && account && chain;
        return <div aria-hidden={!ready} className="rainbow-connect" style={{ opacity: ready ? 1 : 0, pointerEvents: ready ? 'auto' : 'none' }}>
          {!connected ? <button className="wallet-button connect" onClick={openConnectModal}>Connect wallet<ChevronDown size={14}/></button> : chain.unsupported || chain.id !== aevumTestnet.id ? <button className="chain-warning" onClick={openChainModal}>Switch network</button> : <button className="wallet-button" onClick={openAccountModal}><span className="wallet-indicator"/>{account.displayName}</button>}
        </div>;
      }}</ConnectButton.Custom>
    </div>
  </div></header>;
}
