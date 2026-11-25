import { parseAbi } from 'viem';

export const tokenAddress = '0x456569838f1d43009A91ebA4263147Afd7233483' as const;
export const payAddress = process.env.NEXT_PUBLIC_CIMON_PAY_ADDRESS as `0x${string}` | undefined;
export const registryAddress = process.env.NEXT_PUBLIC_CIMON_REGISTRY_ADDRESS as
  `0x${string}` | undefined;

export const erc20Abi = parseAbi([
  'function allowance(address owner, address spender) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function balanceOf(address account) view returns (uint256)',
  'function decimals() view returns (uint8)',
]);
export const payAbi = parseAbi([
  'function getInvoice(bytes32 invoiceId) view returns ((bytes32 id,address merchant,address expectedPayee,uint256 amount,string memo,uint256 safetyDelay,uint256 paidAt,uint8 status,address actualPayer))',
  'function getExpectedName(bytes32 invoiceId) view returns (string)',
  'function copCheck(bytes32 invoiceId) view returns ((uint8 risk,bool registered,bool nameChecked,bool exactMatch,uint8 tier,bool isFlagged,string legalName,uint256 successfulTxCount))',
  'function copCheckAddress(address payee,string expectedName) view returns ((uint8 risk,bool registered,bool nameChecked,bool exactMatch,uint8 tier,bool isFlagged,string legalName,uint256 successfulTxCount))',
  'function createInvoiceWithName(address expectedPayee,uint256 amount,string memo,uint256 safetyDelay,string expectedName) returns (bytes32 invoiceId)',
  'function payInvoiceWithRiskCap(bytes32 invoiceId,uint8 maxRisk)',
  'function getMerchantInvoiceIds(address merchant,uint256 offset,uint256 limit) view returns (bytes32[])',
  'function getPayerInvoiceIds(address payer,uint256 offset,uint256 limit) view returns (bytes32[])',
  'function releaseTime(bytes32 invoiceId) view returns (uint256)',
  'function claimEscrow(bytes32 invoiceId)',
  'function disputeOrCancel(bytes32 invoiceId)',
  'function cancelInvoice(bytes32 invoiceId)',
  'function getReceipt(bytes32 invoiceId) view returns ((uint256 settledAt,bytes32 receiptHash))',
  'event InvoiceCreated(bytes32 indexed id,address indexed merchant,address indexed expectedPayee,uint256 amount,uint256 safetyDelay,string memo,string expectedName)',
]);
export const registryAbi = parseAbi([
  'function getProfile(address payee) view returns ((string legalName,string tradeName,string domain,bytes32 registrationHash,address payoutAddress,uint8 tier,uint256 registeredAt,bool isFlagged,uint256 successfulTxCount))',
  'function registerPayee(string legalName,string tradeName,string domain,bytes32 registrationHash)',
  'function updateProfile(string legalName,string tradeName,string domain,bytes32 registrationHash)',
]);
