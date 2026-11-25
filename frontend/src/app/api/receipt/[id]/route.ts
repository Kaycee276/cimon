import { createPublicClient, http } from 'viem';
import { aevumTestnet } from '../../../../lib/aevum-chain';
import { payAbi, payAddress } from '../../../../config/contracts';
export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!/^0x[a-fA-F0-9]{64}$/.test(id))
    return Response.json({ error: 'Invalid invoice ID.' }, { status: 400 });
  if (!payAddress)
    return Response.json({ error: 'CimonPay address is not configured.' }, { status: 503 });
  try {
    const client = createPublicClient({ chain: aevumTestnet, transport: http() });
    const [invoice, receipt] = await Promise.all([
      client.readContract({
        address: payAddress,
        abi: payAbi,
        functionName: 'getInvoice',
        args: [id as `0x${string}`],
      }),
      client.readContract({
        address: payAddress,
        abi: payAbi,
        functionName: 'getReceipt',
        args: [id as `0x${string}`],
      }),
    ]);
    return new Response(
      JSON.stringify(
        {
          protocol: 'CIMON',
          chain: 'QDay Aevum Testnet',
          chainId: 44005,
          invoiceId: id,
          invoice,
          receipt,
        },
        (_, value) => (typeof value === 'bigint' ? value.toString() : value)
      ),
      { headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } }
    );
  } catch {
    return Response.json({ error: 'Receipt could not be read from Aevum.' }, { status: 502 });
  }
}
