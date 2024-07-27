import { task } from "hardhat/config";
import fs from "fs";
import Safe, { Eip1193Provider } from "@safe-global/protocol-kit";
import { MetaTransactionData } from "@safe-global/safe-core-sdk-types";
import dotenv from "dotenv";
import SafeApiKit, { ProposeTransactionProps } from '@safe-global/api-kit'
import { ethers, BrowserProvider } from "ethers";

// Load environment variables
dotenv.config();

export function getEip1193Provider(provider: BrowserProvider): Eip1193Provider {
    return {
        request: async (request) => {
            return provider.send(request.method, [...((request.params as unknown[]) ?? [])])
        }
    }
}

task("propose-safe-tx", "Proposes a Safe transaction")
    .addParam("jsonFile", "Path to the JSON file containing transaction data")
    .setAction(async (taskArgs, hre) => {
        const { jsonFile } = taskArgs;

        // Read and parse the JSON file
        const transactions: MetaTransactionData[] = JSON.parse(fs.readFileSync(jsonFile, "utf8"));

        const requiredEnvVars = ['SEPOLIA_MULTISIG_ADDRESS', 'SEPOLIA_PRIVATEKEY'];
        for (const envVar of requiredEnvVars) {
            if (!process.env[envVar]) {
                throw new Error(`Environment variable ${envVar} is not set`);
            }
        }
        const safeAddress = process.env.SEPOLIA_MULTISIG_ADDRESS!;
        const privateKey = process.env.SEPOLIA_PRIVATEKEY!;

        // Set up the provider and signer
        const browserProvider = new ethers.BrowserProvider(hre.network.provider)

        // Initialize Safe SDK
        const safeSdk = await Safe.init({
            provider: getEip1193Provider(browserProvider),
            signer: privateKey,
            safeAddress
        })

        const apiKit = new SafeApiKit({
            chainId: BigInt(hre.network.config.chainId!)
        })


        // Create Safe transaction
        const safeTx = await safeSdk.createTransaction({ transactions })

        console.log("Transaction:");
        console.log(safeTx);

        const txHash = await safeSdk.getTransactionHash(safeTx)

        // EOA signature
        const signedTx = await safeSdk.signTransaction(safeTx)

        const signerAddress = (await safeSdk.getSafeProvider().getSignerAddress())!
        const txOptions: ProposeTransactionProps = {
            safeAddress,
            safeTransactionData: safeTx.data,
            safeTxHash: txHash,
            senderAddress: signerAddress,
            senderSignature: signedTx.getSignature(signerAddress)!.data
        }

        const result = await apiKit.proposeTransaction(txOptions)
        console.log("Transaction proposed");
    });