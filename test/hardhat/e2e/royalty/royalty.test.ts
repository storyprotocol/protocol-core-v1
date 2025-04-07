// Test: RoyaltyModule - payRoyaltyOnBehalf, transferToVault, claimRevenueOnBehalf

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { MockERC20, PILicenseTemplate, RoyaltyPolicyLAP, RoyaltyPolicyLRP } from "../constants";
import { mintNFTAndRegisterIPA, mintNFTAndRegisterIPAWithLicenseTerms } from "../utils/mintNFTAndRegisterIPA";
import { terms } from "../licenseTermsTemplate";
import { registerPILTerms } from "../utils/licenseHelper";

describe("RoyaltyModule", function () {
  let signers:any;
  let ipId1: any;
  let ipId2: any;
  let ipId3: any;
  let ipId4: any;
  let licenseTermsLAPId: any;
  let licenseTermsLRPId: any;
  let user1ConnectedLicensingModule: any;
  let user2ConnectedLicensingModule: any;
  let user3ConnectedLicensingModule: any;
  let user1ConnectedRoyaltyModule: any;
  let user2ConnectedRoyaltyModule: any;
  let user3ConnectedRoyaltyModule: any;
  let user2ConnectedRoyaltyPolicyLAP: any;
  let user2ConnectedRoyaltyPolicyLRP: any;
  let user3ConnectedRoyaltyPolicyLRP: any;
  const testTerms = terms;

  this.beforeAll("Get Signers and register license terms", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners(); 

    // Register a commercial remix license with royalty policy LAP
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
    user1ConnectedRoyaltyModule = this.royaltyModule.connect(signers[0]); 
    user2ConnectedRoyaltyModule = this.royaltyModule.connect(signers[1]); 
    user3ConnectedRoyaltyModule = this.royaltyModule.connect(signers[2]); 
    user2ConnectedRoyaltyPolicyLAP = this.royaltyPolicyLAP.connect(signers[1]);     
    user2ConnectedRoyaltyPolicyLRP = this.royaltyPolicyLRP.connect(signers[1]);     
    user3ConnectedRoyaltyPolicyLRP = this.royaltyPolicyLRP.connect(signers[2]);     
  });

  it("Transfer LAP related inflows from royalty policy contract", async function () {
    const mintingFee = terms.defaultMintingFee;
    const payAmount = 1000 as number;
    const commercialRevShare = terms.commercialRevShare / 10 ** 6 / 100;

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
      user2ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [licenseTermsLAPId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0, 20 * 10 ** 6)
    ).not.to.be.rejectedWith(Error);
    await registerDerivative1Tx.wait();
    console.log("Register derivative transaction hash: ", registerDerivative1Tx.hash);
    expect(registerDerivative1Tx.hash).to.not.be.empty.and.to.be.a("HexString");
       
    // IP3 is registered as IP2's derivative
    const registerDerivative2Tx = await expect(
      user3ConnectedLicensingModule.registerDerivative(ipId3, [ipId2], [licenseTermsLAPId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0, 20 * 10 ** 6)
    ).not.to.be.rejectedWith(Error);
    await registerDerivative2Tx.wait();
    console.log("Register derivative transaction hash: ", registerDerivative2Tx.hash);
    expect(registerDerivative2Tx.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP3 payRoyaltyOnBehalf to IP2  
    const payRoyaltyOnBehalfTx = await expect(
      user3ConnectedRoyaltyModule.payRoyaltyOnBehalf(ipId2, ipId3, MockERC20, BigInt(payAmount))
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

    const ip2VaultAddress = await user2ConnectedRoyaltyModule.ipRoyaltyVaults(ipId2);
    console.log("IP2's ipVaultAddress: ", ip2VaultAddress);

    const ip2RoyaltyVaultAddress = await hre.ethers.getContractAt("IpRoyaltyVault", ip2VaultAddress);    

    const ip1VaultAddress = await user1ConnectedRoyaltyModule.ipRoyaltyVaults(ipId1);
    console.log("IP1's ipVaultAddress: ", ip1VaultAddress);

    const ip1RoyaltyVaultAddress = await hre.ethers.getContractAt("IpRoyaltyVault", ip1VaultAddress);    

    // check claimable revenue 
    const ip2ClaimableRevenue = await expect(
      ip2RoyaltyVaultAddress.claimableRevenue(ipId2, MockERC20)
    ).not.to.be.rejectedWith(Error);
    console.log("IP2's claimableRevenue: ", ip2ClaimableRevenue);
    expect(ip2ClaimableRevenue).to.be.a("BigInt").and.equal(BigInt((payAmount + mintingFee) * (1 - commercialRevShare)));

    // check claimable revenue 
    const ip1ClaimableRevenue = await expect(
      ip1RoyaltyVaultAddress.claimableRevenue(ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error);
    console.log("IP1's claimableRevenue: ", ip1ClaimableRevenue);
    expect(ip1ClaimableRevenue).to.be.a("BigInt").and.equal(BigInt(mintingFee +(payAmount + mintingFee) * commercialRevShare));

    // claimRevenueOnBehalf 
    const ip2ClaimRevenueOnBehalfTx = await expect(
      ip2RoyaltyVaultAddress.claimRevenueOnBehalf(ipId2, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await ip2ClaimRevenueOnBehalfTx.wait();
    console.log("Claim revenue on behalf transaction hash: ", ip2ClaimRevenueOnBehalfTx.hash);
    expect(ip2ClaimRevenueOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");

    // claimRevenueOnBehalf 
    const ip1ClaimRevenueOnBehalfTx = await expect(
      ip1RoyaltyVaultAddress.claimRevenueOnBehalf(ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await ip1ClaimRevenueOnBehalfTx.wait();
    console.log("Claim revenue on behalf transaction hash: ", ip1ClaimRevenueOnBehalfTx.hash);
    expect(ip1ClaimRevenueOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");
  });

  it("Transfer LRP related inflows from royalty policy contract", async function () {
    const mintingFee = terms.defaultMintingFee;
    console.log("mintingFee: ", mintingFee);

    const payAmount = 1000 as number;
    const commercialRevShare = terms.commercialRevShare / 10 ** 6 / 100;
    console.log("commercialRevShare: ", commercialRevShare);

    const mintAndRegisterResp1 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    ipId1 = mintAndRegisterResp1.ipId;
    const mintAndRegisterResp2 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    ipId2 = mintAndRegisterResp2.ipId;
    const mintAndRegisterResp3 = await mintNFTAndRegisterIPA(signers[2], signers[2]);
    ipId3 = mintAndRegisterResp3.ipId;
    const mintAndRegisterResp4 = await mintNFTAndRegisterIPA(signers[2], signers[2]);
    ipId4 = mintAndRegisterResp4.ipId;

    // IP1 attach the commercial remix license
    const attachLicenseTx = await expect(
      user1ConnectedLicensingModule.attachLicenseTerms(ipId1, PILicenseTemplate, licenseTermsLRPId)
    ).not.to.be.rejectedWith(Error);
    await attachLicenseTx.wait();
    console.log("Attach license transaction hash: ", attachLicenseTx.hash);
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");
       
    // IP2 is registered as IP1's derivative    
    const registerDerivative1Tx = await expect(
      user2ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [licenseTermsLRPId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0, 50 * 10 ** 6)
    ).not.to.be.rejectedWith(Error);
    await registerDerivative1Tx.wait();
    console.log("Register derivative transaction hash: ", registerDerivative1Tx.hash);
    expect(registerDerivative1Tx.hash).to.not.be.empty.and.to.be.a("HexString");
       
    // IP3 is registered as IP2's derivative
    const registerDerivative2Tx = await expect(
      user3ConnectedLicensingModule.registerDerivative(ipId3, [ipId2], [licenseTermsLRPId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0, 50 * 10 ** 6)
    ).not.to.be.rejectedWith(Error);
    await registerDerivative2Tx.wait();
    console.log("Register derivative transaction hash: ", registerDerivative2Tx.hash);
    expect(registerDerivative2Tx.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP4 payRoyaltyOnBehalf to IP3  
    const payRoyaltyOnBehalfTx = await expect(
      user3ConnectedRoyaltyModule.payRoyaltyOnBehalf(ipId3, ipId4, MockERC20, BigInt(payAmount))
    ).not.to.be.rejectedWith(Error);
    await payRoyaltyOnBehalfTx.wait();
    console.log("Pay royalty on behalf transaction hash: ", payRoyaltyOnBehalfTx.hash);
    expect(payRoyaltyOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP3 transferToVault 
    const transferToVaultTx1 = await expect(
      user3ConnectedRoyaltyPolicyLRP.transferToVault(ipId3, ipId2, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await transferToVaultTx1.wait();
    console.log("Transfer to vault transaction hash: ", transferToVaultTx1.hash);
    expect(transferToVaultTx1.hash).to.not.be.empty.and.to.be.a("HexString");

    const transferToVaultTx3 = await expect(
      user3ConnectedRoyaltyPolicyLRP.transferToVault(ipId3, ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await transferToVaultTx3.wait();
    console.log("Transfer to vault transaction hash: ", transferToVaultTx3.hash);
    expect(transferToVaultTx3.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP2 transferToVault 
    const transferToVaultTx2 = await expect(
      user2ConnectedRoyaltyPolicyLRP.transferToVault(ipId2, ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await transferToVaultTx2.wait();
    console.log("Transfer to vault transaction hash: ", transferToVaultTx2.hash);
    expect(transferToVaultTx2.hash).to.not.be.empty.and.to.be.a("HexString");

    const ip3VaultAddress = await user3ConnectedRoyaltyModule.ipRoyaltyVaults(ipId3);
    console.log("IP3's ipVaultAddress: ", ip3VaultAddress);
    const ip3RoyaltyVaultAddress = await hre.ethers.getContractAt("IpRoyaltyVault", ip3VaultAddress);  

    const ip2VaultAddress = await user2ConnectedRoyaltyModule.ipRoyaltyVaults(ipId2);
    console.log("IP2's ipVaultAddress: ", ip2VaultAddress);
    const ip2RoyaltyVaultAddress = await hre.ethers.getContractAt("IpRoyaltyVault", ip2VaultAddress);    

    const ip1VaultAddress = await user1ConnectedRoyaltyModule.ipRoyaltyVaults(ipId1);
    console.log("IP1's ipVaultAddress: ", ip1VaultAddress);
    const ip1RoyaltyVaultAddress = await hre.ethers.getContractAt("IpRoyaltyVault", ip1VaultAddress);    

    // check claimable revenue 
    const ip3ClaimableRevenue = await expect(
      ip3RoyaltyVaultAddress.claimableRevenue(ipId3, MockERC20)
    ).not.to.be.rejectedWith(Error);
    console.log("IP3's claimableRevenue: ", ip3ClaimableRevenue);
    expect(ip3ClaimableRevenue).to.be.a("BigInt").and.equal(BigInt(payAmount * (1 - commercialRevShare)));

    // check claimable revenue 
    const ip2ClaimableRevenue = await expect(
      ip2RoyaltyVaultAddress.claimableRevenue(ipId2, MockERC20)
    ).not.to.be.rejectedWith(Error);
    console.log("IP2's claimableRevenue: ", ip2ClaimableRevenue);
    expect(ip2ClaimableRevenue).to.be.a("BigInt").and.equal(BigInt((mintingFee + payAmount * commercialRevShare) * (1 - commercialRevShare)));

    // check claimable revenue 
    const ip1ClaimableRevenue = await expect(
      ip1RoyaltyVaultAddress.claimableRevenue(ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error);
    console.log("IP1's claimableRevenue: ", ip1ClaimableRevenue);
    expect(ip1ClaimableRevenue).to.be.a("BigInt").and.equal(BigInt(mintingFee + mintingFee * commercialRevShare + payAmount * commercialRevShare ** 2));

    // claimRevenueOnBehalf 
    const ip3ClaimRevenueOnBehalfTx = await expect(
      ip3RoyaltyVaultAddress.claimRevenueOnBehalf(ipId3, MockERC20)
    ).not.to.be.rejectedWith(Error); 
    await ip3ClaimRevenueOnBehalfTx.wait();
    console.log("Claim revenue on behalf transaction hash: ", ip3ClaimRevenueOnBehalfTx.hash);
    expect(ip3ClaimRevenueOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");

    // claimRevenueOnBehalf 
    const ip2ClaimRevenueOnBehalfTx = await expect(
      ip2RoyaltyVaultAddress.claimRevenueOnBehalf(ipId2, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await ip2ClaimRevenueOnBehalfTx.wait();
    console.log("Claim revenue on behalf transaction hash: ", ip2ClaimRevenueOnBehalfTx.hash);
    expect(ip2ClaimRevenueOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");

    // claimRevenueOnBehalf 
    const ip1ClaimRevenueOnBehalfTx = await expect(
      ip1RoyaltyVaultAddress.claimRevenueOnBehalf(ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error);
    await ip1ClaimRevenueOnBehalfTx.wait();
    console.log("Claim revenue on behalf transaction hash: ", ip1ClaimRevenueOnBehalfTx.hash);
    expect(ip1ClaimRevenueOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");
  });

  it("Get claimable revenue tokens", async function () {
    const mintingFee = terms.defaultMintingFee;
    const payAmount = 100 as number;

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
      user2ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [licenseTermsLAPId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 100000000, 50 * 10 ** 6)
    ).not.to.be.rejectedWith(Error);
    await registerDerivative1Tx.wait();
    console.log("Register derivative transaction hash: ", registerDerivative1Tx.hash);
    expect(registerDerivative1Tx.hash).to.not.be.empty.and.to.be.a("HexString");

    // IP2 payRoyaltyOnBehalf to IP1  
    const payRoyaltyOnBehalfTx = await expect(
      user3ConnectedRoyaltyModule.payRoyaltyOnBehalf(ipId1, ipId2, MockERC20, BigInt(payAmount))
    ).not.to.be.rejectedWith(Error);
    await payRoyaltyOnBehalfTx.wait();
    console.log("Pay royalty on behalf transaction hash: ", payRoyaltyOnBehalfTx.hash);
    expect(payRoyaltyOnBehalfTx.hash).to.not.be.empty.and.to.be.a("HexString");

    const ip1VaultAddress = await user1ConnectedRoyaltyModule.ipRoyaltyVaults(ipId1);
    console.log("IP1's ipVaultAddress: ", ip1VaultAddress);
    const ip1RoyaltyVaultAddress = await hre.ethers.getContractAt("IpRoyaltyVault", ip1VaultAddress);  

    // check claimable revenue 
    const ip1ClaimableRevenue = await expect(
      ip1RoyaltyVaultAddress.claimableRevenue(ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error);
    console.log("IP1's claimableRevenue: ", ip1ClaimableRevenue);
    expect(ip1ClaimableRevenue).to.be.a("BigInt").and.equal(BigInt(mintingFee + payAmount));
  });

  it("LAP Transfer of royalties to the same IP account's vault", async function () {
    console.log("============ Register IP1 ============");
    ({ ipId: ipId1 } = await mintNFTAndRegisterIPAWithLicenseTerms(licenseTermsLAPId));
    console.log("IP1: ", ipId1);

    console.log("============ Register IP2 as IP1's derivative ============");
    ({ ipId: ipId2 } = await mintNFTAndRegisterIPA());
    await expect(
      this.licensingModule.registerDerivative(ipId2, [ipId1], [licenseTermsLAPId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    console.log("IP2: ", ipId2);
    
    console.log("============ IP1 Transfer to same IP account's vault ============");
    await expect(
      this.royaltyPolicyLAP.transferToVault(ipId1, ipId1, MockERC20)
    ).to.be.revertedWithCustomError(this.errors, "RoyaltyPolicyLAP__SameIpTransfer");
  });

  it("LRP Transfer of royalties to the same IP account's vault", async function () {
    console.log("============ Register IP1 ============");
    ({ ipId: ipId1 } = await mintNFTAndRegisterIPAWithLicenseTerms(licenseTermsLRPId));
    console.log("IP1: ", ipId1);

    console.log("============ Register IP2 as IP1's derivative ============");
    ({ ipId: ipId2 } = await mintNFTAndRegisterIPA());
    await expect(
      this.licensingModule.registerDerivative(ipId2, [ipId1], [licenseTermsLRPId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    console.log("IP2: ", ipId2);
    
    console.log("============ IP1 Transfer to  same IP account's vault ============");
    await expect(
      this.royaltyPolicyLRP.transferToVault(ipId1, ipId1, MockERC20)
    ).to.be.revertedWithCustomError(this.errors, "RoyaltyPolicyLRP__SameIpTransfer");
  });
});

describe("LAP royalty policy payment over diamond shape", function () {
  const defaultMintingFee = 100;
  const shareRate = 0.01;
  const paidAmount = 10000;
  let ipId1: any, ipId2: any, ipId3: any, ipId4: any, ipId5: any;
  before(async function () {
    console.log("============ Register License Terms ============");
    const licenseTermsLAPId = await registerPILTerms(true, defaultMintingFee, shareRate * 100 * 10 ** 6, RoyaltyPolicyLAP);

    console.log("============ Register IP1 ============");
    ({ ipId: ipId1 } = await mintNFTAndRegisterIPAWithLicenseTerms(licenseTermsLAPId));
    console.log("IP1: ", ipId1);

    console.log("============ Register IP2 as IP1's derivative ============");
    ({ ipId: ipId2 } = await mintNFTAndRegisterIPA());
    await expect(
      this.licensingModule.registerDerivative(ipId2, [ipId1], [licenseTermsLAPId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    console.log("IP2: ", ipId2);

    console.log("============ Register IP3 as IP2's derivative ============");
    ({ ipId: ipId3 } = await mintNFTAndRegisterIPA());
    await expect(
      this.licensingModule.registerDerivative(ipId3, [ipId2], [licenseTermsLAPId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    console.log("IP3: ", ipId3);

    console.log("============ Register IP4 as IP2's derivative ============");
    ({ ipId: ipId4 } = await mintNFTAndRegisterIPA());
    await expect(
      this.licensingModule.registerDerivative(ipId4, [ipId2], [licenseTermsLAPId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    console.log("IP4: ", ipId4);

    console.log("============ Register IP5 as IP3 & IP4's derivative ============");
    ({ ipId: ipId5 } = await mintNFTAndRegisterIPA());
    await expect(
      this.licensingModule.registerDerivative(ipId5, [ipId3, ipId4], [licenseTermsLAPId, licenseTermsLAPId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    console.log("IP5: ", ipId5);

    console.log("============ IP6 Pay royalty on behalf to IP5 ============");
    const { ipId: ipId6 } = await mintNFTAndRegisterIPA(this.user1, this.user1);
    await expect(
      this.royaltyModule.connect(this.user1).payRoyaltyOnBehalf(ipId5, ipId6, MockERC20, paidAmount)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
  });

  it("IP5 check claimable revenue", async function () {
    console.log("============ Check IP5 claimable revenue ============");
    const ip5VaultAddress = await this.royaltyModule.ipRoyaltyVaults(ipId5);
    const ip5RoyaltyVault = await hre.ethers.getContractAt("IpRoyaltyVault", ip5VaultAddress);
    const ip5ClaimableRevenue = await ip5RoyaltyVault.claimableRevenue(ipId5, MockERC20);
    console.log("IP5 claimable revenue: ", ip5ClaimableRevenue);
    expect(ip5ClaimableRevenue).to.be.equal(paidAmount * (1 - shareRate * 6));
  });

  it("IP4 collect claimable revenue", async function () {
    console.log("============ IP4 Transfer to vault ============");
    await expect(
      this.royaltyPolicyLAP.transferToVault(ipId5, ipId4, MockERC20)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log("============ Check IP4 claimable revenue ============");
    const ip4VaultAddress = await this.royaltyModule.ipRoyaltyVaults(ipId4);
    const ip4RoyaltyVault = await hre.ethers.getContractAt("IpRoyaltyVault", ip4VaultAddress);
    const ip4ClaimableRevenue = await ip4RoyaltyVault.claimableRevenue(ipId4, MockERC20);
    console.log("IP4 claimable revenue: ", ip4ClaimableRevenue);
    expect(ip4ClaimableRevenue).to.be.equal(defaultMintingFee * (1 - shareRate * 2) + paidAmount * shareRate);
  });

  it("IP3 collect claimable revenue", async function () {
    console.log("============ IP3 Transfer to vault ============");
    await expect(
      this.royaltyPolicyLAP.transferToVault(ipId5, ipId3, MockERC20)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    
    console.log("============ Check IP3 claimable revenue ============");
    const ip3VaultAddress = await this.royaltyModule.ipRoyaltyVaults(ipId3);
    const ip3RoyaltyVault = await hre.ethers.getContractAt("IpRoyaltyVault", ip3VaultAddress);
    const ip3ClaimableRevenue = await ip3RoyaltyVault.claimableRevenue(ipId3, MockERC20);
    console.log("IP3 claimable revenue: ", ip3ClaimableRevenue);
    expect(ip3ClaimableRevenue).to.be.equal(defaultMintingFee * (1 - shareRate * 2) + paidAmount * shareRate);
  });

  it("IP2 collect claimable revenue", async function () {
    console.log("============ IP2 Transfer to vault ============");
    await expect(
      this.royaltyPolicyLAP.transferToVault(ipId3, ipId2, MockERC20)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    await expect(
      this.royaltyPolicyLAP.transferToVault(ipId4, ipId2, MockERC20)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    await expect(
      this.royaltyPolicyLAP.transferToVault(ipId5, ipId2, MockERC20)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    
    console.log("============ Check IP2 claimable revenue ============");
    const ip2VaultAddress = await this.royaltyModule.ipRoyaltyVaults(ipId2);
    const ip2RoyaltyVault = await hre.ethers.getContractAt("IpRoyaltyVault", ip2VaultAddress);
    const ip2ClaimableRevenue = await ip2RoyaltyVault.claimableRevenue(ipId2, MockERC20);
    console.log("IP2 claimable revenue: ", ip2ClaimableRevenue);
    expect(ip2ClaimableRevenue).to.be.equal(defaultMintingFee * 2 * (1 - shareRate) + paidAmount * shareRate * 2 + defaultMintingFee * shareRate * 2);
  });

  it("IP1 collect claimable revenue", async function () {
    console.log("============ IP1 Transfer to vault ============");
    await expect(
      this.royaltyPolicyLAP.transferToVault(ipId2, ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    await expect(
      this.royaltyPolicyLAP.transferToVault(ipId3, ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    await expect(
      this.royaltyPolicyLAP.transferToVault(ipId4, ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    await expect(
      this.royaltyPolicyLAP.transferToVault(ipId5, ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log("============ Check IP1 claimable revenue ============");
    const ip1VaultAddress = await this.royaltyModule.ipRoyaltyVaults(ipId1);
    const ip1RoyaltyVault = await hre.ethers.getContractAt("IpRoyaltyVault", ip1VaultAddress);
    const ip1ClaimableRevenue = await ip1RoyaltyVault.claimableRevenue(ipId1, MockERC20);
    console.log("IP1 claimable revenue: ", ip1ClaimableRevenue);
    expect(ip1ClaimableRevenue).to.be.equal(defaultMintingFee + paidAmount * shareRate * 2 + defaultMintingFee * shareRate * 4);
  });
});
