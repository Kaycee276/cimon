'use client';
import { useState } from 'react';
import type { CopResult } from './cop-preflight-card';
import { CopPreflightCard } from './cop-preflight-card';
const examples = [
  { label: 'Verified business', risk: 0, result: { risk: 0, registered: true, nameChecked: true, exactMatch: true, tier: 2, isFlagged: false, legalName: 'Acme Labs Ltd', successfulTxCount: 42n }, name: 'Acme Labs Ltd', address: '0x8A6f3c9123B77D7815a2C4230017A3eA41b9C2d1' },
  { label: 'Unverified wallet', risk: 1, result: { risk: 1, registered: false, nameChecked: true, exactMatch: false, tier: 0, isFlagged: false, legalName: '', successfulTxCount: 0n }, name: 'Northstar Studio', address: '0x4D31a94B9b2A88b7136fA20596bF7a9139CB58c0' },
  { label: 'Lookalike invoice', risk: 2, result: { risk: 2, registered: true, nameChecked: true, exactMatch: false, tier: 1, isFlagged: true, legalName: 'Acme Lab Services', successfulTxCount: 0n }, name: 'Acme Labs', address: '0x71b0f8D2a6C911E7A6E4a0d949e4e93D81a6A2b0' },
];
export function CopSimulator() {
  const [active, setActive] = useState(0);
  const example = examples[active];
  return <div className="simulator-shell"><div className="simulator-head"><div><span className="eyebrow">LIVE COP SIMULATOR</span><h2>See the difference before you pay.</h2></div><span className="sim-live"><span className="live-dot"/>Interactive demo</span></div><div className="sim-tabs" role="tablist" aria-label="Choose a payee verification scenario">{examples.map((item, i) => <button key={item.label} type="button" role="tab" aria-selected={active === i} className={`sim-tab ${active === i ? `selected selected-${item.risk}` : ''}`} onClick={() => setActive(i)}><span className="sim-tab-index">0{i + 1}</span>{item.label}</button>)}</div><div className="sim-content" key={active}><div className="sim-invoice"><span className="eyebrow">INVOICE PREVIEW</span><div className="sim-amount">$2,480<span>.00</span></div><div className="sim-token">tUSD8 <span>·</span> Security audit</div><div className="sim-payee"><span>Payee claims</span><strong>{example.name}</strong></div><div className="sim-address"><span>Destination</span><code>{example.address}</code></div><div className="sim-footer">Invoice details checked against the registry</div></div><CopPreflightCard result={example.result as CopResult} expectedName={example.name} payee={example.address} domain={active===0?'acmelabs.com':undefined}/></div></div>;
}
