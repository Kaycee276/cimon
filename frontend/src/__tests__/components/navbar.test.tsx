import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { Navbar } from '@/components/navbar';

// Mock next/navigation
vi.mock('next/navigation', () => ({
  usePathname: () => '/',
}));

// Mock @rainbow-me/rainbowkit
vi.mock('@rainbow-me/rainbowkit', () => ({
  ConnectButton: {
    Custom: ({
      children,
    }: {
      children: (props: {
        account: null;
        chain: null;
        openConnectModal: () => void;
        mounted: boolean;
      }) => React.ReactNode;
    }) =>
      children({
        account: null,
        chain: null,
        openConnectModal: vi.fn(),
        mounted: true,
      }),
  },
}));

describe('Navbar Component', () => {
  it('renders the brand title linking to home', () => {
    render(<Navbar />);
    const brand = screen.getByRole('link', { name: 'CIMON' });
    expect(brand).toBeInTheDocument();
    expect(brand).toHaveAttribute('href', '/');
  });

  it('renders navigation links for Invoices, Create invoice, and Registry', () => {
    render(<Navbar />);
    const invoiceLinks = screen.getAllByRole('link', { name: /Invoices/i });
    expect(invoiceLinks.length).toBeGreaterThanOrEqual(1);

    const createLinks = screen.getAllByRole('link', { name: /Create invoice/i });
    expect(createLinks.length).toBeGreaterThanOrEqual(1);

    const registryLinks = screen.getAllByRole('link', { name: /Registry/i });
    expect(registryLinks.length).toBeGreaterThanOrEqual(1);
  });

  it('renders network pill with link to Aevum Explorer', () => {
    render(<Navbar />);
    const networkPill = screen.getByTitle('QDay Aevum Testnet Chain ID 44005');
    expect(networkPill).toHaveAttribute('href', 'https://explorer-test.qday.info');
    expect(networkPill).toHaveAttribute('target', '_blank');
  });

  it('toggles mobile menu drawer when mobile button is pressed', () => {
    render(<Navbar />);
    const toggleButton = screen.getByLabelText(/Open menu/i);
    expect(toggleButton).toBeInTheDocument();

    // Click to open
    fireEvent.click(toggleButton);
    expect(screen.getByLabelText(/Close menu/i)).toBeInTheDocument();

    // Click to close
    fireEvent.click(screen.getByLabelText(/Close menu/i));
    expect(screen.getByLabelText(/Open menu/i)).toBeInTheDocument();
  });
});
