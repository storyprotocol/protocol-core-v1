// Purpose: Helper function to mint an NFT and register it as an IP Asset.

import "../setup";
import { mintNFT } from "./nftHelper";
import { MockERC721, IPAssetRegistry, LicensingModule, PILicenseTemplate, GroupingModule } from "../constants";
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

export async function mintNFTAndRegisterIPAWithLicenseTerms(licenseTermsId: any, mintNFTSigner?: any, registerIPASigner?: any): Promise<{ tokenId: number; ipId: HexString }> {
    const { tokenId, ipId } = await mintNFTAndRegisterIPA(mintNFTSigner, registerIPASigner);

    const licensingModule = await hre.ethers.getContractAt("LicensingModule", LicensingModule, registerIPASigner);
    await expect(
        licensingModule.attachLicenseTerms(ipId, PILicenseTemplate, licenseTermsId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    return { tokenId, ipId };
};

export async function registerGroupIPA(groupPool: any, licenseTermsId: any, licenseConfig?: any, registerIPASigner?: any): Promise<HexString> {
    const groupingModule = await hre.ethers.getContractAt("GroupingModule", GroupingModule, registerIPASigner);
    const licensingModule = await hre.ethers.getContractAt("LicensingModule", LicensingModule, registerIPASigner);

    console.log("============ Register Group ============");
    const groupId = await expect(
        groupingModule.registerGroup(groupPool)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[5].args[0]);
    console.log("groupId", groupId);

    console.log("============ Attach License Terms ============");
    await expect(
        licensingModule.attachLicenseTerms(groupId, PILicenseTemplate, licenseTermsId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    if (licenseConfig) {
        console.log("============ Set Licensing Config ============");
        await expect(
            licensingModule.setLicensingConfig(groupId, PILicenseTemplate, licenseTermsId, licenseConfig)
        ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    }
    
    return groupId;
};
