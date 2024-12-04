import "@nomicfoundation/hardhat-ethers"
import "@nomicfoundation/hardhat-foundry"
import "@nomicfoundation/hardhat-verify"
import "@tenderly/hardhat-tenderly"
import { TenderlyConfig } from "@tenderly/hardhat-tenderly/dist/tenderly/types"
import * as tdly from "@tenderly/hardhat-tenderly" // also import tdly for setup, in addition to global import above
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
const TENDERLY_URL = process.env.TENDERLY_URL || "https://eth-tenderly"
const TENDERLY_PRIVATEKEY = process.env.TENDERLY_PRIVATEKEY || "0xkey"
const USE_TENDERLY = process.env.USE_TENDERLY === "true"

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "key"
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "key"

const DEVNET_URL = process.env.DEVNET_URL || "http://"
const DEVNET_CHAINID = Number(process.env.DEVNET_CHAINID) || 1513
const DEVNET_PRIVATEKEY = process.env.DEVNET_PRIVATEKEY || "0xkey"
const DEVNET_USER1 = process.env.DEVNET_USER1 || "0xkey"

if (USE_TENDERLY) {
  tdly.setup({
    automaticVerifications: true,
  })
}

/** @type import('hardhat/config').HardhatUserConfig */
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.26",
      },
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 2000,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  defaultNetwork: "tenderly",
  networks: {
    hardhat: {
      chainId: 31337,
    },
    odyssey: {
      chainId: DEVNET_CHAINID,
      url: DEVNET_URL,
      accounts: [DEVNET_PRIVATEKEY, DEVNET_USER1],
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
    ...(USE_TENDERLY
      ? {
          tenderly: {
            chainId: 11155111,
            url: TENDERLY_URL || "",
            accounts: [TENDERLY_PRIVATEKEY],
          },
        }
      : {
          sepolia: {
            chainId: 11155111,
            url: SEPOLIA_URL || "",
            accounts: [SEPOLIA_PRIVATEKEY],
          },
        }),
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
    timeout: 60_000,
    reporter: "mochawesome",
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  ...(USE_TENDERLY
    ? {
        tenderly: {
          project: process.env.TENDERLY_PROJECT_SLUG || "",
          username: process.env.TENDERLY_USERNAME || "",
          privateVerification: process.env.TENDERLY_PRIVATE_VERIFICATION === "true",
        } as TenderlyConfig,
      }
    : {}),
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
