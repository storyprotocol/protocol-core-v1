import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";
import { PILicenseTemplate } from "../constants";

describe.only("LicensingModule - mintLicenseTokens", function () {
  let signers: any;

  this.beforeAll("Get Signers", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners();   
  });

  it("IP asset owner mint license tokens", async function () {
    const { tokenId, ipId } = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    console.log("tokenId: ", tokenId);
    console.log("ipId: ", ipId);

    const connectedLicensingModule = this.licensingModule.connect(signers[0]);

    const attachLicenseTx = await expect(
      connectedLicensingModule.attachLicenseTerms(ipId, PILicenseTemplate, this.nonCommericialLicenseId)
    ).not.to.be.rejectedWith(Error);
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");

    const mintLicenseTokensTx = await expect(
      connectedLicensingModule.mintLicenseTokens(ipId, PILicenseTemplate, this.nonCommericialLicenseId, 2, signers[0].address, hre.ethers.ZeroAddress, 100)
    ).not.to.be.rejectedWith(Error);
    expect(mintLicenseTokensTx.hash).to.not.be.empty.and.to.be.a("HexString");

    const startLicenseTokenId = await mintLicenseTokensTx.wait().then((receipt:any) => receipt.logs[4].args[6]);
    console.log(startLicenseTokenId);
    expect(startLicenseTokenId).to.be.a("bigint");
  });
});
