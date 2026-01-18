import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { PILicenseTemplate, LicenseCallerWhitelistHook, ModuleRegistry, EvenSplitGroupPool, LicenseRegistry, AccessController } from "../constants";
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";

// Hook Contract ABI (for calling whitelist functions) - includes error definitions
const HOOK_ABI = [
  // Whitelist management
  "function addToWhitelist(address licensorIpId, address licenseTemplate, uint256 licenseTermsId, address minter) external",
  "function removeFromWhitelist(address licensorIpId, address licenseTemplate, uint256 licenseTermsId, address minter) external",
  "function isWhitelisted(address licensorIpId, address licenseTemplate, uint256 licenseTermsId, address minter) external view returns (bool)",
  // ILicensingHook interface
  "function beforeMintLicenseTokens(address caller, address licensorIpId, address licenseTemplate, uint256 licenseTermsId, uint256 amount, address receiver, bytes calldata hookData) external returns (uint256)",
  "function beforeRegisterDerivative(address caller, address childIpId, address parentIpId, address licenseTemplate, uint256 licenseTermsId, bytes calldata hookData) external returns (uint256)",
  "function calculateMintingFee(address caller, address licensorIpId, address licenseTemplate, uint256 licenseTermsId, uint256 amount, address receiver, bytes calldata hookData) external view returns (uint256)",
  // Module info & immutable state
  "function name() external view returns (string)",
  "function LICENSE_REGISTRY() external view returns (address)",
  "function ACCESS_CONTROLLER() external view returns (address)",
  "function IP_ASSET_REGISTRY() external view returns (address)",
  "function supportsInterface(bytes4 interfaceId) external view returns (bool)",
  // Events
  "event AddressWhitelisted(address indexed licensorIpId, address indexed licenseTemplate, uint256 indexed licenseTermsId, address minter)",
  "event AddressRemovedFromWhitelist(address indexed licensorIpId, address indexed licenseTemplate, uint256 indexed licenseTermsId, address minter)",
  // Custom errors
  "error LicenseCallerWhitelistHook_AddressNotWhitelisted(address minter)",
  "error LicenseCallerWhitelistHook_AddressAlreadyWhitelisted(address minter)",
  "error LicenseCallerWhitelistHook_AddressNotInWhitelist(address minter)",
  "error LicenseCallerWhitelistHook_ZeroAddress()",
];


let signers: any[];
let hookContract: any;
let tokenId: number;
let parentTokenId: number;
let childTokenId: number;
let childTokenId2: number;
let ipId: string;
let licenseTermsId: bigint;

before("Setup", async function () {
  signers = await hre.ethers.getSigners();

  // Get the hook contract instance with full ABI
  hookContract = new hre.ethers.Contract(
    LicenseCallerWhitelistHook,
    HOOK_ABI,
    signers[0]
  );

  console.log("\n=============== Test Setup ===============");
  console.log("Hook Contract:", LicenseCallerWhitelistHook);
  console.log("Total signers available:", signers.length);
  console.log("IP Owner (signers[0]):", signers[0].address);
  console.log("Minter (signers[1]):", signers[1]?.address);
  console.log("Non-whitelisted (signers[2]):", signers[2]?.address);
  console.log("==========================================\n");

  // Create IP Asset
  const result = await mintNFTAndRegisterIPA(signers[0], signers[0]);
  tokenId = result.tokenId;
  ipId = result.ipId;

  expect(ipId).to.not.be.empty;

  // attach license terms
  const connectedLicensingModule = this.licensingModule.connect(signers[0]);
  licenseTermsId = this.commericialRemixLicenseId;

  const attachLicenseTermsTx = await connectedLicensingModule.attachLicenseTerms(ipId, PILicenseTemplate, licenseTermsId);
  await attachLicenseTermsTx.wait();

  expect(attachLicenseTermsTx.hash).to.not.be.empty;
});

describe("LicenseCallerWhitelistHook - Basic Verification", function () {

  it("Verify hook contract is deployed", async function () {
    const code = await hre.ethers.provider.getCode(LicenseCallerWhitelistHook);
    expect(code).to.not.equal("0x");
    console.log("✅ Hook contract is deployed, code length:", code.length);
  });

  it("Return correct module name", async function () {
    const name = await hookContract.name();
    console.log("✅ Module name:", name);
    expect(name).to.equal("LICENSE_CALLER_WHITELIST_HOOK");
  });

  it("Return correct LICENSE_REGISTRY address", async function () {
    const licenseRegistryAddress = await hookContract.LICENSE_REGISTRY();
    console.log("LICENSE_REGISTRY address:", licenseRegistryAddress);
    console.log("Expected LicenseRegistry:", LicenseRegistry);

    expect(licenseRegistryAddress).to.equal(LicenseRegistry);
    console.log("✅ LICENSE_REGISTRY address is correct");
  });

  it("Return correct ACCESS_CONTROLLER address", async function () {
    const accessControllerAddress = await hookContract.ACCESS_CONTROLLER();
    console.log("ACCESS_CONTROLLER address:", accessControllerAddress);
    console.log("Expected AccessController:", AccessController);

    expect(accessControllerAddress).to.equal(AccessController);
    console.log("✅ ACCESS_CONTROLLER address is correct");
  });

  it("Verify hook is registered in ModuleRegistry", async function () {
    const moduleRegistry = await hre.ethers.getContractAt("ModuleRegistry", ModuleRegistry);
    const isHookRegistered = await moduleRegistry.isRegistered(LicenseCallerWhitelistHook);

    console.log("Hook address:", LicenseCallerWhitelistHook);
    console.log("Is registered in ModuleRegistry:", isHookRegistered);

    expect(isHookRegistered).to.be.true;
    console.log("✅ Hook is registered in ModuleRegistry");
  });
});

// ==================== Mint License Tokens E2E Test ====================

describe("LicenseCallerWhitelistHook - Mint License Tokens E2E Test", function () {
  // ==================== 1. IP Asset Setup ====================

  describe("1. Setup: Create IP Asset and Attach License Terms", function () {
    // it("Create and register IP Asset", async function () {
    //   const result = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    //   tokenId = result.tokenId;
    //   ipId = result.ipId;

    //   console.log("✅ Created IP Asset - IP ID:", ipId, "Token ID:", tokenId);
    //   expect(ipId).to.not.be.empty;
    // });

    // it("Attach license terms to IP", async function () {
    //   const connectedLicensingModule = this.licensingModule.connect(signers[0]);
    //   licenseTermsId = this.commericialRemixLicenseId;

    //   const tx = await connectedLicensingModule.attachLicenseTerms(ipId, PILicenseTemplate, licenseTermsId);
    //   await tx.wait();

    //   console.log("✅ Attached license terms - ID:", licenseTermsId.toString());
    // });

    it("IP Owner can mint (no hook configured)", async function () {
      const connectedLicensingModule = this.licensingModule.connect(signers[0]);

      const tx = await connectedLicensingModule.mintLicenseTokens(
        ipId,
        PILicenseTemplate,
        licenseTermsId,
        1,
        signers[1].address,
        hre.ethers.ZeroAddress,
        hre.ethers.parseUnits("1000", 18),
        50 * 10 ** 6
      );
      await tx.wait();

      console.log("✅ IP Owner minted successfully (no hook)");
      expect(tx.hash).to.not.be.empty;
    });

    it("Non-owner can mint (no hook configured - default behavior)", async function () {
      const nonOwner = signers[2];
      const connectedLicensingModule = this.licensingModule.connect(nonOwner);

      const tx = await connectedLicensingModule.mintLicenseTokens(
        ipId,
        PILicenseTemplate,
        licenseTermsId,
        1,
        signers[2].address,
        hre.ethers.ZeroAddress,
        hre.ethers.parseUnits("1000", 18),
        50 * 10 ** 6
      );
      await tx.wait();

      console.log("✅ Non-owner minted successfully (default PIL behavior)");
      expect(tx.hash).to.not.be.empty;
    });
  });

  // ==================== 2. Configure Hook ====================

  describe("2. Configure Licensing Hook", function () {
    it("Set licensing config with whitelist hook", async function () {
      const connectedLicensingModule = this.licensingModule.connect(signers[0]);

      const licensingConfig = {
        isSet: true,
        mintingFee: 100,
        licensingHook: LicenseCallerWhitelistHook,
        hookData: "0x",
        commercialRevShare: 0,
        disabled: false,
        expectMinimumGroupRewardShare: 0,
        expectGroupRewardPool: EvenSplitGroupPool
      };

      const tx = await connectedLicensingModule.setLicensingConfig(
        ipId,
        PILicenseTemplate,
        licenseTermsId,
        licensingConfig
      );
      await tx.wait();

      console.log("✅ Licensing config set with hook");
    });

    it("Verify licensing config is correctly set", async function () {
      const config = await this.licenseRegistry.getLicensingConfig(ipId, PILicenseTemplate, licenseTermsId);

      expect(config.isSet).to.be.true;
      expect(config.licensingHook).to.equal(LicenseCallerWhitelistHook);
      console.log("✅ Hook configured - Address:", config.licensingHook);
    });

    it("IP Owner cannot mint (not whitelisted)", async function () {
      const connectedLicensingModule = this.licensingModule.connect(signers[0]);

      await expect(
        connectedLicensingModule.mintLicenseTokens(
          ipId,
          PILicenseTemplate,
          licenseTermsId,
          1,
          signers[1].address,
          hre.ethers.ZeroAddress,
          hre.ethers.parseUnits("1000", 18),
          50 * 10 ** 6
        )
      ).to.be.rejected;

      console.log("✅ IP Owner correctly rejected (not whitelisted)");
    });

    it("Non-owner cannot mint (not whitelisted)", async function () {
      const connectedLicensingModule = this.licensingModule.connect(signers[2]);

      await expect(
        connectedLicensingModule.mintLicenseTokens(
          ipId,
          PILicenseTemplate,
          licenseTermsId,
          1,
          signers[2].address,
          hre.ethers.ZeroAddress,
          hre.ethers.parseUnits("1000", 18),
          50 * 10 ** 6
        )
      ).to.be.rejected;

      console.log("✅ Non-owner correctly rejected (not whitelisted)");
    });
  });

  // ==================== 3. Add to Whitelist ====================

  describe("3. Add Minter to Whitelist", function () {
    it("Add minter (signers[1]) to whitelist", async function () {
      const minter = signers[1].address;
      const tx = await hookContract.addToWhitelist(ipId, PILicenseTemplate, licenseTermsId, minter);
      await tx.wait();
      console.log("✅ Added to whitelist:", minter);
    });

    it("Verify minter is whitelisted", async function () {
      const isWhitelisted = await hookContract.isWhitelisted(ipId, PILicenseTemplate, licenseTermsId, signers[1].address);
      expect(isWhitelisted).to.be.true;
      console.log("✅ Whitelist status verified");
    });
  });

  // ==================== 4. Mint License Tokens ====================

  describe("4. Mint License Tokens (Hook Active)", function () {


    it("Whitelisted caller can mint", async function () {
      const connectedLicensingModule = this.licensingModule.connect(signers[1]);

      const tx = await connectedLicensingModule.mintLicenseTokens(
        ipId,
        PILicenseTemplate,
        licenseTermsId,
        1,
        signers[1].address,
        hre.ethers.ZeroAddress,
        hre.ethers.parseUnits("1000", 18),
        50 * 10 ** 6
      );
      await tx.wait();

      console.log("✅ Whitelisted caller minted successfully");
      expect(tx.hash).to.not.be.empty;
    });

    it("Non-whitelisted caller cannot mint", async function () {
      const connectedLicensingModule = this.licensingModule.connect(signers[2]);

      await expect(
        connectedLicensingModule.mintLicenseTokens(
          ipId,
          PILicenseTemplate,
          licenseTermsId,
          1,
          signers[2].address,
          hre.ethers.ZeroAddress,
          hre.ethers.parseUnits("1000", 18),
          50 * 10 ** 6
        )
      ).to.be.rejected;

      console.log("✅ Non-whitelisted caller correctly rejected");
    });
  });

  // ==================== 5. Remove from Whitelist ====================

  describe("5. Remove from Whitelist", function () {
    it("Remove minter from whitelist", async function () {
      const minter = signers[1].address;

      const tx = await hookContract.removeFromWhitelist(ipId, PILicenseTemplate, licenseTermsId, minter);
      await tx.wait();

      const isWhitelisted = await hookContract.isWhitelisted(ipId, PILicenseTemplate, licenseTermsId, minter);
      expect(isWhitelisted).to.be.false;
      console.log("✅ Removed from whitelist");
    });

    it("Cannot remove non-whitelisted address", async function () {
      await expect(
        hookContract.removeFromWhitelist(ipId, PILicenseTemplate, licenseTermsId, signers[2].address)
      ).to.be.rejected;

      console.log("✅ Correctly rejected (address not in whitelist)");
    });

    it("Removed address cannot mint", async function () {
      const connectedLicensingModule = this.licensingModule.connect(signers[1]);

      await expect(
        connectedLicensingModule.mintLicenseTokens(
          ipId,
          PILicenseTemplate,
          licenseTermsId,
          1,
          signers[1].address,
          hre.ethers.ZeroAddress,
          hre.ethers.parseUnits("1000", 18),
          50 * 10 ** 6
        )
      ).to.be.rejected;

      console.log("✅ Removed address correctly rejected");
    });
  });
});

// ==================== Register Derivative E2E Test ====================

describe("LicenseCallerWhitelistHook - Register Derivative E2E Test", function () {
  let parentIpId: string;
  let parentTokenId: number;
  let childIpId: string;
  let childIpId2: string;

  // ==================== 1. Setup Parent IP ====================

  describe("1. Setup: Create Parent IP and Attach License Terms", function () {
    it("Create and register parent IP Asset", async function () {
      const result = await mintNFTAndRegisterIPA(signers[0], signers[0]);
      parentTokenId = result.tokenId;
      parentIpId = result.ipId;

      console.log("✅ Created Parent IP - ID:", parentIpId, "Token:", parentTokenId);
      expect(parentIpId).to.not.be.empty;
    });

    it("Attach license terms to parent IP", async function () {
      const connectedLicensingModule = this.licensingModule.connect(signers[0]);
      licenseTermsId = this.commericialRemixLicenseId;

      const tx = await connectedLicensingModule.attachLicenseTerms(parentIpId, PILicenseTemplate, licenseTermsId);
      await tx.wait();

      console.log("✅ Attached license terms - ID:", licenseTermsId.toString());
    });
  });

  // ==================== 2. Setup Child IPs ====================

  describe("2. Setup: Create Child IP Assets", function () {
    it("Create child IP 1 (for whitelisted user - signers[1])", async function () {
      const result = await mintNFTAndRegisterIPA(signers[1], signers[1]);
      childTokenId = result.tokenId;
      childIpId = result.ipId;

      console.log("✅ Created Child IP 1 - ID:", childIpId, "Owner: signers[1]");
      expect(childIpId).to.not.be.empty;
    });

    it("Create child IP 2 (for non-whitelisted user - signers[2])", async function () {
      const result = await mintNFTAndRegisterIPA(signers[2], signers[2]);
      childTokenId2 = result.tokenId;
      childIpId2 = result.ipId;

      console.log("✅ Created Child IP 2 - ID:", childIpId2, "Owner: signers[2]");
      expect(childIpId2).to.not.be.empty;
    });

    it("Anyone can register derivative (no hook configured)", async function () {
      const result = await mintNFTAndRegisterIPA(signers[2], signers[2]);
      const testChildIpId = result.ipId;

      const connectedLicensingModule = this.licensingModule.connect(signers[2]);

      const tx = await connectedLicensingModule.registerDerivative(
        testChildIpId,
        [parentIpId],
        [licenseTermsId],
        PILicenseTemplate,
        hre.ethers.ZeroAddress,
        0,
        0,
        50 * 10 ** 6
      );
      await tx.wait();

      console.log("✅ Derivative registered successfully (no hook)");
      expect(tx.hash).to.not.be.empty;
    });
  });

  // ==================== 3. Configure Hook ====================

  describe("3. Configure Licensing Hook", function () {
    it("Set licensing config with whitelist hook", async function () {
      const connectedLicensingModule = this.licensingModule.connect(signers[0]);

      const licensingConfig = {
        isSet: true,
        mintingFee: 100,
        licensingHook: LicenseCallerWhitelistHook,
        hookData: "0x",
        commercialRevShare: 0,
        disabled: false,
        expectMinimumGroupRewardShare: 0,
        expectGroupRewardPool: EvenSplitGroupPool
      };

      const tx = await connectedLicensingModule.setLicensingConfig(
        parentIpId,
        PILicenseTemplate,
        licenseTermsId,
        licensingConfig
      );
      await tx.wait();

      console.log("✅ Licensing config set with hook");
    });

    it("Verify licensing config is correctly set", async function () {
      const config = await this.licenseRegistry.getLicensingConfig(parentIpId, PILicenseTemplate, licenseTermsId);

      expect(config.isSet).to.be.true;
      expect(config.licensingHook).to.equal(LicenseCallerWhitelistHook);
      console.log("✅ Hook configured - Address:", config.licensingHook);
    });

    it("Non-whitelisted cannot register derivative (hook active)", async function () {
      const connectedLicensingModule = this.licensingModule.connect(signers[2]);

      await expect(
        connectedLicensingModule.registerDerivative(
          childIpId2,
          [parentIpId],
          [licenseTermsId],
          PILicenseTemplate,
          hre.ethers.ZeroAddress,
          0,
          0,
          50 * 10 ** 6
        )
      ).to.be.rejected;

      console.log("✅ Non-whitelisted correctly rejected");
    });
  });

  // ==================== 4. Add to Whitelist ====================

  describe("4. Add Caller to Whitelist", function () {
    it("Add signers[1] to whitelist", async function () {
      const tx = await hookContract.addToWhitelist(parentIpId, PILicenseTemplate, licenseTermsId, signers[1].address);
      await tx.wait();
      console.log("✅ Added to whitelist:", signers[1].address);
    });

    it("Verify caller is whitelisted", async function () {
      const isWhitelisted = await hookContract.isWhitelisted(parentIpId, PILicenseTemplate, licenseTermsId, signers[1].address);
      expect(isWhitelisted).to.be.true;
      console.log("✅ Whitelist status verified");
    });
  });

  // ==================== 5. Register Derivative ====================

  describe("5. Register Derivative (Hook Active)", function () {
    it("Whitelisted caller can register derivative", async function () {
      const connectedLicensingModule = this.licensingModule.connect(signers[1]);

      const tx = await connectedLicensingModule.registerDerivative(
        childIpId,
        [parentIpId],
        [licenseTermsId],
        PILicenseTemplate,
        hre.ethers.ZeroAddress,
        0,
        0,
        50 * 10 ** 6
      );
      await tx.wait();

      console.log("✅ Whitelisted caller registered derivative successfully");
      expect(tx.hash).to.not.be.empty;
    });

    it("Non-whitelisted caller cannot register derivative", async function () {
      // Create new child IP for signers[2]
      const result = await mintNFTAndRegisterIPA(signers[2], signers[2]);
      const newChildIpId = result.ipId;

      const connectedLicensingModule = this.licensingModule.connect(signers[2]);

      await expect(
        connectedLicensingModule.registerDerivative(
          newChildIpId,
          [parentIpId],
          [licenseTermsId],
          PILicenseTemplate,
          hre.ethers.ZeroAddress,
          0,
          0,
          50 * 10 ** 6
        )
      ).to.be.rejected;

      console.log("✅ Non-whitelisted caller correctly rejected");
    });
  });

  // ==================== 6. Remove from Whitelist ====================

  describe("6. Remove from Whitelist", function () {
    it("Remove signers[1] from whitelist", async function () {
      const tx = await hookContract.removeFromWhitelist(parentIpId, PILicenseTemplate, licenseTermsId, signers[1].address);
      await tx.wait();

      const isWhitelisted = await hookContract.isWhitelisted(parentIpId, PILicenseTemplate, licenseTermsId, signers[1].address);
      expect(isWhitelisted).to.be.false;
      console.log("✅ Removed from whitelist");
    });

    it("Removed address cannot register derivative", async function () {
      const result = await mintNFTAndRegisterIPA(signers[1], signers[1]);
      const newChildIpId = result.ipId;

      const connectedLicensingModule = this.licensingModule.connect(signers[1]);

      await expect(
        connectedLicensingModule.registerDerivative(
          newChildIpId,
          [parentIpId],
          [licenseTermsId],
          PILicenseTemplate,
          hre.ethers.ZeroAddress,
          0,
          0,
          50 * 10 ** 6
        )
      ).to.be.rejected;

      console.log("✅ Removed address correctly rejected");
    });
  });
});

// ==================== Whitelist Management Tests (add, remove, re-add) ====================
describe("LicenseCallerWhitelistHook - Whitelist Management", function () {
  it("Add address to whitelist (by IP Owner)", async function () {
    // prepare for this test - set licensing config
    const connectedLicensingModule = this.licensingModule.connect(signers[0]);
    const licensingConfig = {
      isSet: true,
      mintingFee: 100,
      licensingHook: LicenseCallerWhitelistHook,
      hookData: "0x",
      commercialRevShare: 0,
      disabled: false,
      expectMinimumGroupRewardShare: 0,
      expectGroupRewardPool: EvenSplitGroupPool
    };

    const setLicensingConfigTx = await connectedLicensingModule.setLicensingConfig(ipId, PILicenseTemplate, licenseTermsId, licensingConfig);
    await setLicensingConfigTx.wait();

    // add address to whitelist
    const minter = signers[1].address;

    console.log("\n========== addToWhitelist Parameters ==========");
    console.log("  licensorIpId:", ipId);
    console.log("  licenseTemplate:", PILicenseTemplate);
    console.log("  licenseTermsId:", licenseTermsId?.toString());
    console.log("  minter:", minter);
    console.log("  caller (IP Owner):", signers[0].address);
    console.log("================================================\n");

    // First check current whitelist status
    const currentStatus = await hookContract.isWhitelisted(
      ipId,
      PILicenseTemplate,
      licenseTermsId,
      minter
    );
    console.log("Current whitelist status before add:", currentStatus);

    const tx = await hookContract.addToWhitelist(
      ipId,
      PILicenseTemplate,
      licenseTermsId,
      minter
    );

    console.log("Transaction sent:", tx.hash);
    const receipt = await tx.wait();
    console.log("✅ Address added to whitelist");
    console.log("   Block:", receipt.blockNumber);
    console.log("   Gas used:", receipt.gasUsed.toString());

    // Verify event emitted
    const event = receipt.logs.find((log: any) => {
      try {
        return hookContract.interface.parseLog(log)?.name === "AddressWhitelisted";
      } catch { return false; }
    });
    if (event) {
      console.log("   Event AddressWhitelisted emitted ✓");
    }
  });

  it("Verify address is whitelisted", async function () {
    const minter = signers[1].address;

    const isWhitelisted = await hookContract.isWhitelisted(
      ipId,
      PILicenseTemplate,
      licenseTermsId,
      minter
    );

    console.log("isWhitelisted result:", isWhitelisted);
    expect(isWhitelisted).to.be.true;
    console.log("✅ Address is whitelisted:", isWhitelisted);
  });

  it("Verify non-whitelisted address returns false", async function () {
    const nonWhitelisted = signers[2].address;

    const isWhitelisted = await hookContract.isWhitelisted(
      ipId,
      PILicenseTemplate,
      licenseTermsId,
      nonWhitelisted
    );

    expect(isWhitelisted).to.be.false;
    console.log("✅ Non-whitelisted address returns false:", isWhitelisted);
  });

  it("Fail to add already whitelisted address", async function () {
    const minter = signers[1].address;

    await expect(
      hookContract.addToWhitelist(
        ipId,
        PILicenseTemplate,
        licenseTermsId,
        minter
      )
    ).to.be.rejected;

    console.log("✅ Correctly rejected duplicate whitelist entry");
  });

  it("Fail to add zero address to whitelist", async function () {
    await expect(
      hookContract.addToWhitelist(
        ipId,
        PILicenseTemplate,
        licenseTermsId,
        hre.ethers.ZeroAddress
      )
    ).to.be.rejected;

    console.log("✅ Correctly rejected zero address");
  });

  it("Fail when non-owner tries to add whitelist", async function () {
    // Check if we have enough signers
    if (signers.length < 3) {
      console.log("⚠️ Skipping test: Not enough signers available");
      this.skip();
      return;
    }

    const nonOwner = signers[2];
    const hookContractAsNonOwner = hookContract.connect(nonOwner);
    const targetAddress = signers.length > 3 ? signers[3].address : signers[2].address;

    console.log("Testing non-owner access:");
    console.log("  Non-owner:", nonOwner.address);
    console.log("  Target address:", targetAddress);

    await expect(
      hookContractAsNonOwner.addToWhitelist(
        ipId,
        PILicenseTemplate,
        licenseTermsId,
        targetAddress
      )
    ).to.be.rejected;

    console.log("✅ Non-owner cannot add whitelist");
  });

  // ==================== Remove from Whitelist Tests ====================

  it("Remove address from whitelist", async function () {
    const minter = signers[1].address;

    const tx = await hookContract.removeFromWhitelist(ipId, PILicenseTemplate, licenseTermsId, minter);
    await tx.wait();

    const isWhitelisted = await hookContract.isWhitelisted(ipId, PILicenseTemplate, licenseTermsId, minter);
    expect(isWhitelisted).to.be.false;
    console.log("✅ Address removed from whitelist");
  });

  it("Verify removed address is no longer whitelisted", async function () {
    const minter = signers[1].address;

    const isWhitelisted = await hookContract.isWhitelisted(ipId, PILicenseTemplate, licenseTermsId, minter);
    expect(isWhitelisted).to.be.false;
    console.log("✅ Removed address returns false:", isWhitelisted);
  });

  it("Fail to remove non-whitelisted address", async function () {
    const nonWhitelisted = signers[2].address;

    await expect(
      hookContract.removeFromWhitelist(ipId, PILicenseTemplate, licenseTermsId, nonWhitelisted)
    ).to.be.rejected;

    console.log("✅ Correctly rejected removing non-whitelisted address");
  });

  it("Fail when non-owner tries to remove from whitelist", async function () {
    // First re-add the address so we can test removal
    const minter = signers[1].address;
    const addTx = await hookContract.addToWhitelist(ipId, PILicenseTemplate, licenseTermsId, minter);
    await addTx.wait();

    const nonOwner = signers[2];
    const hookContractAsNonOwner = hookContract.connect(nonOwner);

    await expect(
      hookContractAsNonOwner.removeFromWhitelist(ipId, PILicenseTemplate, licenseTermsId, minter)
    ).to.be.rejected;

    console.log("✅ Non-owner cannot remove from whitelist");
  });

  // ==================== Re-add to Whitelist Tests ====================

  it("Remove then re-add address to whitelist", async function () {
    const minter = signers[1].address;

    // Remove first
    const removeTx = await hookContract.removeFromWhitelist(ipId, PILicenseTemplate, licenseTermsId, minter);
    await removeTx.wait();

    let isWhitelisted = await hookContract.isWhitelisted(ipId, PILicenseTemplate, licenseTermsId, minter);
    expect(isWhitelisted).to.be.false;
    console.log("  Removed from whitelist");

    // Re-add
    const addTx = await hookContract.addToWhitelist(ipId, PILicenseTemplate, licenseTermsId, minter);
    await addTx.wait();

    isWhitelisted = await hookContract.isWhitelisted(ipId, PILicenseTemplate, licenseTermsId, minter);
    expect(isWhitelisted).to.be.true;
    console.log("✅ Address re-added to whitelist");
  });

  it("Verify re-added address is whitelisted", async function () {
    const minter = signers[1].address;

    const isWhitelisted = await hookContract.isWhitelisted(ipId, PILicenseTemplate, licenseTermsId, minter);
    expect(isWhitelisted).to.be.true;
    console.log("✅ Re-added address is whitelisted:", isWhitelisted);
  });
});

// ==================== Calculate Minting Fee ====================
describe("Calculate Minting Fee", function () {
  it("Calculate minting fee for amount = 1", async function () {
    const mintingFee = await hookContract.calculateMintingFee(
      signers[1].address,
      ipId,
      PILicenseTemplate,
      licenseTermsId,
      1,
      signers[1].address,
      "0x"
    );

    expect(mintingFee).to.be.a("bigint");
    expect(mintingFee).to.be.gt(0);
    console.log("✅ Minting fee for 1 token:", mintingFee.toString());
  });

  it("Calculate minting fee for amount = 2", async function () {
    const mintingFee = await hookContract.calculateMintingFee(
      signers[1].address,
      ipId,
      PILicenseTemplate,
      licenseTermsId,
      2,
      signers[1].address,
      "0x"
    );

    expect(mintingFee).to.be.a("bigint");
    expect(mintingFee).to.be.gt(0);
    console.log("✅ Minting fee for 2 tokens:", mintingFee.toString());
  });

  it("Calculate minting fee for amount = 10", async function () {
    const mintingFee = await hookContract.calculateMintingFee(
      signers[1].address,
      ipId,
      PILicenseTemplate,
      licenseTermsId,
      10,
      signers[1].address,
      "0x"
    );

    expect(mintingFee).to.be.a("bigint");
    expect(mintingFee).to.be.gt(0);
    console.log("✅ Minting fee for 10 tokens:", mintingFee.toString());
  });

  it("Calculate fee for zero amount returns zero", async function () {
    const mintingFee = await hookContract.calculateMintingFee(
      signers[1].address,
      ipId,
      PILicenseTemplate,
      licenseTermsId,
      0,
      signers[1].address,
      "0x"
    );

    expect(mintingFee).to.equal(0n);
    console.log("✅ Zero amount returns zero fee");
  });

  it("Negative amount should be rejected", async function () {
    await expect(
      hookContract.calculateMintingFee(
        signers[1].address,
        ipId,
        PILicenseTemplate,
        licenseTermsId,
        -1,
        signers[1].address,
        "0x"
      )
    ).to.be.rejected;

    console.log("✅ Negative amount correctly rejected");
  });

  it("Fee calculation is independent of caller address", async function () {
    const fee1 = await hookContract.calculateMintingFee(
      signers[1].address,
      ipId,
      PILicenseTemplate,
      licenseTermsId,
      1,
      signers[1].address,
      "0x"
    );

    const fee2 = await hookContract.calculateMintingFee(
      signers[2].address,
      ipId,
      PILicenseTemplate,
      licenseTermsId,
      1,
      signers[1].address,
      "0x"
    );

    // Fee should be the same regardless of caller
    expect(fee1).to.equal(fee2);
    console.log("✅ Fee is independent of caller address");
  });

  it("Fee calculation is independent of receiver address", async function () {
    const fee1 = await hookContract.calculateMintingFee(
      signers[1].address,
      ipId,
      PILicenseTemplate,
      licenseTermsId,
      1,
      signers[1].address,
      "0x"
    );

    const fee2 = await hookContract.calculateMintingFee(
      signers[1].address,
      ipId,
      PILicenseTemplate,
      licenseTermsId,
      1,
      signers[2].address,
      "0x"
    );

    // Fee should be the same regardless of receiver
    expect(fee1).to.equal(fee2);
    console.log("✅ Fee is independent of receiver address");
  });
});
