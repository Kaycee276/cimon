import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';
import { formatUnits, isAddress } from 'viem';
export function cn(...inputs: ClassValue[]) { return twMerge(clsx(inputs)); }
export function truncateAddress(value?: string, size = 6) { return value ? `${value.slice(0, size)}…${value.slice(-4)}` : '—'; }
export function formatToken(value?: bigint) { return value === undefined ? '—' : Number(formatUnits(value, 6)).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
export function validAddress(value: string) { return isAddress(value); }
export const explorerTx = (hash: string) => `https://explorer-test.qday.info/tx/${hash}`;
export const explorerAddress = (address: string) => `https://explorer-test.qday.info/address/${address}`;
