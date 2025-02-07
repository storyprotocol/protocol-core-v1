// Test: LicensingModule - mintLicenseTokens

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";
import { PILicenseTemplate } from "../constants";

describe("LicensingModule - mintLicenseTokens", function () {
  let signers: any;
  let tokenId: any;
  let ipId: any;

  this.beforeAll("Get Signers", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners();
    
    const result = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    tokenId = result.tokenId;
    ipId = result.ipId;
    console.log("tokenId: ", tokenId);
    console.log("ipId: ", ipId);

    const connectedLicensingModule = this.licensingModule.connect(signers[0]);

    const attachLicenseTx = await expect(
      connectedLicensingModule.attachLicenseTerms(ipId, PILicenseTemplate, this.nonCommercialLicenseId)
    ).not.to.be.rejectedWith(Error);
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");
  });

  it("IP asset owner mint license tokens", async function () {
    const connectedLicensingModule = this.licensingModule.connect(signers[0]);

    const mintLicenseTokensTx = await expect(

      connectedLicensingModule.mintLicenseTokens(ipId, PILicenseTemplate, this.nonCommercialLicenseId, 2, signers[0].address, hre.ethers.ZeroAddress, 0, 50 * 10 ** 6)
    ).not.to.be.rejectedWith(Error);
    expect(mintLicenseTokensTx.hash).to.not.be.empty.and.to.be.a("HexString");

    const startLicenseTokenId = await mintLicenseTokensTx.wait().then((receipt:any) => receipt.logs[4].args[6]);
    console.log(startLicenseTokenId);
    expect(startLicenseTokenId).to.be.a("bigint");
  });

  it("Non-IP asset owner mint license tokens", async function () {
    const nonOwnerLicensingModule = this.licensingModule.connect(signers[1]);

    const mintLicenseTokensTx = await expect(

      nonOwnerLicensingModule.mintLicenseTokens(ipId, PILicenseTemplate, this.nonCommercialLicenseId, 2, signers[0].address, hre.ethers.ZeroAddress, 0, 50 * 10 ** 6)
    ).not.to.be.rejectedWith(Error);
    expect(mintLicenseTokensTx.hash).to.not.be.empty.and.to.be.a("HexString");

    const startLicenseTokenId = await mintLicenseTokensTx.wait().then((receipt:any) => receipt.logs[4].args[6]);
    console.log(startLicenseTokenId);
    expect(startLicenseTokenId).to.be.a("bigint");
  });

  it("Mint license tokens with amount 0", async function () {
    const connectedLicensingModule = this.licensingModule.connect(signers[0]);

    const mintLicenseTokensTx = await expect(

      connectedLicensingModule.mintLicenseTokens(ipId, PILicenseTemplate, this.nonCommercialLicenseId, 0, signers[0].address, hre.ethers.ZeroAddress, 0, 50 * 10 ** 6)
    ).to.be.rejectedWith("execution reverted");
  });

  it("Mint license tokens with different receivers", async function () {
    const nonOwnerLicensingModule = this.licensingModule.connect(signers[0]);

    const mintLicenseTokensTx = await expect(

      nonOwnerLicensingModule.mintLicenseTokens(ipId, PILicenseTemplate, this.nonCommercialLicenseId, 2, signers[1].address, hre.ethers.ZeroAddress, 0, 50 * 10 ** 6)
    ).not.to.be.rejectedWith(Error);
    expect(mintLicenseTokensTx.hash).to.not.be.empty.and.to.be.a("HexString");

    const startLicenseTokenId = await mintLicenseTokensTx.wait().then((receipt:any) => receipt.logs[4].args[6]);
    console.log(startLicenseTokenId);
    expect(startLicenseTokenId).to.be.a("bigint");
  });
});
