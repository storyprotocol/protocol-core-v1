// Test: LicensingModule - attachLicenseTerms

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
    console.log(this.nonCommericialLicenseId);

    const attachLicenseTx = await expect(
      connectedLicensingModule.attachLicenseTerms(ipId, PILicenseTemplate, this.commericialUseLicenseId)
    ).not.to.be.rejectedWith(Error);
    await attachLicenseTx.wait();
    console.log(attachLicenseTx.hash);
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");
  });
});
