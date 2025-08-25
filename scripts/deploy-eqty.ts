import hre from "hardhat";
import { createWalletClient, createPublicClient, http, formatEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { baseSepolia, base } from "viem/chains";
import * as fs from "fs";
import * as path from "path";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  const network = process.env.HARDHAT_NETWORK || "hardhat";
  console.log(`🚀 Deploying EQTY token to ${network}...`);
  
  // Get private key from environment
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("PRIVATE_KEY not found in environment variables");
  }
  
  // Get bridge wallet from environment
  const bridgeWallet = process.env.BRIDGE_WALLET;
  if (!bridgeWallet) {
    throw new Error("BRIDGE_WALLET not found in environment variables");
  }
  
  // Get mint deadline from environment (optional, defaults to 90 days from now)
  const mintDeadline = process.env.MINT_DEADLINE
    ? Math.floor(new Date(process.env.MINT_DEADLINE).getTime() / 1000)
    : Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60);
  
  // Create account from private key (add 0x prefix if not present)
  const formattedPrivateKey = privateKey.startsWith('0x') ? privateKey : `0x${privateKey}`;
  const account = privateKeyToAccount(formattedPrivateKey as `0x${string}`);
  console.log(`👤 Deployer: ${account.address}`);
  console.log(`🌉 Bridge Wallet: ${bridgeWallet}`);
  console.log(`⏰ Mint Deadline: ${new Date(mintDeadline * 1000).toISOString()}`);
  
  // Configure chain and RPC based on network
  let chain;
  let rpcUrl;
  
  switch (network) {
    case "base-sepolia":
      chain = baseSepolia;
      rpcUrl = process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org";
      break;
    case "base":
      chain = base;
      rpcUrl = process.env.BASE_MAINNET_RPC_URL || "https://mainnet.base.org";
      break;
    default:
      throw new Error(`Unsupported network: ${network}. Use 'base-sepolia' or 'base'`);
  }
  
  // Create clients
  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
  });
  
  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(rpcUrl),
  });
  
  // Check balance
  const balance = await publicClient.getBalance({ address: account.address });
  console.log(`💰 Balance: ${formatEther(balance)} ETH`);
  
  if (balance === 0n) {
    throw new Error("Deployer has no ETH balance");
  }
  
  // Get contract artifact
  const artifactPath = path.join(
    process.cwd(),
    "artifacts/contracts/EQTY.sol/EQTY.json"
  );
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf-8"));
  
  console.log("\n📄 Deploying EQTY token...");
  
  // Deploy contract
  const hash = await walletClient.deployContract({
    abi: artifact.abi,
    bytecode: artifact.bytecode as `0x${string}`,
    args: [bridgeWallet, BigInt(mintDeadline)],
  });
  
  console.log(`📤 Transaction hash: ${hash}`);
  console.log(`⏳ Waiting for confirmation...`);
  
  // Wait for transaction receipt
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  
  if (!receipt.contractAddress) {
    throw new Error("Contract deployment failed - no contract address in receipt");
  }
  
  console.log(`✅ EQTY deployed at: ${receipt.contractAddress}`);
  console.log(`   - Block: ${receipt.blockNumber}`);
  console.log(`   - Bridge Wallet: ${bridgeWallet}`);
  console.log(`   - Cap: 500,000,000 EQTY`);
  console.log(`   - Mint Deadline: ${new Date(mintDeadline * 1000).toISOString()}`);
  
  // Save deployment info
  const deploymentsDir = path.join(process.cwd(), "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  
  const deploymentPath = path.join(deploymentsDir, `${network}-eqty.json`);
  
  // Load existing deployment if it exists
  let existingDeployment = {};
  if (fs.existsSync(deploymentPath)) {
    existingDeployment = JSON.parse(fs.readFileSync(deploymentPath, "utf-8"));
  }
  
  const deploymentInfo = {
    ...existingDeployment,
    eqty: {
      address: receipt.contractAddress,
      deploymentHash: hash,
      deployedAt: new Date().toISOString(),
      deployer: account.address,
      bridgeWallet: bridgeWallet,
      cap: "500000000000000000000000000", // 500M * 10^18
      mintDeadline: mintDeadline,
      mintDeadlineFormatted: new Date(mintDeadline * 1000).toISOString(),
      blockNumber: receipt.blockNumber.toString(),
    }
  };
  
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  console.log(`\n✅ Deployment saved to ${deploymentPath}`);
  
  console.log("\n🔍 To verify the contract on Basescan:");
  console.log(`   npx hardhat verify --network ${network} ${receipt.contractAddress} ${bridgeWallet} ${mintDeadline}`);
  
  console.log("\n✨ Deployment complete!");
  console.log("📋 Summary:");
  console.log(`   - Network: ${network}`);
  console.log(`   - Chain ID: ${chain.id}`);
  console.log(`   - EQTY Token: ${receipt.contractAddress}`);
  console.log(`   - Bridge Wallet: ${bridgeWallet}`);
  console.log(`   - Cap: 500,000,000 EQTY`);
  console.log(`   - Minting Deadline: ${new Date(mintDeadline * 1000).toISOString()}`);
  
  const explorerUrl = network === "base-sepolia" 
    ? `https://sepolia.basescan.org/address/${receipt.contractAddress}`
    : `https://basescan.org/address/${receipt.contractAddress}`;
  console.log(`\n🔗 View on Basescan: ${explorerUrl}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
