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
  console.log(`🚀 Deploying Anchor contract to ${network} (no EQTY token, 0 fee)...`);
  
  // Get private key from environment
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("PRIVATE_KEY not found in environment variables");
  }
  
  // Create account from private key (add 0x prefix if not present)
  const formattedPrivateKey = privateKey.startsWith('0x') ? privateKey : `0x${privateKey}`;
  const account = privateKeyToAccount(formattedPrivateKey as `0x${string}`);
  console.log(`👤 Deployer: ${account.address}`);
  
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
    "artifacts/contracts/Anchor.sol/Anchor.json"
  );
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf-8"));
  
  console.log("\n📄 Deploying Anchor contract...");
  
  // Deploy contract
  const hash = await walletClient.deployContract({
    abi: artifact.abi,
    bytecode: artifact.bytecode as `0x${string}`,
    args: [],
  });
  
  console.log(`📤 Transaction hash: ${hash}`);
  console.log(`⏳ Waiting for confirmation...`);
  
  // Wait for transaction receipt
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  
  if (!receipt.contractAddress) {
    throw new Error("Contract deployment failed - no contract address in receipt");
  }
  
  console.log(`✅ Anchor deployed at: ${receipt.contractAddress}`);
  console.log(`   - Block: ${receipt.blockNumber}`);
  console.log(`   - Owner: ${account.address}`);
  console.log(`   - EQTY Token: Not set (0x0000...0000)`);
  console.log(`   - Fee: 0`);
  
  // Save deployment info
  const deploymentInfo = {
    anchor: {
      address: receipt.contractAddress,
      deploymentHash: hash,
      deployedAt: new Date().toISOString(),
      anchorFee: "0",
      eqtyToken: "0x0000000000000000000000000000000000000000",
      blockNumber: receipt.blockNumber.toString(),
    }
  };
  
  const deploymentsDir = path.join(process.cwd(), "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  const deploymentPath = path.join(deploymentsDir, `${network}.json`);
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  console.log(`\n✅ Deployment saved to ${deploymentPath}`);
  
  console.log("\n🔍 To verify the contract on Basescan:");
  console.log(`   npx hardhat verify --network ${network} ${receipt.contractAddress}`);
  
  console.log("\n✨ Deployment complete!");
  console.log("📋 Summary:");
  console.log(`   - Network: ${network}`);
  console.log(`   - Chain ID: ${chain.id}`);
  console.log(`   - Anchor: ${receipt.contractAddress}`);
  console.log(`   - EQTY Token: Not set`);
  console.log(`   - Anchor Fee: 0`);
  console.log("\n💡 Note: The Anchor contract is deployed with no EQTY token and 0 fee.");
  console.log("   Users can anchor without any fee requirements.");
  
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