// This file is a root hook used to setup preconditions before running the tests.

import hre from "hardhat";
import { network } from "hardhat";
import { GroupingModule, IPAssetRegistry, LicenseRegistry, LicenseToken, LicensingModule, PILicenseTemplate, RoyaltyPolicyLAP, MockERC20, RoyaltyPolicyLRP, AccessController, RoyaltyModule, EvenSplitGroupPool, IpRoyaltyVaultImpl, DisputeModule, ArbitrationPolicyUMA, CoreMetadataModule, CoreMetadataViewModule, STORY_OOV3 } from "./constants";
import { terms } from "./licenseTermsTemplate";
import { checkAndApproveSpender } from "./utils/erc20Helper";

before(async function () {
  // Get the list of signers, the first signer is usually the default wallet
  const [defaultSigner] = await hre.ethers.getSigners();

  // Log the default signer address to confirm it's correct
  console.log(`Default signer address: ${defaultSigner.address}`);

  // Use the default signer to get the contract instances
  this.ipAssetRegistry = await hre.ethers.getContractAt("IPAssetRegistry", IPAssetRegistry);
  this.licenseRegistry = await hre.ethers.getContractAt("LicenseRegistry", LicenseRegistry);
  this.licenseToken = await hre.ethers.getContractAt("LicenseToken", LicenseToken);
  this.licensingModule = await hre.ethers.getContractAt("LicensingModule", LicensingModule);
  this.groupingModule = await hre.ethers.getContractAt("GroupingModule", GroupingModule);
  this.licenseTemplate = await hre.ethers.getContractAt("PILicenseTemplate", PILicenseTemplate);
  this.accessController = await hre.ethers.getContractAt("AccessController", AccessController);
  this.royaltyModule = await hre.ethers.getContractAt("RoyaltyModule", RoyaltyModule);
  this.royaltyPolicyLAP = await hre.ethers.getContractAt("RoyaltyPolicyLAP", RoyaltyPolicyLAP);
  this.royaltyPolicyLRP = await hre.ethers.getContractAt("RoyaltyPolicyLRP", RoyaltyPolicyLRP);
  this.ipRoyaltyVaultImpl = await hre.ethers.getContractAt("IpRoyaltyVault", IpRoyaltyVaultImpl);
  this.evenSplitGroupPool = await hre.ethers.getContractAt("EvenSplitGroupPool", EvenSplitGroupPool);
  this.disputeModule = await hre.ethers.getContractAt("DisputeModule", DisputeModule);
  this.arbitrationPolicyUMA = await hre.ethers.getContractAt("ArbitrationPolicyUMA", ArbitrationPolicyUMA);
  this.coreMetadataModule = await hre.ethers.getContractAt("CoreMetadataModule", CoreMetadataModule);
  this.CoreMetadataViewModule = await hre.ethers.getContractAt("CoreMetadataViewModule", CoreMetadataViewModule);
  this.errors = await hre.ethers.getContractFactory("contracts/lib/Errors.sol:Errors");
  
  console.log(`================= Load Users =================`);
  [this.owner, this.user1, this.user2] = await hre.ethers.getSigners();
  await this.owner.sendTransaction({ to: this.user1.address, value: hre.ethers.parseEther("100.0") }).then((tx: any) => tx.wait());
  await this.owner.sendTransaction({ to: this.user2.address, value: hre.ethers.parseEther("100.0") }).then((tx: any) => tx.wait());
  
  console.log(`================= Chain ID =================`);
  const networkConfig = network.config;
  this.chainId = networkConfig.chainId;
  console.log("chainId: ", this.chainId);

  console.log(`================= Whitelist Royalty Token =================`);
  try {
    await this.royaltyModule.whitelistRoyaltyToken(MockERC20, true).then((tx : any) => tx.wait());
    console.log(`✅ whitelistRoyaltyToken successfully! `)
  } catch (error: any) {
    console.log(error);
    console.error("❌ Transaction Reverted!");
    console.error("🔴 Error Message:", error.message || "No error message");
    console.error("📜 Error Data:", error.data || "No error data");
  }

  console.log(`================= Register non-commercial PIL license terms =================`);
  await this.licenseTemplate.registerLicenseTerms(terms).then((tx : any) => tx.wait());
  this.nonCommercialLicenseId = await this.licenseTemplate.getLicenseTermsId(terms);
  console.log("Non-commercial licenseTermsId: ", this.nonCommercialLicenseId);
  
  console.log(`================= Register commercial-use PIL license terms =================`);
  let testTerms = terms;

  testTerms.royaltyPolicy = RoyaltyPolicyLAP;
  testTerms.defaultMintingFee = 30;
  testTerms.commercialUse = true;
  testTerms.currency = MockERC20;

  console.log("Registering License Terms...");
  
  try {
    const tx = await this.licenseTemplate.registerLicenseTerms(testTerms);
    await tx.wait();
    const receipt = await tx.wait();
  
    console.log("Transaction Success: ", receipt);
  } catch (error: any) {
    console.error("❌ Transaction Reverted!");
    console.error("🔴 Error Message:", error.message || "No error message");
    console.error("📜 Error Data:", error.data || "No error data");
  
    if (error.transactionHash) {
      console.log("🔍 Check Transaction on Explorer:", `https://devnet.storyscan.xyz/tx/${error.transactionHash}`);
    }
  }
  
  this.commercialUseLicenseId = await this.licenseTemplate.getLicenseTermsId(testTerms);
  console.log("Commercial-use licenseTermsId: ", this.commercialUseLicenseId);

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
  const amountToCheck = BigInt(1 * 10 ** 18);
  await checkAndApproveSpender(this.owner, RoyaltyPolicyLAP, amountToCheck);
  await checkAndApproveSpender(this.owner, RoyaltyPolicyLRP, amountToCheck);
  await checkAndApproveSpender(this.owner, RoyaltyModule, amountToCheck);
  await checkAndApproveSpender(this.user1, RoyaltyPolicyLAP, amountToCheck);
  await checkAndApproveSpender(this.user1, RoyaltyPolicyLRP, amountToCheck);
  await checkAndApproveSpender(this.user1, RoyaltyModule, amountToCheck);
  await checkAndApproveSpender(this.user1, ArbitrationPolicyUMA, amountToCheck);
  await checkAndApproveSpender(this.user2, RoyaltyPolicyLAP, amountToCheck);
  await checkAndApproveSpender(this.user2, RoyaltyPolicyLRP, amountToCheck);
  await checkAndApproveSpender(this.user2, RoyaltyModule, amountToCheck);

  if (STORY_OOV3) {
    console.log(`================= Set UMA =================`)
    console.log(`================= STORY_OOV3: ${STORY_OOV3} =================`)

    try {
      await this.arbitrationPolicyUMA.setOOV3(STORY_OOV3).then((tx: any) => tx.wait())
      console.log(`✅ setOOV3 successfully! `)
      
    } catch (error: any) {
      console.log(error);
      console.error("❌ Transaction Reverted!");
      console.error("🔴 Error Message:", error.message || "No error message");
      console.error("📜 Error Data:", error.data || "No error data");
    }

    try {
      console.log(`ArbitrationPolicyUMA: ${ArbitrationPolicyUMA}`);
      console.log(`this.owner.address: ${this.owner.address}`);
      
      await this.disputeModule
        .setArbitrationRelayer(ArbitrationPolicyUMA, this.owner.address)
        .then((tx: any) => tx.wait())
      console.log(`✅ setArbitrationRelayer successfully! `)
      
      await this.arbitrationPolicyUMA.setMaxBond(MockERC20, hre.ethers.parseEther("1.0")).then((tx: any) => tx.wait())
      
      console.log(`✅ setMaxBond successfully! `)

    } catch (error: any) {
      console.log(error);
      console.error("❌ Transaction Reverted!");
      console.error("🔴 Error Message:", error.message || "No error message");
      console.error("📜 Error Data:", error.data || "No error data");
    }
  }
  
});
