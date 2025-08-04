import { HardhatRuntimeEnvironment } from "hardhat/types";
import hre from "hardhat";
import type { Address } from "viem";
import { baseSepolia } from "viem/chains";
import * as fs from "fs";
import * as path from "path";

export interface DeploymentInfo {
  eqty?: {
    address: Address;
    deploymentHash: string;
    deployedAt: string;
  };
  anchor: {
    address: Address;
    deploymentHash: string;
    deployedAt: string;
    anchorFee: string;
    eqtyToken?: string;
  };
}

export async function getClients() {
  const networkName = getNetworkName();
  let chain = undefined;
  
  // Explicitly specify chain for base-sepolia to avoid conflicts
  if (networkName === "base-sepolia") {
    chain = baseSepolia;
  }
  
  const [deployer] = await hre.viem.getWalletClients(chain ? { chain } : {});
  const publicClient = await hre.viem.getPublicClient(chain ? { chain } : {});
  
  if (!deployer) {
    throw new Error("No wallet client available. Check your configuration.");
  }
  
  return { deployer, publicClient };
}

export function getNetworkName(): string {
  return process.env.HARDHAT_NETWORK || "hardhat";
}

export function getDeploymentsPath(network?: string): string {
  const networkName = network || getNetworkName();
  const deploymentsDir = path.join(process.cwd(), "deployments");
  
  // Create deployments directory if it doesn't exist
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  
  return path.join(deploymentsDir, `${networkName}.json`);
}

export function saveDeployment(deployment: DeploymentInfo, network?: string): void {
  const deploymentPath = getDeploymentsPath(network);
  fs.writeFileSync(deploymentPath, JSON.stringify(deployment, null, 2));
  console.log(`✅ Deployment saved to ${deploymentPath}`);
}

export function loadDeployment(network?: string): DeploymentInfo {
  const deploymentPath = getDeploymentsPath(network);
  
  if (!fs.existsSync(deploymentPath)) {
    throw new Error(`No deployment found for ${network || getNetworkName()}. Run deploy script first.`);
  }
  
  return JSON.parse(fs.readFileSync(deploymentPath, "utf-8"));
}

export async function verifyContract(
  address: Address,
  constructorArgs: any[] = []
): Promise<void> {
  const network = getNetworkName();
  
  // Skip verification on local networks
  if (network === "hardhat" || network === "localhost") {
    console.log("📝 Skipping verification on local network");
    return;
  }

  console.log(`📝 Verifying contract at ${address} on ${network}...`);
  
  try {
    await hre.run("verify:verify", {
      address,
      constructorArguments: constructorArgs,
    });
    console.log("✅ Contract verified successfully");
  } catch (error: any) {
    if (error.message.includes("already verified")) {
      console.log("✅ Contract already verified");
    } else {
      console.error("❌ Verification failed:", error.message);
    }
  }
}