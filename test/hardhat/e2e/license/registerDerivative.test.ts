// Test: LicensingModule - registerDerivative, registerDerivativeWithLicenseTokens

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { PILicenseTemplate } from "../constants";
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";

describe("LicensingModule - registerDerivative", function () {
  let signers:any;
  let ipId1: any;
  let ipId2: any;

  this.beforeAll("Get Signers", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners(); 
  });

  it("Register derivative with the license that parent IP attached", async function () {
    const mintAndRegisterResp1 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    ipId1 = mintAndRegisterResp1.ipId;
    const mintAndRegisterResp2 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    ipId2 = mintAndRegisterResp2.ipId;

    const connectedLicensingModule = this.licensingModule.connect(signers[0]);
    // IP1 attach a non-commercial license
    const attachLicenseTx = await expect(
      connectedLicensingModule.attachLicenseTerms(ipId1, PILicenseTemplate, this.nonCommericialLicenseId)
    ).not.to.be.rejectedWith(Error);
    await attachLicenseTx.wait();
    console.log("Attach license transaction hash: ", attachLicenseTx.hash);
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");
       
    // IP2 is registered as IP1's derivative
    const user1ConnectedLicensingModule = this.licensingModule.connect(signers[1]);
    const registerDerivativeTx = await expect(
      user1ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [this.nonCommericialLicenseId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0)
    ).not.to.be.rejectedWith(Error);
    await registerDerivativeTx.wait();
    console.log("Register derivative transaction hash: ", registerDerivativeTx.hash);
    expect(registerDerivativeTx.hash).to.not.be.empty.and.to.be.a("HexString");
  });

  it("Register derivative with the license that parent IP doesn’t attached", async function () {
    const mintAndRegisterResp1 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    ipId1 = mintAndRegisterResp1.ipId;
    const mintAndRegisterResp2 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    ipId2 = mintAndRegisterResp2.ipId;
    
    // IP2 is registered as IP1's derivative
    const user1ConnectedLicensingModule= this.licensingModule.connect(signers[1]);
    const registerDerivativeTx = await expect(
      user1ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [this.nonCommericialLicenseId], PILicenseTemplate, hre.ethers.ZeroAddress, 100, 10)
    ).to.be.rejectedWith(`execution reverted`);
  });

  it("IP asset already attached a non-default license and register derivative", async function () {
    const mintAndRegisterResp1 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    ipId1 = mintAndRegisterResp1.ipId;
    const mintAndRegisterResp2 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    ipId2 = mintAndRegisterResp2.ipId;
    
    const user1ConnectedLicensingModule = this.licensingModule.connect(signers[1]);

    // IP2 attach a non-commercial license
    const attachLicenseTx = await expect(
      user1ConnectedLicensingModule.attachLicenseTerms(ipId2, PILicenseTemplate, this.nonCommericialLicenseId)
    ).not.to.be.rejectedWith(Error);
    await attachLicenseTx.wait();
    console.log("Attach license transaction hash: ", attachLicenseTx.hash);
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP2 is registered as IP1's derivative
    const registerDerivativeTx = await expect(
      user1ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [1n], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0)
    ).to.be.rejectedWith(`execution reverted`);
  });

  it("License token holder register derivative with the license token", async function () {
    const mintAndRegisterResp1 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    ipId1 = mintAndRegisterResp1.ipId;
    const mintAndRegisterResp2 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    ipId2 = mintAndRegisterResp2.ipId;
    
    const connectedLicensingModule = this.licensingModule.connect(signers[0]);

    const mintLicenseTokensTx = await expect(
      connectedLicensingModule.mintLicenseTokens(ipId1, PILicenseTemplate, 1n, 2, signers[1].address, hre.ethers.ZeroAddress, 100)
    ).not.to.be.rejectedWith(Error);
    const startLicenseTokenId = await mintLicenseTokensTx.wait().then((receipt:any) => receipt.logs[4].args[6]);
    expect(mintLicenseTokensTx.hash).to.not.be.empty.and.to.be.a("HexString");
    expect(startLicenseTokenId).to.be.a("bigint");
    console.log("Start license token id: ", startLicenseTokenId);

    // registerDerivativeWithLicenseTokens
    const user1ConnectedLicensingModule = this.licensingModule.connect(signers[1]);
    const registerDerivativeTx = await expect(
      user1ConnectedLicensingModule.registerDerivativeWithLicenseTokens(ipId2, [startLicenseTokenId], hre.ethers.ZeroAddress, 10)
    ).not.to.be.rejectedWith(Error);
    await registerDerivativeTx.wait();
    console.log("Register derivative transaction hash: ", registerDerivativeTx.hash);
    expect(registerDerivativeTx.hash).to.not.be.empty.and.to.be.a("HexString");
  });
});
