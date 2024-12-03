// Purpose: Helper function to mint an NFT and register it as an IP Asset.

import "../setup";
import { mintNFT } from "./nftHelper";
import { MockERC721, IPAssetRegistry } from "../constants";
import { expect } from "chai";
import hre from "hardhat";
import { network } from "hardhat";
import { HexString } from "ethers/lib.commonjs/utils/data";

export async function mintNFTAndRegisterIPA(mintNFTSigner?: any, registerIPASigner?: any): Promise<{ tokenId: number; ipId: HexString }> {
    const networkConfig = network.config;
    const chainId = networkConfig.chainId;

    const tokenId = await mintNFT(mintNFTSigner);

    const signer = registerIPASigner || (await hre.ethers.getSigners())[0];
    const ipAssetRegistry = await hre.ethers.getContractAt("IPAssetRegistry", IPAssetRegistry, signer);

    // Register the IP Asset
    const ipId = await expect(
        ipAssetRegistry.register(chainId, MockERC721, tokenId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[2].args[0]);

    console.log("ipId:", ipId);

    expect(ipId).to.not.be.empty.and.to.be.a("HexString");

    // Check if the IP Asset is registered
    const isRegistered = await expect(
        ipAssetRegistry.isRegistered(ipId)
    ).not.to.be.rejectedWith(Error);

    expect(isRegistered).to.equal(true);

    // Return both tokenId and ipId as an object
    return { tokenId, ipId };
};

