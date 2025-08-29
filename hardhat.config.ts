import "@nomicfoundation/hardhat-ethers"
import "@nomicfoundation/hardhat-foundry"
import "@nomicfoundation/hardhat-verify"
// Tenderly imports removed - set USE_TENDERLY=false to disable
import "@typechain/hardhat"
// import "@openzeppelin/hardhat-upgrades"
import "hardhat-gas-reporter"
import "hardhat-deploy"
import { HardhatConfig, HardhatUserConfig } from "hardhat/types"
import "hardhat-contract-sizer" // npx hardhat size-contracts
import "solidity-coverage"
import "solidity-docgen"
import "@nomicfoundation/hardhat-chai-matchers"

require("dotenv").config()

//
// NOTE:
// To load the correct .env, you must run this at the root folder (where hardhat.config is located)
//
const MAINNET_URL = process.env.MAINNET_URL || "https://eth-mainnet"
const MAINNET_PRIVATEKEY = process.env.MAINNET_PRIVATEKEY || "0xkey"
const SEPOLIA_URL = process.env.SEPOLIA_URL || "https://eth-sepolia"
const SEPOLIA_PRIVATEKEY = process.env.SEPOLIA_PRIVATEKEY || "0xkey"
// Tenderly config removed - set USE_TENDERLY=false to disable
const USE_TENDERLY = false

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "key"
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "key"

const STORY_URL = process.env.STORY_URL || "http://"
const STORY_CHAINID = Number(process.env.STORY_CHAINID) || 1513
const STORY_PRIVATEKEY = process.env.STORY_PRIVATEKEY || "0xkey"
const STORY_USER1 = process.env.STORY_USER1 || "0xkey"
const STORY_USER2 = process.env.STORY_USER2 || "0xkey"

// Tenderly setup removed - set USE_TENDERLY=false to disable

/** @type import('hardhat/config').HardhatUserConfig */
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.26",
        settings: {
          optimizer: {
            enabled: true,
            runs: 2000,
          },
          evmVersion: "cancun",
        },
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
    },
    odyssey: {
      chainId: STORY_CHAINID,
      url: STORY_URL,
      accounts: [STORY_PRIVATEKEY, STORY_USER1, STORY_USER2],
    },
    internal_devnet: {
      chainId: STORY_CHAINID,
      url: STORY_URL,
      accounts: [STORY_PRIVATEKEY, STORY_USER1, STORY_USER2],
    },
    aeneid: {
      chainId: STORY_CHAINID,
      url: STORY_URL,
      accounts: [STORY_PRIVATEKEY, STORY_USER1, STORY_USER2],
    },
    localhost: {
      chainId: 31337,
      url: "http://127.0.0.1:8545/",
    },
    mainnet: {
      chainId: 1,
      url: MAINNET_URL || "",
      accounts: [MAINNET_PRIVATEKEY],
    },
    sepolia: {
      chainId: 11155111,
      url: SEPOLIA_URL || "",
      accounts: [SEPOLIA_PRIVATEKEY],
    },
  },
  // @ts-ignore
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    outputFile: "gas-report.txt",
    noColors: true,
    currency: "USD",
    coinmarketcap: COINMARKETCAP_API_KEY,
  },
  mocha: {
    timeout: 200_000,
    reporter: "mochawesome",
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
      // Tenderly config removed - set USE_TENDERLY=false to disable
  typechain: {
    outDir: "typechain",
    target: "ethers-v6",
  },
  docgen: {
    outputDir: "./docs",
    pages: "files"
  }
}

export default config
