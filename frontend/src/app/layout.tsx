import type { Metadata } from 'next';
import localFont from 'next/font/local';
import { Providers } from '../components/providers';
import { Navbar } from '../components/navbar';
import { Footer } from '../components/footer';
import '@rainbow-me/rainbowkit/styles.css';
import './globals.css';
import './product.css';
import './homepage-motion.css';
const display = localFont({ src: '../../public/fonts/quicksand-medium.ttf', weight: '500', variable: '--font-display', display: 'swap' });
const sans = localFont({ src: '../../public/fonts/noto-sans-regular.ttf', weight: '400', variable: '--font-sans', display: 'swap' });
const mono = localFont({ src: '../../public/fonts/dejavu-sans-mono.ttf', weight: '400', variable: '--font-mono', display: 'swap' });
export const metadata: Metadata = { title: 'CIMON — Confirmation of Payee', description: 'Verified invoicing and safer tUSD8 settlement on QDay Aevum.' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body className={`${display.variable} ${sans.variable} ${mono.variable} antialiased`}><Providers><Navbar/><main>{children}</main><Footer/></Providers></body></html>;
}
