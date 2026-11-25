import Link from "next/link";
import { ArrowUpRight } from "lucide-react";

export function Footer() {
  return (
    <footer className="footer relative border-t border-white/[0.08] bg-[#07080d] overflow-hidden pt-12 pb-10">
      <div className="w-[min(1160px,calc(100%-48px))] mx-auto flex flex-col justify-between">
        {/* Top links row */}
        <div className="flex flex-wrap items-center justify-between gap-6 pb-8 border-b border-white/[0.06] text-xs text-[#8c94a4]">
          <div className="flex flex-wrap items-center gap-6 sm:gap-8 font-medium">
            <Link
              href="/invoices/create"
              className="hover:text-white transition-colors"
            >
              Create Invoice
            </Link>
            <Link
              href="/invoices"
              className="hover:text-white transition-colors"
            >
              Invoices
            </Link>
            <Link
              href="/register"
              className="hover:text-white transition-colors"
            >
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

        {/* Centerpiece: CIMON Very Big, Very Light */}
        <div className="py-10 sm:py-16 text-center select-none pointer-events-none">
          <span className="block font-display font-medium tracking-[-0.05em] leading-[0.8] text-[clamp(4.8rem,19vw,15.5rem)] text-white/[0.06] uppercase">
            CIMON
          </span>
        </div>

        {/* Bottom links & metadata */}
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-6 border-t border-white/[0.05] text-[11px] text-[#6b7280]">
          <div className="flex items-center gap-2.5">
            <span className="inline-block w-1.5 h-1.5 rounded-full bg-emerald-400" />
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
      </div>
    </footer>
  );
}
