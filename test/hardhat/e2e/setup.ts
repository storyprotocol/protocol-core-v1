// This file is a root hook used to setup preconditions before running the tests.

import hre from "hardhat";
import { network } from "hardhat";
import { GroupingModule, IPAssetRegistry, LicenseRegistry, LicenseToken, LicensingModule, PILicenseTemplate, RoyaltyPolicyLAP, MockERC20, RoyaltyPolicyLRP, AccessController, RoyaltyModule, EvenSplitGroupPool, IpRoyaltyVaultImpl, DisputeModule, ArbitrationPolicyUMA, CoreMetadataModule, CoreMetadataViewModule, STORY_OOV3 } from "./constants";
import { terms } from "./licenseTermsTemplate";
import { checkAndApproveSpender } from "./utils/erc20Helper";
import { executeWithEnvironmentExpectation, logEnvironmentInfo } from "./utils/environmentHelper";

// Auto-skip functionality based on environment variables
function setupAutoSkip() {
  const originalIt = global.it;
  const originalDescribe = global.describe;

  const excludedFiles = process.env.EXCLUDED_FILES ? JSON.parse(process.env.EXCLUDED_FILES) : [];
  const excludedPatterns = process.env.EXCLUDED_TEST_PATTERNS ? JSON.parse(process.env.EXCLUDED_TEST_PATTERNS) : [];
  const excludedDescribeBlocks = process.env.EXCLUDED_DESCRIBE_BLOCKS ? JSON.parse(process.env.EXCLUDED_DESCRIBE_BLOCKS) : [];

  console.log('DEBUG: EXCLUDED_FILES:', excludedFiles);
  console.log('DEBUG: EXCLUDED_TEST_PATTERNS:', excludedPatterns);
  console.log('DEBUG: EXCLUDED_DESCRIBE_BLOCKS:', excludedDescribeBlocks);

  // Safely determine the caller test file from the stack (works during test definition time)
  const getCallerTestFile = (): string | undefined => {
    try {
      const err = new Error();
      const stack = (err.stack || '').split('\n');
      for (const line of stack) {
        // Matches: at /path/file.ts:line:col OR at Function (/path/file.ts:line:col)
        const match = line.match(/\((.*):(\d+):(\d+)\)|at (.*):(\d+):(\d+)/);
        const filePath = match ? (match[1] || match[4]) : undefined;
        if (!filePath) continue;
        // Heuristic: pick the first test file in our e2e folder that isn't setup.ts
        if (filePath.includes('/test/hardhat/e2e/') && !filePath.endsWith('setup.ts')) {
          return filePath;
        }
      }
    } catch {}
    return undefined;
  };

  // Function to check if a file is excluded
  const isFileExcluded = (filePath) => {
    if (!filePath) return false;
    return excludedFiles.some((excludedFile) => filePath.includes(excludedFile));
  };

  // Override global.it to check for excluded files and patterns
  global.it = function(title: string, fn?: Mocha.Func | Mocha.AsyncFunc) {
    const testFile = getCallerTestFile();
    console.log('DEBUG: Current test file:', testFile);

    if (isFileExcluded(testFile)) {
      console.log(`⏭️  Skipping test in file: "${testFile}"`);
      return originalIt.skip(title, fn);
    }

    const shouldSkipPattern = excludedPatterns.some((pattern: string) => title.includes(pattern));
    if (shouldSkipPattern) {
      console.log(`⏭️  Skipping test: "${title}" - pattern excluded for current network`);
      return originalIt.skip(title, fn);
    }
    
    return originalIt.call(this, title, fn);
  };
  
  // Override global.describe to check for excluded files and describe blocks
  global.describe = function(title: string, fn: () => void) {
    const describeFile = getCallerTestFile();
    console.log('DEBUG: Current describe file:', describeFile);

    if (isFileExcluded(describeFile)) {
      console.log(`⏭️  Skipping describe block in file: "${describeFile}"`);
      return originalDescribe.skip(title, fn);
    }

    const shouldSkipDescribe = excludedDescribeBlocks.some((pattern: string) => title === pattern);
    if (shouldSkipDescribe) {
      console.log(`⏭️  Skipping describe block: "${title}" - excluded for current network`);
      return originalDescribe.skip(title, fn);
    }
    
    return originalDescribe.call(this, title, fn);
  };

  // Stable runtime guard using Mocha's current test context
  beforeEach(function () {
    const currentTest: any = (this as any).currentTest;
    const testTitle: string | undefined = currentTest?.title;
    const filePath: string | undefined = currentTest?.file;
    const normalizedPatterns: string[] = excludedPatterns.map((p: any) => String(p).toLowerCase().trim());

    // File-based exclusion
    if (isFileExcluded(filePath)) {
      console.log(`⏭️  [beforeEach] Skipping due to excluded file: "${filePath}"`);
      return (this as any).skip();
    }

    // Title pattern exclusion
    if (testTitle) {
      const normTitle = testTitle.toLowerCase().trim();
      if (normalizedPatterns.some((pattern: string) => normTitle.includes(pattern))) {
      console.log(`⏭️  [beforeEach] Skipping due to excluded pattern in title: "${testTitle}"`);
      return (this as any).skip();
      }
    }

    // Suite-level exclusion by walking parents
    let suite = currentTest?.parent;
    while (suite) {
      const suiteTitle: string | undefined = suite.title;
      if (suiteTitle && (
        excludedDescribeBlocks.some((pattern: string) => suiteTitle === pattern) ||
        normalizedPatterns.some((pattern: string) => suiteTitle.toLowerCase().includes(pattern))
      )) {
        console.log(`⏭️  [beforeEach] Skipping due to excluded describe: "${suiteTitle}" (file: ${filePath})`);
        return (this as any).skip();
      }
      suite = suite.parent;
    }
  });
}

// Initialize auto-skip functionality
setupAutoSkip();

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
  // this.erc20 = await hre.ethers.getContractAt("MockERC20", MockERC20);
  this.errors = await hre.ethers.getContractFactory("contracts/lib/Errors.sol:Errors");
  
  console.log(`================= Load Users =================`);
  [this.owner, this.user1, this.user2] = await hre.ethers.getSigners();
  await this.owner.sendTransaction({ to: this.user1.address, value: hre.ethers.parseEther("10.0") }).then((tx: any) => tx.wait());
  await this.owner.sendTransaction({ to: this.user2.address, value: hre.ethers.parseEther("10.0") }).then((tx: any) => tx.wait());
  
  console.log(`================= Chain ID =================`);
  const networkConfig = network.config;
  this.chainId = networkConfig.chainId;
  console.log("chainId: ", this.chainId);
  
  // Log environment information
  logEnvironmentInfo();

  console.log(`================= Whitelist Royalty Token =================`);
  await executeWithEnvironmentExpectation(
    async () => {
      const tx = await this.royaltyModule.whitelistRoyaltyToken(MockERC20, true);
      return await tx.wait();
    },
    "whitelistRoyaltyToken",
    'adminOperations'
  );

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

  console.log(`================= Get OOV3 Contract Address =================`);
  const oov3Contract = await this.arbitrationPolicyUMA.oov3();
  console.log(`OOV3 Contract Address: ${oov3Contract}`);

  console.log(`================= Call OOV3 getMinimumBond =================`);
  // Get the OOV3 contract instance
  this.oov3 = await hre.ethers.getContractAt("IOOV3", oov3Contract);
  
  // Call getMinimumBond method with MockERC20 token address
  this.minimumBond = await this.oov3.getMinimumBond(MockERC20);
  console.log(`Minimum Bond for MockERC20: ${this.minimumBond.toString()}`);
  
  if (STORY_OOV3) {
    console.log(`================= Set UMA =================`)
    console.log(`================= STORY_OOV3: ${STORY_OOV3} =================`)

    await executeWithEnvironmentExpectation(
      async () => {
        const tx = await this.arbitrationPolicyUMA.setOOV3(STORY_OOV3);
        return await tx.wait();
      },
      "setOOV3",
      'adminOperations'
    );

    console.log(`ArbitrationPolicyUMA: ${ArbitrationPolicyUMA}`);
    console.log(`this.owner.address: ${this.owner.address}`);
    
    await executeWithEnvironmentExpectation(
      async () => {
        const tx = await this.disputeModule.setArbitrationRelayer(ArbitrationPolicyUMA, this.owner.address);
        return await tx.wait();
      },
      "setArbitrationRelayer",
      'adminOperations'
    );
    
    await executeWithEnvironmentExpectation(
      async () => {
        const tx = await this.arbitrationPolicyUMA.setMaxBond(MockERC20, hre.ethers.parseEther("1.0"));
        return await tx.wait();
      },
      "setMaxBond",
      'adminOperations'
    );
  }
});
