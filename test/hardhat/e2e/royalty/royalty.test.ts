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

    // Register a commericial remix license with royalty policy LAP
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
    expect(ip2ClaimableRevenue).to.be.a("BigInt").and.equal(BigInt(mintingFee * (1 - commercialRevShare) + payAmount * commercialRevShare));

    // check claimable revenue 
    const ip1ClaimableRevenue = await expect(
      ip1RoyaltyVaultAddress.claimableRevenue(ipId1, MockERC20)
    ).not.to.be.rejectedWith(Error);
    console.log("IP1's claimableRevenue: ", ip1ClaimableRevenue);
    expect(ip1ClaimableRevenue).to.be.a("BigInt").and.equal(BigInt(mintingFee + mintingFee * commercialRevShare));

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
      user2ConnectedLicensingModule.registerDerivative(ipId2, [ipId1], [licenseTermsLAPId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 100000000)
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
});
