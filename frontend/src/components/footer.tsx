import Link from 'next/link';
import { ShieldCheck } from 'lucide-react';
export function Footer() { return <footer className="footer"><div className="footer-inner"><Link href="/" className="brand"><span className="brand-mark"><ShieldCheck size={16}/></span><span>CIMON<span className="brand-period">.</span></span></Link><span>Confirmation of Payee · Aevum Testnet</span><div><a href="https://qday.info" target="_blank" rel="noreferrer">QDay <span>↗</span></a><a href="https://explorer-test.qday.info" target="_blank" rel="noreferrer">Explorer <span>↗</span></a></div></div></footer>; }
