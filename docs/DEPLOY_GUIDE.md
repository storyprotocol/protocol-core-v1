
# PoC Deployment Guide

This guide walks you through setting up your environment and deploying Story's Proof-of-Creativity protocol.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Repository Setup](#repository-setup)
3. [Environment Configuration](#environment-configuration)
4. [Funding the Deployer Wallet](#funding-the-deployer-wallet)
5. [Creating the Deployment Info File](#creating-the-deployment-info-file)
6. [Running the Deployment Script](#running-the-deployment-script)

## Prerequisites
Ensure the following tools are installed:

- **Foundry**: [Installation Guide](https://book.getfoundry.sh/getting-started/installation)
- **Yarn**: [Installation Guide](https://classic.yarnpkg.com/lang/en/docs/install)

## Repository Setup

1. **Clone the Repository:**
   ```bash
   git clone git@github.com:storyprotocol/protocol-core-v1.git && cd protocol-core-v1
   ```

2. **Install Dependencies and Build:**
   ```bash
   yarn && forge build
   ```

## Environment Configuration

1. **Create a `.env` File:**

   In the root directory, create a `.env` file and populate it with the following variables:
   ```bash
   STORY_DEPLOYER_ADDRESS=0x1234567890abcdef       # Deployer address
   STORY_PRIVATEKEY=0x1234567890abcdef             # Deployer private key
   STORY_MULTISIG_ADDRESS=0x1234567890abcdef       # Admin address (not the same as the deployer)
   STORY_RELAYER_ADDRESS=0x1234567890abcdef        # Relayer address (can be the same as the multisig)
   STORY_RPC=https://odyssey.storyrpc.io/          # Story RPC URL
   CREATE3_SALT_SEED=838483948394384394839         # CREATE3 salt seed needs to be unique for each deployment
   ```

   Make sure the addresses and keys are updated to your actual values.

## Funding the Deployer Wallet

- Make sure the deployer wallet has at least **3 IP tokens** (depends on the gas price more tokens might be needed for deployment).

## Creating the Deployment Info File

1. **Create `deployment-v1.3-1516.json` in `deploy-out/`:**
   ```bash
   touch deploy-out/deployment-v1.3-1516.json
   ```
   
   Add the following content to `deploy-out/deployment-v1.3-1516.json`:
   ```json
   {
     "main": ""
   }
   ```
   
   This file will store the addresses of the deployed contracts.

## Running the Deployment Script

1. **Execute the Deployment:**
   ```bash
   source .env && forge script script/foundry/deployment/Main.s.sol:Main $CREATE3_SALT_SEED \
       --sig "run(uint256)" \
       --fork-url $STORY_RPC \
       -vvvv \
       --broadcast \
       --sender $STORY_DEPLOYER_ADDRESS \
       --priority-gas-price 1 \
       --legacy \
       --verify \
       --verifier=blockscout \
       --verifier-url=https://odyssey.storyscan.xyz/api
   ```

- Double-check the values in your `.env` and that your deployer wallet is funded before running this command.
- The `-vvvv` flag enables verbose output, which can help with debugging.



**You’re all set!** Follow the steps above to complete the deployment of the PoC. If you encounter any issues, make sure to verify your `.env` file contents, ensure your deployer wallet is properly funded, and carefully review any error messages from the verbose output.
