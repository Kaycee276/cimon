import { AlertOctagon, Check, Copy } from 'lucide-react';
import { truncateAddress } from '../lib/utils';
export type CopResult = { risk: number; registered: boolean; nameChecked: boolean; exactMatch: boolean; tier: number; isFlagged: boolean; legalName: string; successfulTxCount: bigint; domain?: string };
export function CopPreflightCard({ result, expectedName, payee, onCopy, domain }: { result?: CopResult; expectedName?: string; payee?: string; onCopy?: () => void; domain?: string }) {
  const level = result?.risk ?? 1;
  const label = level === 0 ? 'VERIFIED' : level === 1 ? 'CAUTION' : 'HIGH RISK';
  const tierLabel = ['Unregistered', 'Basic user', 'Verified business', 'Government verified'][result?.tier ?? 0] ?? 'Unknown';
  const checks = [
    ['Name comparison', !result?.nameChecked ? 'No expected name supplied' : !result.registered ? 'No registered identity to compare' : result.exactMatch ? 'Exact match' : 'Does not match', result?.nameChecked && result.registered ? result.exactMatch : undefined],
    ['Identity tier', tierLabel, (result?.tier ?? 0) >= 2],
    ['Registered domain', domain ? `${domain} · ${(result?.tier ?? 0) >= 2 ? 'Attestor verified' : 'Self-asserted'}` : 'Not provided', domain ? (result?.tier ?? 0) >= 2 : undefined],
    ['Registry flags', result?.isFlagged ? 'Address flagged' : 'No active flags', !result?.isFlagged],
    ['Successful settlements', result ? result.successfulTxCount.toString() : 'Not available', undefined],
  ] as const;
  return <section className={`cop-card risk-${level}`}>
    <div className="cop-card-top"><div><span className="eyebrow">CONFIRMATION OF PAYEE</span><h2>Recipient verification</h2></div><span className={`risk-badge risk-badge-${level}`}><span className="verdict-mark"/>{label}</span></div>
    <div className="entity-row"><div className="entity-copy"><strong>{result?.legalName || expectedName || 'Unregistered payee'}</strong><span>{result?.legalName && expectedName ? `Claimed as “${expectedName}”` : result?.registered ? 'Identity registered on CimonRegistry' : 'No identity profile found on CimonRegistry'}</span></div>{result?.tier && result.tier >= 2 ? <span className="tier-badge">{tierLabel}</span> : null}</div>
    <div className="address-line"><span>PAYOUT ADDRESS</span><code>{truncateAddress(payee, 10)}</code><button aria-label="Copy payee address" className="icon-button" onClick={onCopy}><Copy size={14}/></button></div>
    <div className="audit-list">{checks.map(([name, value, passed]) => <div className="audit-row" key={name}><span className={`audit-icon ${passed === true ? 'pass' : passed === false ? 'fail' : 'neutral'}`}>{passed === true ? <Check size={12}/> : passed === false ? <AlertOctagon size={12}/> : <span>·</span>}</span><span>{name}</span><strong>{value}</strong></div>)}</div>
    <p className="risk-note">{level === 0 ? 'Verified identity and matching invoice details. Review the amount before you authorize settlement.' : level === 1 ? 'This payee has limited or no independent attestation. Confirm the address with the merchant through a separate channel.' : 'Do not pay until you have independently verified the recipient. This address is flagged or the registered name conflicts with the invoice.'}</p>
  </section>;
}
