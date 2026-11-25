import { describe, it, expect } from 'vitest';
import { GET } from '@/app/api/receipt/[id]/route';

describe('Receipt API Route (/api/receipt/[id])', () => {
  it('returns 400 for invalid invoice ID format', async () => {
    const request = new Request('http://localhost:3000/api/receipt/invalid-id');
    const response = await GET(request, { params: Promise.resolve({ id: 'invalid-id' }) });

    expect(response.status).toBe(400);
    const data = await response.json();
    expect(data.error).toBe('Invalid invoice ID.');
  });

  it('returns 503 if CimonPay address is not configured in process.env', async () => {
    const validBytes32 = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const request = new Request(`http://localhost:3000/api/receipt/${validBytes32}`);
    const response = await GET(request, { params: Promise.resolve({ id: validBytes32 }) });

    // Since NEXT_PUBLIC_CIMON_PAY_ADDRESS is undefined in test env by default
    expect(response.status).toBe(503);
    const data = await response.json();
    expect(data.error).toBe('CimonPay address is not configured.');
  });
});
