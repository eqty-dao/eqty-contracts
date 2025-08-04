import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-viem";
import "@typechain/hardhat";
import "@nomicfoundation/hardhat-verify";
import "hardhat-abi-exporter";
import "hardhat-gas-reporter";
import "solidity-coverage";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 1000000 // Optimize for many deployments (stateless contract)
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 31337, // Default Hardhat chain ID
    },
    base: {
      url: process.env.BASE_MAINNET_RPC_URL || "https://mainnet.base.org",
      chainId: 8453,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: 1000000, // 0.001 gwei
    },
    "base-sepolia": {
      url: process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org",
      chainId: 84532,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: 1000000, // 0.001 gwei
    }
  },
  etherscan: {
    apiKey: process.env.BASESCAN_API_KEY || "",
    customChains: [
      {
        network: "base-sepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org"
        }
      }
    ]
  },
  sourcify: {
    enabled: true
  },
  abiExporter: {
    path: "./abi",
    runOnCompile: true,
    clear: true,
    flat: true,
    only: ["Anchor", "IAnchor"],
    format: "json",
  },
  mocha: {
    timeout: 100000
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    gasPrice: 0.025, // Base L2 actual gas price in gwei
    baseFee: 25, // L1 base fee in gwei
    blobBaseFee: 1, // L1 blob base fee in gwei
    token: "ETH",
    tokenPrice: "3600", // Hardcoded ETH price in USD
    currencyDisplayPrecision: 5, // Show 5 decimal places for USD values
    showMethodSig: true, // Show function signatures
    excludeContracts: [], // Show all contracts
    outputFile: process.env.REPORT_GAS === "file" ? "gas-report.txt" : undefined,
    noColors: false,
    L2: "base", // Configure for Base L2 network
    offline: true // Don't fetch live data
  },
  // @ts-ignore
  solcover: {
    skipFiles: [
      "test/",
      "mocks/",
      "interfaces/"
    ]
  }
};

export default config;