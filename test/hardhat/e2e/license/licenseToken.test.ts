// Test: licenseToken - transferFrom, balanceOf

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { MockERC721, PILicenseTemplate } from "../constants";
import { terms } from "../licenseTermsTemplate";
import { mintNFT } from "../utils/nftHelper";

describe("licenseToken - transferFrom", function () {
  let signers: any;
  let ipId: string;

  this.beforeAll("Get Signers", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners();
    
    const tokenId = await mintNFT(signers[0]);
    console.log("tokenId: ", tokenId);

    const connectedIpAssetRegistry = this.ipAssetRegistry.connect(signers[0]);
    ipId = await expect(
      connectedIpAssetRegistry.register(this.chainId, MockERC721, tokenId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[2].args[0]);
    console.log("ipId:", ipId);
  });

  it("Transfer license token", async function () {
    const testTerms = terms;
    testTerms.transferable = true;

    const connectedLicense = this.licenseTemplate.connect(signers[0]);
    const tx = await expect(
      connectedLicense.registerLicenseTerms(testTerms)
    ).to.not.be.rejectedWith(Error);
    await tx.wait();

    const licenseTermsId = await connectedLicense.getLicenseTermsId(testTerms);
    console.log("licenseTermsId: ", licenseTermsId);

    const isTransferable = await connectedLicense.isLicenseTransferable(licenseTermsId);
    console.log("isTransferable: ", isTransferable);
    expect(isTransferable).to.be.true;


    const connectedLicensingModule = this.licensingModule.connect(signers[0]);

    const mintLicenseTokensTx = await expect(
      connectedLicensingModule.mintLicenseTokens(ipId, PILicenseTemplate, licenseTermsId, 1, signers[0].address, hre.ethers.ZeroAddress, 0, 50 * 10 ** 6)
    ).not.to.be.rejectedWith(Error);
    await mintLicenseTokensTx.wait();
    console.log("mintLicenseTokensTx: ", mintLicenseTokensTx.hash);
    expect(mintLicenseTokensTx.hash).to.not.be.empty.and.to.be.a("HexString");

    const startLicenseTokenId = await mintLicenseTokensTx.wait().then((receipt:any) => receipt.logs[receipt.logs.length - 1].args[6]);
    console.log(startLicenseTokenId);

    const connectedLicenseToken = this.licenseToken.connect(signers[0]);
    const ownerBalanceOfBefore = await connectedLicenseToken.balanceOf(signers[0].address);
    console.log("ownerBalanceOfBefore: ", ownerBalanceOfBefore);

    const user1BalanceOfBefore = await connectedLicenseToken.balanceOf(signers[1].address);
    console.log("user1BalanceOfBefore: ", user1BalanceOfBefore);

    await expect(
      connectedLicenseToken.transferFrom(signers[0].address, signers[1].address, startLicenseTokenId)
    ).to.not.be.rejectedWith(Error).then((tx: any) => tx.wait());
    
    const ownerBalanceOfAfter = await connectedLicenseToken.balanceOf(signers[0].address);
    expect(ownerBalanceOfAfter).to.equal(ownerBalanceOfBefore - BigInt(1));

    const user1BalanceOfAfter = await connectedLicenseToken.balanceOf(signers[1].address);
    expect(user1BalanceOfAfter).to.equal(user1BalanceOfBefore + BigInt(1));
  });

  it("Transfer license token failed as not transferable", async function () {
    const testTerms = terms;
    testTerms.transferable = false;

    const connectedLicense = this.licenseTemplate.connect(signers[0]);
    const tx = await expect(
      connectedLicense.registerLicenseTerms(testTerms)
    ).to.not.be.rejectedWith(Error);
    await tx.wait();

    const licenseTermsId = await connectedLicense.getLicenseTermsId(testTerms);
    console.log("licenseTermsId: ", licenseTermsId);

    const isTransferable = await connectedLicense.isLicenseTransferable(licenseTermsId);
    console.log("isTransferable: ", isTransferable);
    expect(isTransferable).to.be.false;

    const connectedLicensingModule = this.licensingModule.connect(signers[0]);

    const mintLicenseTokensTx = await expect(
      connectedLicensingModule.mintLicenseTokens(ipId, PILicenseTemplate, licenseTermsId, 1, signers[0].address, hre.ethers.ZeroAddress, 0, 50 * 10 ** 6)
    ).not.to.be.rejectedWith(Error);
    await mintLicenseTokensTx.wait();
    console.log("mintLicenseTokensTx: ", mintLicenseTokensTx.hash);
    expect(mintLicenseTokensTx.hash).to.not.be.empty.and.to.be.a("HexString");

    const startLicenseTokenId = await mintLicenseTokensTx.wait().then((receipt:any) => receipt.logs[receipt.logs.length - 1].args[6]);
    console.log(startLicenseTokenId);

    const connectedLicenseToken = this.licenseToken.connect(signers[0]);
    const ownerBalanceOfBefore = await connectedLicenseToken.balanceOf(signers[0].address);
    console.log("ownerBalanceOfBefore: ", ownerBalanceOfBefore);

    const user1BalanceOfBefore = await connectedLicenseToken.balanceOf(signers[1].address);
    console.log("user1BalanceOfBefore: ", user1BalanceOfBefore);

    await expect(
      connectedLicenseToken.transferFrom(signers[0].address, signers[1].address, startLicenseTokenId)
    ).to.be.revertedWithCustomError(this.errors, "LicenseToken__NotTransferable");
    
    const ownerBalanceOfAfter = await connectedLicenseToken.balanceOf(signers[0].address);
    expect(ownerBalanceOfAfter).to.equal(ownerBalanceOfBefore);

    const user1BalanceOfAfter = await connectedLicenseToken.balanceOf(signers[1].address);
    expect(user1BalanceOfAfter).to.equal(user1BalanceOfBefore);
  });
});
