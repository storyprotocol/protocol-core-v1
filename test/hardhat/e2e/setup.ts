// This file is a root hook used to setup preconditions before running the tests.

import hre from "hardhat";
import { network } from "hardhat";
import { GroupingModule, IPAssetRegistry, LicenseRegistry, LicenseToken, LicensingModule, PILicenseTemplate, RoyaltyPolicyLAP, MockERC20, RoyaltyPolicyLRP, AccessController, RoyaltyModule, EvenSplitGroupPool, IpRoyaltyVaultImpl, DisputeModule, ArbitrationPolicyUMA, CoreMetadataModule, CoreMetadataViewModule, STORY_OOV3 } from "./constants";
import { terms } from "./licenseTermsTemplate";
import { checkAndApproveSpender } from "./utils/erc20Helper";
import "@nomicfoundation/hardhat-chai-matchers";

// Constants
const MIN_BALANCE_ETH = "10.0";
const APPROVAL_AMOUNT = BigInt(1 * 10 ** 18);

// Logging utilities
const logSection = (title: string) => console.log(`\n${'='.repeat(20)} ${title} ${'='.repeat(20)}`);
const logSuccess = (message: string) => console.log(`✅ ${message}`);
const logInfo = (message: string) => console.log(`ℹ️  ${message}`);
const logWarning = (message: string) => console.log(`⚠️  ${message}`);

// Error handling utility
const handleTransactionError = (error: any, context: string) => {
  if (error.data && error.data.includes("0x068ca9d8")) {
    console.error("Transaction Reverted!");
    console.error("💡 Known Issue: AccessManagedUnauthorized - Multi-signer account lacks required permissions");
    console.error(`🔧 Solution: Ensure the account has proper access control permissions for ${context}`);
  } else {
    console.error("Transaction Reverted!");
    console.error("🔴 Error Message:", error.message || "No error message");
    console.error("📜 Error Data:", error.data || "No error data");
    if (error.transactionHash) {
      console.log("🔍 Check Transaction on Explorer:", `https://devnet.storyscan.xyz/tx/${error.transactionHash}`);
    }
  }
};

// Balance check and transfer utility
const ensureUserBalance = async (owner: any, user: any, userLabel: string) => {
  const minBalance = hre.ethers.parseEther(MIN_BALANCE_ETH);
  const userBalance = await hre.ethers.provider.getBalance(user.address);
  
  if (userBalance < minBalance) {
    logInfo(`${userLabel} balance (${hre.ethers.formatEther(userBalance)} ETH) is below ${MIN_BALANCE_ETH} ETH, transferring funds...`);
    await owner.sendTransaction({ to: user.address, value: minBalance }).then((tx: any) => tx.wait());
    logSuccess(`Transferred ${MIN_BALANCE_ETH} ETH to ${userLabel}`);
  } else {
    logInfo(`${userLabel} balance (${hre.ethers.formatEther(userBalance)} ETH) is sufficient`);
  }
};

before(async function () {
  // Initialize contracts
  logSection("Initializing Contracts");
  const [defaultSigner] = await hre.ethers.getSigners();
  logInfo(`Default signer: ${defaultSigner.address}`);

  // Contract instances
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
  logSuccess("All contracts initialized");

  // Setup users and balances
  logSection("User Setup");
  [this.owner, this.user1, this.user2] = await hre.ethers.getSigners();
  
  await ensureUserBalance(this.owner, this.user1, "User1");
  await ensureUserBalance(this.owner, this.user2, "User2");

  // Network configuration
  logSection("Network Configuration");
  const networkConfig = network.config;
  this.chainId = networkConfig.chainId;
  logInfo(`Chain ID: ${this.chainId}`);

  // Royalty token whitelist
  logSection("Royalty Token Setup");
  try {
    await this.royaltyModule.whitelistRoyaltyToken(MockERC20, true).then((tx: any) => tx.wait());
    logSuccess("Royalty token whitelisted successfully");
  } catch (error: any) {
    handleTransactionError(error, "RoyaltyModule");
  }

  // License terms registration
  logSection("License Terms Registration");
  
  // Non-commercial license
  try {
    await this.licenseTemplate.registerLicenseTerms(terms).then((tx: any) => tx.wait());
    this.nonCommercialLicenseId = await this.licenseTemplate.getLicenseTermsId(terms);
    logSuccess(`Non-commercial license registered: ${this.nonCommercialLicenseId}`);
  } catch (error: any) {
    handleTransactionError(error, "LicenseTemplate");
  }

  // Commercial-use license
  try {
    const commercialTerms = {
      ...terms,
      royaltyPolicy: RoyaltyPolicyLAP,
      defaultMintingFee: 30,
      commercialUse: true,
      currency: MockERC20
    };
    
    await this.licenseTemplate.registerLicenseTerms(commercialTerms).then((tx: any) => tx.wait());
    this.commercialUseLicenseId = await this.licenseTemplate.getLicenseTermsId(commercialTerms);
    logSuccess(`Commercial-use license registered: ${this.commercialUseLicenseId}`);
  } catch (error: any) {
    handleTransactionError(error, "LicenseTemplate");
  }

  // Commercial-remix license
  try {
    const remixTerms = {
      ...terms,
      royaltyPolicy: RoyaltyPolicyLRP,
      defaultMintingFee: 80,
      commercialUse: true,
      commercialRevShare: 100,
      currency: MockERC20
    };
    
    await this.licenseTemplate.registerLicenseTerms(remixTerms).then((tx: any) => tx.wait());
    this.commericialRemixLicenseId = await this.licenseTemplate.getLicenseTermsId(remixTerms);
    logSuccess(`Commercial-remix license registered: ${this.commericialRemixLicenseId}`);
  } catch (error: any) {
    handleTransactionError(error, "LicenseTemplate");
  }

  // ERC20 approvals
  logSection("ERC20 Approvals");
  const users = [this.owner, this.user1, this.user2];
  const spenders = [RoyaltyPolicyLAP, RoyaltyPolicyLRP, RoyaltyModule];
  
  for (const user of users) {
    for (const spender of spenders) {
      await checkAndApproveSpender(user, spender, APPROVAL_AMOUNT);
    }
  }
  
  // Additional approval for user1 to ArbitrationPolicyUMA
  await checkAndApproveSpender(this.user1, ArbitrationPolicyUMA, APPROVAL_AMOUNT);
  logSuccess("All ERC20 approvals completed");

  // UMA setup (conditional)
  if (STORY_OOV3) {
    logSection("UMA Configuration");
    logInfo(`OOV3 Address: ${STORY_OOV3}`);

    try {
      await this.arbitrationPolicyUMA.setOOV3(STORY_OOV3).then((tx: any) => tx.wait());
      logSuccess("OOV3 address set successfully");
    } catch (error: any) {
      handleTransactionError(error, "ArbitrationPolicyUMA");
    }

    try {
      await this.disputeModule
        .setArbitrationRelayer(ArbitrationPolicyUMA, this.owner.address)
        .then((tx: any) => tx.wait());
      logSuccess("Arbitration relayer set successfully");
      
      await this.arbitrationPolicyUMA.setMaxBond(MockERC20, hre.ethers.parseEther("1.0")).then((tx: any) => tx.wait());
      logSuccess("Max bond set successfully");
    } catch (error: any) {
      handleTransactionError(error, "DisputeModule and ArbitrationPolicyUMA");
    }
  }

  logSection("Setup Complete");
  logSuccess("All preconditions configured successfully");
});
