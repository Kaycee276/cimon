import Link from "next/link";
import { ArrowUpRight } from "lucide-react";

export function Footer() {
  return (
    <footer className="footer relative border-t border-white/[0.08] bg-[#07080d] overflow-hidden pt-12 pb-10">
      {/* Top links row */}
      <div className="w-[min(1160px,calc(100%-48px))] mx-auto pb-8 border-b border-white/[0.06] flex flex-wrap items-center justify-between gap-6 text-xs text-[#8c94a4]">
        <div className="flex flex-wrap items-center gap-6 sm:gap-8 font-medium">
          <Link
            href="/invoices/create"
            className="hover:text-white transition-colors"
          >
            Create Invoice
          </Link>
          <Link href="/invoices" className="hover:text-white transition-colors">
            Invoices
          </Link>
          <Link href="/register" className="hover:text-white transition-colors">
            Register Payee
          </Link>
        </div>

        <div className="flex flex-wrap items-center gap-6 sm:gap-7">
          <a
            href="https://qday.io"
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1 hover:text-white transition-colors"
          >
            QDay <ArrowUpRight className="w-3.5 h-3.5 text-[#5a6274]" />
          </a>
          <a
            href="https://explorer-test.qday.info"
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1 hover:text-white transition-colors"
          >
            Explorer <ArrowUpRight className="w-3.5 h-3.5 text-[#5a6274]" />
          </a>
          <a
            href="https://github.com/Kaycee276/cimon"
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1 hover:text-white transition-colors"
          >
            GitHub <ArrowUpRight className="w-3.5 h-3.5 text-[#5a6274]" />
          </a>
        </div>
      </div>

      {/* Full-bleed Centerpiece: As wide as the screen can take */}
      <div className="w-full overflow-hidden select-none pointer-events-none my-4 sm:my-8 text-center px-1">
        <span className="block w-full font-display font-medium tracking-[-0.04em] leading-[0.78] text-[28.5vw] text-white/[0.05] uppercase whitespace-nowrap">
          CIMON
        </span>
      </div>

      {/* Bottom metadata & attribution row */}
      <div className="w-[min(1160px,calc(100%-48px))] mx-auto pt-6 border-t border-white/[0.05] flex flex-col sm:flex-row items-center justify-between gap-4 text-[11px] text-[#6b7280]">
        <div className="flex items-center gap-2.5">
          <span>Confirmation of Payee Protocol</span>
          <span className="text-white/10">·</span>
          <span className="font-mono text-[10px] text-[#7d8597]">
            QDay Aevum Testnet (44005)
          </span>
        </div>

        <div className="flex flex-wrap items-center gap-4 sm:gap-6">
          <span>Settled in tUSD8</span>
          <span className="text-white/10">·</span>
          <a
            href="https://qday.io/builder-challenge"
            target="_blank"
            rel="noreferrer"
            className="hover:text-white transition-colors"
          >
            Aevum Builder Challenge #1
          </a>
          <span className="text-white/10">·</span>
          <span className="text-[#9ca3af]">
            © {new Date().getFullYear()} CIMON
          </span>
        </div>
      </div>
    </footer>
  );
}
