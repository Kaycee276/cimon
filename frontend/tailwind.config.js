/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: { ink: '#090A0F', surface: '#11131B', raised: '#161924', line: 'rgba(255,255,255,.08)', blue: '#3B82F6', verified: '#10B981', caution: '#F59E0B', danger: '#F43F5E' },
      fontFamily: { display: ['var(--font-display)'], sans: ['var(--font-sans)'], mono: ['var(--font-mono)'] },
    },
  },
  plugins: [],
};
