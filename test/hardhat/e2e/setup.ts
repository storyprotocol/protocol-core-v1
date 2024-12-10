// This file is a root hook used to setup preconditions before running the tests.

import hre from "hardhat";
import { network } from "hardhat";
import { GroupingModule, IPAssetRegistry, LicenseRegistry, LicenseToken, LicensingModule, PILicenseTemplate, RoyaltyPolicyLAP, MockERC20, RoyaltyPolicyLRP, AccessController, RoyaltyModule } from "./constants";
import { terms } from "./licenseTermsTemplate";
import { approveSpender, checkAndApproveSpender, getAllowance, mintAmount } from "./utils/erc20Helper";
import { check } from "prettier";

before(async function () {
  console.log(`================= Load Contract =================`);
  this.ipAssetRegistry = await hre.ethers.getContractAt("IPAssetRegistry", IPAssetRegistry);
  this.licenseRegistry = await hre.ethers.getContractAt("LicenseRegistry", LicenseRegistry);
  this.licenseToken = await hre.ethers.getContractAt("LicenseToken", LicenseToken);
  this.licensingModule = await hre.ethers.getContractAt("LicensingModule", LicensingModule);
  this.groupingModule = await hre.ethers.getContractAt("GroupingModule", GroupingModule);
  this.licenseTemplate = await hre.ethers.getContractAt("PILicenseTemplate", PILicenseTemplate);
  this.accessController = await hre.ethers.getContractAt("AccessController", AccessController);
  this.errors = await hre.ethers.getContractFactory("Errors");
  
  console.log(`================= Load Users =================`);
  [this.owner, this.user1] = await hre.ethers.getSigners();
  
  console.log(`================= Chain ID =================`);
  const networkConfig = network.config;
  this.chainId = networkConfig.chainId;
  console.log("chainId: ", this.chainId);

  console.log(`================= Register non-commercial PIL license terms =================`);
  await this.licenseTemplate.registerLicenseTerms(terms).then((tx : any) => tx.wait());
  this.nonCommericialLicenseId = await this.licenseTemplate.getLicenseTermsId(terms);
  console.log("Non-commercial licenseTermsId: ", this.nonCommericialLicenseId);
  
  console.log(`================= Register commercial-use PIL license terms =================`);
  let testTerms = terms;
  testTerms.royaltyPolicy = RoyaltyPolicyLAP;
  testTerms.defaultMintingFee = 30;
  testTerms.commercialUse = true;
  testTerms.currency = MockERC20;
  await this.licenseTemplate.registerLicenseTerms(testTerms).then((tx : any) => tx.wait());
  this.commericialUseLicenseId = await this.licenseTemplate.getLicenseTermsId(testTerms);
  console.log("Commercial-use licenseTermsId: ", this.commericialUseLicenseId);

  console.log(`================= Register commercial-remix PIL license terms =================`);
  testTerms = terms;
  testTerms.royaltyPolicy = RoyaltyPolicyLRP;
  testTerms.defaultMintingFee = 80;
  testTerms.commercialUse = true;
  testTerms.commercialRevShare = 100;
  testTerms.currency = MockERC20;
  await this.licenseTemplate.registerLicenseTerms(testTerms).then((tx : any) => tx.wait());
  this.commericialRemixLicenseId = await this.licenseTemplate.getLicenseTermsId(testTerms);
  console.log("Commercial-remix licenseTermsId: ", this.commericialRemixLicenseId);

  console.log(`================= ERC20 approve spender =================`);
  const amountToCheck = BigInt(200 * 10 ** 18);
  await checkAndApproveSpender(this.owner, RoyaltyPolicyLAP, amountToCheck);
  await checkAndApproveSpender(this.owner, RoyaltyPolicyLRP, amountToCheck);
  await checkAndApproveSpender(this.owner, RoyaltyModule, amountToCheck);
  await checkAndApproveSpender(this.user1, RoyaltyPolicyLAP, amountToCheck);
  await checkAndApproveSpender(this.user1, RoyaltyPolicyLRP, amountToCheck);
  await checkAndApproveSpender(this.user1, RoyaltyModule, amountToCheck);
});
