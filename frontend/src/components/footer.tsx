import Link from "next/link";
import { ArrowUpRight } from "lucide-react";

export function Footer() {
  return (
    <footer className="footer relative border-t border-white/[0.08] bg-[#07080d] overflow-hidden pt-10 sm:pt-12 pb-8 sm:pb-10">
      {/* Top links row */}
      <div className="w-[min(1160px,calc(100%-32px))] sm:w-[min(1160px,calc(100%-48px))] mx-auto pb-6 sm:pb-8 border-b border-white/[0.06] flex flex-col md:flex-row items-center justify-between gap-5 sm:gap-6 text-xs text-[#8c94a4]">
        {/* Navigation links */}
        <div className="flex flex-wrap items-center justify-center md:justify-start gap-4 sm:gap-8 font-medium">
          <Link
            href="/invoices/create"
            className="hover:text-white transition-colors py-1"
          >
            Create Invoice
          </Link>
          <Link
            href="/invoices"
            className="hover:text-white transition-colors py-1"
          >
            Invoices
          </Link>
          <Link
            href="/register"
            className="hover:text-white transition-colors py-1"
          >
            Register Payee
          </Link>
        </div>

        {/* External ecosystem links */}
        <div className="flex flex-wrap items-center justify-center md:justify-end gap-5 sm:gap-7">
          <a
            href="https://qday.io"
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1 hover:text-white transition-colors py-1"
          >
            QDay <ArrowUpRight className="w-3.5 h-3.5 text-[#5a6274]" />
          </a>
          <a
            href="https://explorer-test.qday.info"
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1 hover:text-white transition-colors py-1"
          >
            Explorer <ArrowUpRight className="w-3.5 h-3.5 text-[#5a6274]" />
          </a>
          <a
            href="https://github.com/Kaycee276/cimon"
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1 hover:text-white transition-colors py-1"
          >
            GitHub <ArrowUpRight className="w-3.5 h-3.5 text-[#5a6274]" />
          </a>
        </div>
      </div>

      {/* Full-bleed Centerpiece: As wide as the screen can take */}
      <div className="w-full overflow-hidden select-none pointer-events-none my-3 sm:my-8 text-center px-0.5">
        <span className="block w-full font-display font-medium tracking-[-0.04em] leading-[0.78] text-[27.5vw] sm:text-[28.5vw] text-white/[0.05] uppercase whitespace-nowrap">
          CIMON
        </span>
      </div>

      {/* Bottom metadata & attribution row */}
      <div className="w-[min(1160px,calc(100%-32px))] sm:w-[min(1160px,calc(100%-48px))] mx-auto pt-6 border-t border-white/[0.05] flex flex-col sm:flex-row items-center justify-between gap-4 text-[11px] text-[#6b7280] text-center sm:text-left">
        <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2 sm:gap-2.5">
          <span className="inline-block w-1.5 h-1.5 rounded-full bg-emerald-400" />
          <span>Confirmation of Payee Protocol</span>
          <span className="text-white/10 hidden xs:inline">·</span>
          <span className="font-mono text-[10px] text-[#7d8597]">
            QDay Aevum Testnet (44005)
          </span>
        </div>

        <div className="flex flex-wrap items-center justify-center sm:justify-end gap-3 sm:gap-6">
          <span>Settled in tUSD8</span>
          <span className="text-white/10 hidden xs:inline">·</span>
          <a
            href="https://qday.io/builder-challenge"
            target="_blank"
            rel="noreferrer"
            className="hover:text-white transition-colors"
          >
            Aevum Challenge
          </a>
          <span className="text-white/10 hidden xs:inline">·</span>
          <span className="text-[#9ca3af]">
            © {new Date().getFullYear()} CIMON
          </span>
        </div>
      </div>
    </footer>
  );
}
