// Test: LicensingModule - registerDerivative, registerDerivativeWithLicenseTokens

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { MockERC20, MockERC721, PILicenseTemplate, RoyaltyPolicyLAP } from "../constants";
import { mintNFTAndRegisterIPA, mintNFTAndRegisterIPAWithLicenseTerms } from "../utils/mintNFTAndRegisterIPA";
import { mintNFT } from "../utils/nftHelper";
import { terms } from "../licenseTermsTemplate";
import { registerPILTerms } from "../utils/licenseHelper";

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

    try {
      const connectedLicensingModule = this.licensingModule.connect(signers[0]);
    
      // IP1 attach a non-commercial license
      const attachLicenseTx = await connectedLicensingModule.attachLicenseTerms(
        ipId1,
        PILicenseTemplate,
        this.nonCommercialLicenseId
      );
    
      await attachLicenseTx.wait();
      console.log("Attach license transaction hash: ", attachLicenseTx.hash);
    
      expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");
    } catch (error) {
      // Extract and log the revert reason
      if (error.data) {
        console.error("📜 Error Data:", error.data);
        // const revertReason = decodeRevertReason(error.data);
        // console.error("🔴 Revert Reason:", revertReason);
      }
     else {
        console.error("Transaction failed, but no revert reason found.");
      }
      throw error;
    }
       
    // IP2 is registered as IP1's derivative
    const user1ConnectedLicensingModule = this.licensingModule.connect(signers[1]);
    const registerDerivativeTx = await expect(
      user1ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [this.nonCommercialLicenseId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0, 50 * 10 ** 6)
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
      user1ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [this.nonCommercialLicenseId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 10, 50 * 10 ** 6)
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
      user1ConnectedLicensingModule.attachLicenseTerms(ipId2, PILicenseTemplate, this.nonCommercialLicenseId)
    ).not.to.be.rejectedWith(Error);
    await attachLicenseTx.wait();
    console.log("Attach license transaction hash: ", attachLicenseTx.hash);
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP2 is registered as IP1's derivative
    const registerDerivativeTx = await expect(
      user1ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [1n], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0, 50 * 10 ** 6)
    ).to.be.rejectedWith(`execution reverted`);
  });

  it("License token holder register derivative with the license token", async function () {
    const mintAndRegisterResp1 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    ipId1 = mintAndRegisterResp1.ipId;
    const mintAndRegisterResp2 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    ipId2 = mintAndRegisterResp2.ipId;
    
    const connectedLicensingModule = this.licensingModule.connect(signers[0]);

    const mintLicenseTokensTx = await expect(
      connectedLicensingModule.mintLicenseTokens(ipId1, PILicenseTemplate, 1n, 2, signers[1].address, hre.ethers.ZeroAddress, 0, 50 * 10 ** 6)
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

  it("Verify IP Graph precompiles register derivative error: RoyaltyModule__AboveParentLimit", async function () {
    const count = 17;

    const mint: Promise<number>[] = [];
    let nonce = await hre.ethers.provider.getTransactionCount(this.owner.address);
    console.log("Nonce: ", nonce);
    for (let i = 0; i < count; i++) {
      mint.push(
        mintNFT(this.owner, this.owner.address, nonce++)
      );
    }
    const tokenIds = await Promise.all(mint);

    const registerIps: Promise<number>[] = [];
    for (let i = 0; i < count; i++) {
      registerIps.push(
        this.ipAssetRegistry.register(this.chainId, MockERC721, tokenIds[i], { nonce: nonce++ }).then((tx: any) => tx.wait()).then((receipt: any) => receipt.logs[2].args[0])
      );
    }
    const parentIpIds = (await Promise.all(registerIps));

    const licenseTermsIds: number[] = [];
    const attachLicenseTerms: Promise<void>[] = [];
    for (let i = 0; i < count; i++) {
      attachLicenseTerms.push(
        this.licensingModule.attachLicenseTerms(parentIpIds[i], PILicenseTemplate, this.commericialRemixLicenseId, { nonce: nonce++ })
      );
      licenseTermsIds.push(this.commericialRemixLicenseId);
    }

    console.log("Parent IP Ids: ", parentIpIds);
    console.log("License Terms Ids: ", licenseTermsIds);

    const { ipId: childIpId } = await mintNFTAndRegisterIPA(this.user1, this.user1);
    await expect(
      this.licensingModule.connect(this.user1).registerDerivative(childIpId, parentIpIds, licenseTermsIds, PILicenseTemplate, "0x", 0, 100e6, 0)
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__TooManyParents");
  });

  it("Derivative IP asset should not attached license itself", async function () {
    const { ipId: parentIpId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialRemixLicenseId);
    const { ipId: childIpId } = await mintNFTAndRegisterIPA(this.user1, this.user1);

    console.log("============ Register derivative ============")
    await expect(
      this.licensingModule.connect(this.user1).registerDerivative(childIpId, [parentIpId], [this.commericialRemixLicenseId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log("============ Attach license to derivative ============")
    await expect(
      this.licensingModule.connect(this.user1).attachLicenseTerms(childIpId, PILicenseTemplate, this.commercialUseLicenseId)
    ).to.be.revertedWithCustomError(this.errors, "LicensingModule__DerivativesCannotAddLicenseTerms");
  });

  it("Register derivative with an incorrect license token", async function () {
    const { ipId: parentIpId1 } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialRemixLicenseId);
    const { ipId: parentIpId2 } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commercialUseLicenseId);
    const { ipId: childIpId } = await mintNFTAndRegisterIPA(this.user1, this.user1);

    console.log("============ Register derivative ============")
    await expect(
      this.licensingModule.connect(this.user1).registerDerivative(childIpId, [parentIpId1, parentIpId2], [this.commericialRemixLicenseId, this.commericialRemixLicenseId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__ParentIpHasNoLicenseTerms");
  });

  it("Register derivatives chain with Royalty LAP policy, revenue share > 100%", async function () {
    const testTerms = { ...terms };
    testTerms.commercialUse = true;
    testTerms.commercialRevShare = 33.4 * 10 ** 6;
    testTerms.royaltyPolicy = RoyaltyPolicyLAP;
    testTerms.derivativesReciprocal = true;
    testTerms.currency = MockERC20;

    console.log("============ Register license terms ============")
    await expect(
      this.licenseTemplate.registerLicenseTerms(testTerms)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    const commRemixTermsId = await this.licenseTemplate.getLicenseTermsId(testTerms);
    console.log("Commercial-remix licenseTermsId: ", commRemixTermsId);

    console.log("============ Register root IP ============")
    const { ipId: rootIpId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);

    console.log("============ Register derivative from root ============")
    const { ipId: childIpId1 } = await mintNFTAndRegisterIPA();
    await expect(
      this.licensingModule.registerDerivative(childIpId1, [rootIpId], [commRemixTermsId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log("============ Register derivative from child 1 ============")
    const { ipId: childIpId2 } = await mintNFTAndRegisterIPA();
    await expect(
      this.licensingModule.registerDerivative(childIpId2, [childIpId1], [commRemixTermsId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log("============ Register derivative from child 2 ============")
    const { ipId: childIpId3 } = await mintNFTAndRegisterIPA();
    await expect(
      this.licensingModule.registerDerivative(childIpId3, [childIpId2], [commRemixTermsId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).to.be.revertedWithCustomError(this.errors, "RoyaltyPolicyLAP__AboveMaxPercent");
  });

  it("Derivative IP Asset attach incompatible licenses", async function () {
    console.log("============ Register IPs ============")
    const { ipId: parentIpId1 } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialRemixLicenseId);
    const { ipId: parentIpId2 } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commercialUseLicenseId);
    const { ipId: childIpId } = await mintNFTAndRegisterIPA(this.user1, this.user1);

    console.log("============ Register derivative ============")
    await expect(
      this.licensingModule.connect(this.user1).registerDerivative(childIpId, [parentIpId1, parentIpId2], [this.commericialRemixLicenseId, this.commercialUseLicenseId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).to.be.revertedWithCustomError(this.errors, "LicensingModule__RoyaltyPolicyMismatch");
  });

  it("Derivative IP Asset attach compatible licenses", async function () {
    console.log("============ Register License Terms ============")
    const commRemixTermsId1 = await registerPILTerms(true, 100, 10 * 10 ** 6, RoyaltyPolicyLAP, 0, MockERC20, false);
    console.log("Commercial-remix licenseTermsId1: ", commRemixTermsId1);
    const commRemixTermsId2 = await registerPILTerms(true, 50, 15 * 10 ** 6, RoyaltyPolicyLAP, 0, MockERC20, false);
    console.log("Commercial-remix licenseTermsId2: ", commRemixTermsId2);

    console.log("============ Register IPs ============")
    const { ipId: parentIpId1 } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId1);
    const { ipId: parentIpId2 } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId2);
    const { ipId: childIpId } = await mintNFTAndRegisterIPA(this.user1, this.user1);

    console.log("============ Register derivative ============")
    await expect(
      this.licensingModule.connect(this.user1).registerDerivative(childIpId, [parentIpId1, parentIpId2], [commRemixTermsId1, commRemixTermsId2], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    const count = await this.licenseRegistry.getParentIpCount(childIpId);
    console.log("Parent IP count: ", count);
    expect(count).to.equal(2);
  });
});
