'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState, useEffect } from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { aevumTestnet } from '../lib/aevum-chain';
import {
  ArrowUpRight,
  ChevronDown,
  Menu,
  X,
  FileText,
  PlusCircle,
  ShieldCheck,
} from 'lucide-react';

export function Navbar() {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  // Close mobile drawer on route change
  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  // Prevent background scroll when mobile menu is active
  useEffect(() => {
    if (mobileOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
    };
  }, [mobileOpen]);

  const navLinks = [
    { href: '/invoices', label: 'Invoices', icon: FileText },
    { href: '/invoices/create', label: 'Create invoice', icon: PlusCircle },
    { href: '/register', label: 'Registry', icon: ShieldCheck },
  ];

  return (
    <header
      className={`topbar ${mobileOpen ? 'drawer-open' : ''}`}
      style={mobileOpen ? { backgroundColor: '#090a0f' } : undefined}
    >
      <div className="topbar-inner">
        {/* Brand */}
        <Link href="/" className="brand" onClick={() => setMobileOpen(false)}>
          <span>CIMON</span>
        </Link>

        {/* Desktop Navigation Links */}
        <nav className="main-nav">
          {navLinks.map((link) => {
            const isActive = pathname === link.href;
            return (
              <Link
                key={link.href}
                href={link.href}
                className={isActive ? 'text-white font-medium' : ''}
              >
                {link.label}
              </Link>
            );
          })}
        </nav>

        {/* Right Actions Container */}
        <div className="top-actions">
          {/* Network Pill - Desktop/Tablet */}
          <a
            className="network-pill hidden sm:flex"
            href="https://explorer-test.qday.info"
            target="_blank"
            rel="noreferrer"
            title="QDay Aevum Testnet Chain ID 44005"
          >
            <span className="live-dot" />
            <span>Aevum</span>
            <span className="network-id">44005</span>
            <ArrowUpRight size={12} />
          </a>

          {/* RainbowKit Wallet Button */}
          <ConnectButton.Custom>
            {({
              account,
              chain,
              openAccountModal,
              openChainModal,
              openConnectModal,
              authenticationStatus,
              mounted,
            }) => {
              const ready = mounted && authenticationStatus !== 'loading';
              const connected = ready && account && chain;
              return (
                <div
                  aria-hidden={!ready}
                  className="rainbow-connect"
                  style={{
                    opacity: ready ? 1 : 0,
                    pointerEvents: ready ? 'auto' : 'none',
                  }}
                >
                  {!connected ? (
                    <button
                      className="wallet-button connect text-xs sm:text-xs px-2.5 sm:px-3 h-[34px]"
                      onClick={openConnectModal}
                    >
                      <span>Connect</span>
                      <span className="hidden xs:inline">wallet</span>
                      <ChevronDown size={13} />
                    </button>
                  ) : chain.unsupported || chain.id !== aevumTestnet.id ? (
                    <button
                      className="chain-warning text-xs px-2.5 h-[34px]"
                      onClick={openChainModal}
                    >
                      Switch network
                    </button>
                  ) : (
                    <button
                      className="wallet-button text-xs px-2.5 sm:px-3 h-[34px]"
                      onClick={openAccountModal}
                    >
                      <span className="wallet-indicator" />
                      <span className="max-w-[85px] xs:max-w-[120px] sm:max-w-none truncate">
                        {account.displayName}
                      </span>
                    </button>
                  )}
                </div>
              );
            }}
          </ConnectButton.Custom>

          {/* Mobile Hamburger Toggle Button */}
          <button
            type="button"
            className="md:hidden flex items-center justify-center w-[34px] h-[34px] rounded-md border border-white/10 bg-[#171a24] text-[#cbd1dc] hover:text-white transition-colors"
            onClick={() => setMobileOpen(!mobileOpen)}
            aria-label={mobileOpen ? 'Close menu' : 'Open menu'}
            aria-expanded={mobileOpen}
          >
            {mobileOpen ? <X size={18} /> : <Menu size={18} />}
          </button>
        </div>
      </div>

      {/* Mobile Navigation Dropdown Drawer with 100% Solid Opaque Background */}
      {mobileOpen && (
        <div
          className="mobile-drawer md:hidden fixed top-[72px] inset-x-0 bottom-0 z-[100] flex flex-col justify-between p-6 overflow-y-auto"
          style={{ backgroundColor: '#090a0f', opacity: 1 }}
        >
          <div className="flex flex-col gap-2">
            <span className="text-[10px] font-mono tracking-widest text-[#727a8a] uppercase mb-1 px-3">
              Navigation
            </span>
            {navLinks.map((link) => {
              const Icon = link.icon;
              const isActive = pathname === link.href;
              return (
                <Link
                  key={link.href}
                  href={link.href}
                  onClick={() => setMobileOpen(false)}
                  className={`flex items-center gap-3.5 px-3.5 py-3 rounded-lg text-sm font-medium transition-all ${
                    isActive
                      ? 'bg-blue-600/20 border border-blue-500/40 text-white'
                      : 'text-[#a2aab8] hover:text-white hover:bg-white/[0.05]'
                  }`}
                >
                  <Icon size={18} className={isActive ? 'text-blue-400' : 'text-[#727a8a]'} />
                  <span>{link.label}</span>
                </Link>
              );
            })}

            <div className="my-3 border-t border-white/[0.08]" />

            <span className="text-[10px] font-mono tracking-widest text-[#727a8a] uppercase mb-1 px-3">
              Ecosystem & Network
            </span>
            <a
              href="https://explorer-test.qday.info"
              target="_blank"
              rel="noreferrer"
              className="flex items-center justify-between px-3.5 py-2.5 rounded-lg text-xs text-[#a2aab8] hover:text-white hover:bg-white/[0.05] transition-colors"
            >
              <div className="flex items-center gap-2.5">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
                <span>QDay Aevum Testnet</span>
                <span className="font-mono text-[10px] text-[#727a8a]">(44005)</span>
              </div>
              <ArrowUpRight size={13} className="text-[#656e80]" />
            </a>

            <a
              href="https://qday.io"
              target="_blank"
              rel="noreferrer"
              className="flex items-center justify-between px-3.5 py-2.5 rounded-lg text-xs text-[#a2aab8] hover:text-white hover:bg-white/[0.05] transition-colors"
            >
              <span>QDay.io Official</span>
              <ArrowUpRight size={13} className="text-[#656e80]" />
            </a>

            <a
              href="https://github.com/Kaycee276/cimon"
              target="_blank"
              rel="noreferrer"
              className="flex items-center justify-between px-3.5 py-2.5 rounded-lg text-xs text-[#a2aab8] hover:text-white hover:bg-white/[0.05] transition-colors"
            >
              <span>GitHub Repository</span>
              <ArrowUpRight size={13} className="text-[#656e80]" />
            </a>
          </div>

          {/* Footer note inside mobile drawer */}
          <div className="pt-4 mt-6 border-t border-white/[0.08] text-[11px] text-[#727a8a] flex items-center justify-between">
            <span>Confirmation of Payee</span>
            <span>Settled in tUSD8</span>
          </div>
        </div>
      )}
    </header>
  );
}
