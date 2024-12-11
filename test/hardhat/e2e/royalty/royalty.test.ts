// Test: RoyaltyModule - payRoyaltyOnBehalf, transferToVault, claimRevenueOnBehalf

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { MockERC20, PILicenseTemplate, RoyaltyPolicyLAP, RoyaltyPolicyLRP } from "../constants";
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";
import { terms } from "../licenseTermsTemplate";

describe("RoyaltyModule", function () {
  let signers:any;
  let ipId1: any;
  let ipId2: any;
  let ipId3: any;
  let licenseTermsLAPId: any;
  let licenseTermsLRPId: any;
  let user1ConnectedLicensingModule: any;
  let user2ConnectedLicensingModule: any;
  let user3ConnectedLicensingModule: any;
  let user1ConnectedIpRoyaltyVaultImpl: any;
  let user2ConnectedIpRoyaltyVaultImpl: any;
  let user3ConnectedRoyaltyModule: any;
  let user2ConnectedRoyaltyPolicyLAP: any;
  let user1ConnectedRoyaltyPolicyLAP: any;

  this.beforeAll("Get Signers", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners(); 

    // Register a commericial remix license with royalty policy LAP
    const testTerms = terms;
    testTerms.royaltyPolicy = RoyaltyPolicyLAP;
    testTerms.defaultMintingFee = 100;
    testTerms.commercialUse = true;
    testTerms.derivativesReciprocal = true;
    testTerms.commercialRevShare = 10 * 10 ** 6;
    testTerms.currency = MockERC20;

    const connectedLicense = this.licenseTemplate.connect(signers[0]);
    const registerLicenseLAPTx = await expect(
        connectedLicense.registerLicenseTerms(testTerms)
    ).to.not.be.rejectedWith(Error);
    await registerLicenseLAPTx.wait();
    
    console.log("Transaction hash: ", registerLicenseLAPTx.hash);
    expect(registerLicenseLAPTx.hash).not.to.be.empty.and.to.be.a("HexString");

    licenseTermsLAPId = await connectedLicense.getLicenseTermsId(terms);
    console.log("licenseTermsLAPId: ", licenseTermsLAPId);

    testTerms.royaltyPolicy = RoyaltyPolicyLRP;
    const registerLicenseLRPTx = await expect(
        connectedLicense.registerLicenseTerms(testTerms)
    ).to.not.be.rejectedWith(Error);
    await registerLicenseLRPTx.wait();
    
    console.log("Transaction hash: ", registerLicenseLRPTx.hash);
    expect(registerLicenseLRPTx.hash).not.to.be.empty.and.to.be.a("HexString");

    licenseTermsLRPId = await connectedLicense.getLicenseTermsId(terms);
    console.log("licenseTermsLRPId: ", licenseTermsLRPId);    

    user1ConnectedLicensingModule = this.licensingModule.connect(signers[0]); 
    user2ConnectedLicensingModule = this.licensingModule.connect(signers[1]);
    user3ConnectedLicensingModule = this.licensingModule.connect(signers[2]);
    user1ConnectedIpRoyaltyVaultImpl = this.ipRoyaltyVaultImpl.connect(signers[0]); 
    user2ConnectedIpRoyaltyVaultImpl = this.ipRoyaltyVaultImpl.connect(signers[1]); 
    user3ConnectedRoyaltyModule = this.royaltyModule.connect(signers[2]); 
    user2ConnectedRoyaltyPolicyLAP = this.royaltyPolicyLAP.connect(signers[1]); 
    user1ConnectedRoyaltyPolicyLAP = this.royaltyPolicyLAP.connect(signers[0]); 
  });

  it("Transfer LAP related inflows from royalty policy contract", async function () {
    const mintAndRegisterResp1 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    ipId1 = mintAndRegisterResp1.ipId;
    const mintAndRegisterResp2 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    ipId2 = mintAndRegisterResp2.ipId;
    const mintAndRegisterResp3 = await mintNFTAndRegisterIPA(signers[2], signers[2]);
    ipId3 = mintAndRegisterResp3.ipId;

    // IP1 attach the commercial remix license
    const attachLicenseTx = await expect(
      user1ConnectedLicensingModule.attachLicenseTerms(ipId1, PILicenseTemplate, licenseTermsLAPId)
    ).not.to.be.rejectedWith(Error);
    await attachLicenseTx.wait();
    console.log("Attach license transaction hash: ", attachLicenseTx.hash);
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");
       
    // IP2 is registered as IP1's derivative    
    const registerDerivative1Tx = await expect(
      user2ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [licenseTermsLAPId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0)
    ).not.to.be.rejectedWith(Error);
    await registerDerivative1Tx.wait();
    console.log("Register derivative transaction hash: ", registerDerivative1Tx.hash);
    expect(registerDerivative1Tx.hash).to.not.be.empty.and.to.be.a("HexString");
       
    // IP3 is registered as IP2's derivative
    const registerDerivative2Tx = await expect(
      user3ConnectedLicensingModule.registerDerivative(ipId3, [ipId2], [licenseTermsLAPId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0)
    ).not.to.be.rejectedWith(Error);
    await registerDerivative2Tx.wait();
    console.log("Register derivative transaction hash: ", registerDerivative2Tx.hash);
    expect(registerDerivative2Tx.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP3 payRoyaltyOnBehalf to IP2  
    const payRoyaltyOnBehalfTx = await expect(
      user3ConnectedRoyaltyModule.payRoyaltyOnBehalf(ipId2, ipId3, MockERC20, 1000n)
    ).not.to.be.rejectedWith(Error);
    await payRoyaltyOnBehalfTx.wait();
    console.log("Pay royalty on behalf transaction hash: ", payRoyaltyOnBehalfTx.hash);
    expect(payRoyaltyOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP2 transferToVault 
    const transferToVaultTx1 = await expect(
      user2ConnectedRoyaltyPolicyLAP.transferToVault(ipId2, ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await transferToVaultTx1.wait();
    console.log("Transfer to vault transaction hash: ", transferToVaultTx1.hash);
    expect(transferToVaultTx1.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP1 transferToVault 
    const transferToVaultTx2 = await expect(
      user1ConnectedRoyaltyPolicyLAP.transferToVault(ipId1, ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await transferToVaultTx2.wait();
    console.log("Transfer to vault transaction hash: ", transferToVaultTx2.hash);
    expect(transferToVaultTx2.hash).to.not.be.empty.and.to.be.a("HexString");

    // claimRevenueOnBehalf 
    const claimRevenueOnBehalfTx = await expect(
      user2ConnectedIpRoyaltyVaultImpl.claimRevenueOnBehalf(signers[1].address, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await claimRevenueOnBehalfTx.wait();
    console.log("Claim revenue on behalf transaction hash: ", claimRevenueOnBehalfTx.hash);
    expect(claimRevenueOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");

    // claimRevenueOnBehalf
    const user1ClaimRevenueOnBehalfTx = await expect(
      user1ConnectedIpRoyaltyVaultImpl.claimRevenueOnBehalf(signers[0].address, MockERC20)
      ).not.to.be.rejectedWith(Error);
    await user1ClaimRevenueOnBehalfTx.wait();
    console.log("Claim revenue on behalf transaction hash: ", user1ClaimRevenueOnBehalfTx.hash);
    expect(user1ClaimRevenueOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");
  });

  it("Transfer LRP related inflows from royalty policy contract", async function () {
    const mintAndRegisterResp1 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    ipId1 = mintAndRegisterResp1.ipId;
    const mintAndRegisterResp2 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    ipId2 = mintAndRegisterResp2.ipId;
    const mintAndRegisterResp3 = await mintNFTAndRegisterIPA(signers[2], signers[2]);
    ipId3 = mintAndRegisterResp3.ipId;

    // IP1 attach the commercial remix license
    const attachLicenseTx = await expect(
      user1ConnectedLicensingModule.attachLicenseTerms(ipId1, PILicenseTemplate, licenseTermsLRPId)
    ).not.to.be.rejectedWith(Error);
    await attachLicenseTx.wait();
    console.log("Attach license transaction hash: ", attachLicenseTx.hash);
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");
       
    // IP2 is registered as IP1's derivative    
    const registerDerivative1Tx = await expect(
      user2ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [licenseTermsLRPId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0)
    ).not.to.be.rejectedWith(Error);
    await registerDerivative1Tx.wait();
    console.log("Register derivative transaction hash: ", registerDerivative1Tx.hash);
    expect(registerDerivative1Tx.hash).to.not.be.empty.and.to.be.a("HexString");
       
    // IP3 is registered as IP2's derivative
    const registerDerivative2Tx = await expect(
      user3ConnectedLicensingModule.registerDerivative(ipId3, [ipId2], [licenseTermsLRPId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0)
    ).not.to.be.rejectedWith(Error);
    await registerDerivative2Tx.wait();
    console.log("Register derivative transaction hash: ", registerDerivative2Tx.hash);
    expect(registerDerivative2Tx.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP3 payRoyaltyOnBehalf to IP2  
    const payRoyaltyOnBehalfTx = await expect(
      user3ConnectedRoyaltyModule.payRoyaltyOnBehalf(ipId2, ipId3, MockERC20, 1000n)
    ).not.to.be.rejectedWith(Error);
    await payRoyaltyOnBehalfTx.wait();
    console.log("Pay royalty on behalf transaction hash: ", payRoyaltyOnBehalfTx.hash);
    expect(payRoyaltyOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP2 transferToVault 
    const transferToVaultTx1 = await expect(
      user2ConnectedRoyaltyPolicyLAP.transferToVault(ipId2, ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await transferToVaultTx1.wait();
    console.log("Transfer to vault transaction hash: ", transferToVaultTx1.hash);
    expect(transferToVaultTx1.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP1 transferToVault 
    const transferToVaultTx2 = await expect(
      user1ConnectedRoyaltyPolicyLAP.transferToVault(ipId1, ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await transferToVaultTx2.wait();
    console.log("Transfer to vault transaction hash: ", transferToVaultTx2.hash);
    expect(transferToVaultTx2.hash).to.not.be.empty.and.to.be.a("HexString");

    // claimRevenueOnBehalf 
    const claimRevenueOnBehalfTx = await expect(
      user2ConnectedIpRoyaltyVaultImpl.claimRevenueOnBehalf(signers[1].address, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await claimRevenueOnBehalfTx.wait();
    console.log("Claim revenue on behalf transaction hash: ", claimRevenueOnBehalfTx.hash);
    expect(claimRevenueOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");

    // claimRevenueOnBehalf
    const user1ClaimRevenueOnBehalfTx = await expect(
      user1ConnectedIpRoyaltyVaultImpl.claimRevenueOnBehalf(signers[0].address, MockERC20)
      ).not.to.be.rejectedWith(Error);
    await user1ClaimRevenueOnBehalfTx.wait();
    console.log("Claim revenue on behalf transaction hash: ", user1ClaimRevenueOnBehalfTx.hash);
    expect(user1ClaimRevenueOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");
  });

  it("Get claimable revenue tokens", async function () {
    const mintAndRegisterResp1 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    ipId1 = mintAndRegisterResp1.ipId;
    const mintAndRegisterResp2 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    ipId2 = mintAndRegisterResp2.ipId;

    // IP1 attach the commercial remix license
    const attachLicenseTx = await expect(
      user1ConnectedLicensingModule.attachLicenseTerms(ipId1, PILicenseTemplate, licenseTermsLAPId)
    ).not.to.be.rejectedWith(Error);
    await attachLicenseTx.wait();
    console.log("Attach license transaction hash: ", attachLicenseTx.hash);
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");
       
    // IP2 is registered as IP1's derivative    
    const registerDerivative1Tx = await expect(
      user2ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [licenseTermsLAPId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 100000000)
    ).not.to.be.rejectedWith(Error);
    await registerDerivative1Tx.wait();
    console.log("Register derivative transaction hash: ", registerDerivative1Tx.hash);
    expect(registerDerivative1Tx.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP2 payRoyaltyOnBehalf to IP1  
    const payRoyaltyOnBehalfTx = await expect(
      user3ConnectedRoyaltyModule.payRoyaltyOnBehalf(ipId1, ipId2, MockERC20, 1000n)
    ).not.to.be.rejectedWith(Error);
    await payRoyaltyOnBehalfTx.wait();
    console.log("Pay royalty on behalf transaction hash: ", payRoyaltyOnBehalfTx.hash);
    expect(payRoyaltyOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");

    // claimableRevenue 
    const claimRevenueOnBehalfTx = await expect(
      user2ConnectedIpRoyaltyVaultImpl.claimableRevenue(signers[1].address, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await claimRevenueOnBehalfTx.wait();
    console.log("Claim revenue on behalf transaction hash: ", claimRevenueOnBehalfTx.hash);
    expect(claimRevenueOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");
  });
});
