// Test: LicensingModule - attachLicenseTerms, attachDefaultLicenseTerms

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { MockERC721, PILicenseTemplate } from "../constants";
import { mintNFT } from "../utils/nftHelper";

describe("LicensingModule - attachLicenseTerms", function () {
  let signers: any;

  this.beforeAll("Get Signers", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners();
  });

  it("IP Asset attach a license except for default one", async function () {
    const tokenId = await mintNFT(signers[0]);
    const connectedRegistry = this.ipAssetRegistry.connect(signers[0]);

    const ipId = await expect(
      connectedRegistry.register(this.chainId, MockERC721, tokenId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[2].args[0]);
    console.log("ipId:", ipId);
    expect(ipId).to.not.be.empty.and.to.be.a("HexString");

    const connectedLicensingModule = this.licensingModule.connect(signers[0]);
    console.log(this.nonCommercialLicenseId);

    const attachLicenseTx = await expect(
      connectedLicensingModule.attachLicenseTerms(ipId, PILicenseTemplate, this.commercialUseLicenseId)
    ).not.to.be.rejectedWith(Error);
    await attachLicenseTx.wait();
    console.log(attachLicenseTx.hash);
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");
  });
});

describe("LicensingModule - attachDefaultLicenseTerms", function () {
  let signers: any;
  let ipId: string;

  this.beforeAll("Get Signers", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners();

    const tokenId = await mintNFT(signers[0]);
    const connectedRegistry = this.ipAssetRegistry.connect(signers[0]);

    ipId = await expect(
      connectedRegistry.register(this.chainId, MockERC721, tokenId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[2].args[0]);
    console.log("ipId:", ipId);
  });

  it("IP Asset attach the default license terms", async function () {
    const connectedLicensingModule = this.licensingModule.connect(signers[0]);

    const attachLicenseTx = await expect(
      connectedLicensingModule.attachDefaultLicenseTerms(ipId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");
  });

  it("IP Asset attach the default license terms again", async function () {
    const connectedLicensingModule = this.licensingModule.connect(signers[0]);

    await expect(
      connectedLicensingModule.attachDefaultLicenseTerms(ipId)
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__LicenseTermsAlreadyAttached");
  });
});
