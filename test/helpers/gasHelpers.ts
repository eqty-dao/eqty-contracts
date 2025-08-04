import type { PublicClient, Hash } from "viem";

export interface GasReport {
  operation: string;
  gasUsed: bigint;
  ethCost: bigint;
  usdCost: number;
}

export async function measureGas(
  publicClient: PublicClient,
  txHash: Hash,
  operation: string,
  ethPrice: number = 3000
): Promise<GasReport> {
  const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });
  const gasPrice = receipt.effectiveGasPrice || 0n;
  const ethCost = receipt.gasUsed * gasPrice;
  const usdCost = Number(ethCost) / 1e18 * ethPrice;

  return {
    operation,
    gasUsed: receipt.gasUsed,
    ethCost,
    usdCost
  };
}

export function printGasReport(reports: GasReport[]) {
  console.log("\n=== Gas Usage Report ===");
  console.log("ETH Price: $3,000");
  console.log("Base Network Gas Price: ~0.001 gwei\n");
  
  console.log("Operation                | Gas Used  | ETH Cost    | USD Cost");
  console.log("------------------------|-----------|-------------|----------");
  
  reports.forEach(report => {
    const operation = report.operation.padEnd(23);
    const gasUsed = report.gasUsed.toString().padEnd(9);
    const ethCost = (Number(report.ethCost) / 1e18).toFixed(6).padEnd(11);
    const usdCost = `$${report.usdCost.toFixed(4)}`;
    
    console.log(`${operation} | ${gasUsed} | ${ethCost} | ${usdCost}`);
  });
  
  console.log("\n");
}

export function compareToStorage(eventGas: bigint, estimatedStorageGas: bigint): number {
  const savings = 100 - (Number(eventGas) / Number(estimatedStorageGas) * 100);
  return Math.round(savings);
}