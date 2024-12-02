import hre from "hardhat";
import { network } from "hardhat";
import { GroupingModule, IPAssetRegistry, LicenseRegistry, LicenseToken, LicensingModule, PILicenseTemplate, RoyaltyPolicyLAP, MockERC20, RoyaltyPolicyLRP } from "./constants";
import { expect } from "chai";
import { terms } from "./licenseTermsTemplate";

before(async function () {
  console.log(`================= Load Contract =================`);
  this.ipAssetRegistry = await hre.ethers.getContractAt("IPAssetRegistry", IPAssetRegistry);
  this.licenseRegistry = await hre.ethers.getContractAt("LicenseRegistry", LicenseRegistry);
  this.licenseToken = await hre.ethers.getContractAt("LicenseToken", LicenseToken);
  this.licensingModule = await hre.ethers.getContractAt("LicensingModule", LicensingModule);
  this.groupingModule = await hre.ethers.getContractAt("GroupingModule", GroupingModule);
  this.licenseTemplate = await hre.ethers.getContractAt("PILicenseTemplate", PILicenseTemplate);
  
  console.log(`================= Load Users =================`);
  [this.owner, this.user1] = await hre.ethers.getSigners();
  
  console.log(`================= Chain ID =================`);
  const networkConfig = network.config;
  this.chainId = networkConfig.chainId;
  console.log("chainId: ", this.chainId);

  it("Register non-commercial PIL license terms", async function () {
    console.log(`================= Register non-commercial PIL license terms =================`);
    const tx = await expect(
      this.licenseTemplate.registerLicenseTerms(terms)
    ).to.not.be.rejectedWith(Error);
    
    console.log("Transaction hash: ", tx.hash);
    expect(tx.hash).not.to.be.empty.and.to.be.a("HexString");

    this.nonCommericialLicenseId = await this.licenseTemplate.getLicenseTermsId(terms);
    console.log("Non-commercial licenseTermsId: ", this.nonCommericialLicenseId);
  });
  
  it("Register commercial use PIL license terms", async function () {
    console.log(`================= Register commercial-use PIL license terms =================`);
    const testTerms = terms;
    testTerms.royaltyPolicy = RoyaltyPolicyLAP;
    testTerms.defaultMintingFee = 30;
    testTerms.commercialUse = true;
    testTerms.currency = MockERC20;

    const tx = await expect(
      this.licenseTemplate.registerLicenseTerms(testTerms)
    ).to.not.be.rejectedWith(Error);
    
    console.log("Transaction hash: ", tx.hash);
    expect(tx.hash).not.to.be.empty.and.to.be.a("HexString");

    this.commericialUseLicenseId = await this.licenseTemplate.getLicenseTermsId(testTerms);
    console.log("Commercial-use licenseTermsId: ", this.commericialUseLicenseId);
  });
  
  it("Register commercial remix PIL license terms", async function () {
    console.log(`================= Register commercial-remix PIL license terms =================`);
    const testTerms = terms;
    testTerms.royaltyPolicy = RoyaltyPolicyLRP;
    testTerms.defaultMintingFee = 80;
    testTerms.commercialUse = true;
    testTerms.commercialRevShare = 100;
    testTerms.currency = MockERC20;

    const tx = await expect(
      this.licenseTemplate.registerLicenseTerms(testTerms)
    ).to.not.be.rejectedWith(Error);
    
    console.log("Transaction hash: ", tx.hash);
    expect(tx.hash).not.to.be.empty.and.to.be.a("HexString");

    this.commericialRemixLicenseId = await this.licenseTemplate.getLicenseTermsId(testTerms);
    console.log("Commercial-remix licenseTermsId: ", this.commericialRemixLicenseId);
  });
});
