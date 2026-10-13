// Test: PILicenseTemplate - registerLicenseTerms

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { MockERC20, RoyaltyPolicyLAP, RoyaltyPolicyLRP, PILicenseTemplate, ModuleRegistry } from "../constants";
import { terms } from "../licenseTermsTemplate";
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";

describe("PILicenseTemplate - registerLicenseTerms", function () {
  let signers:any;

  this.beforeAll("Get Signers", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners();   
  });

  it("Register non-commercial PIL license terms", async function () {
    const connectedLicense = this.licenseTemplate.connect(signers[0]);
    const tx = await expect(
        connectedLicense.registerLicenseTerms(terms)
    ).to.not.be.rejectedWith(Error);
    await tx.wait();
    
    console.log("Transaction hash: ", tx.hash);
    expect(tx.hash).not.to.be.empty.and.to.be.a("HexString");

    const licenseTermsId = await connectedLicense.getLicenseTermsId(terms);
    console.log("licenseTermsId: ", licenseTermsId);

    expect(licenseTermsId).and.to.be.a("bigint");
  });

  it("Register commercial use license terms", async function () {
    const testTerms = terms;
    testTerms.royaltyPolicy = RoyaltyPolicyLAP;
    testTerms.defaultMintingFee = 30;
    testTerms.commercialUse = true;
    testTerms.currency = MockERC20;

    const connectedLicense = this.licenseTemplate.connect(signers[0]);
    const tx = await expect(
        connectedLicense.registerLicenseTerms(testTerms)
    ).to.not.be.rejectedWith(Error);
    await tx.wait();
    
    console.log("Transaction hash: ", tx.hash);
    expect(tx.hash).not.to.be.empty.and.to.be.a("HexString");

    const licenseTermsId = await connectedLicense.getLicenseTermsId(terms);
    console.log("licenseTermsId: ", licenseTermsId);

    expect(licenseTermsId).and.to.be.a("bigint");
  });

  it("Register commercial remix license terms", async function () {
    const testTerms = terms;
    testTerms.royaltyPolicy = RoyaltyPolicyLRP;
    testTerms.defaultMintingFee = 60;
    testTerms.commercialUse = true;
    testTerms.commercialRevShare = 100;
    testTerms.currency = MockERC20;

    const connectedLicense = this.licenseTemplate.connect(signers[0]);
    const tx = await expect(
        connectedLicense.registerLicenseTerms(terms)
    ).to.not.be.rejectedWith(Error);
    await tx.wait();
    
    console.log("Transaction hash: ", tx.hash);
    expect(tx.hash).not.to.be.empty.and.to.be.a("HexString");

    const licenseTermsId = await connectedLicense.getLicenseTermsId(testTerms);
    console.log("licenseTermsId: ", licenseTermsId);

    expect(licenseTermsId).and.to.be.a("bigint");
  });

  it("Register commercial remix license terms with commercialRevShare larger than max value", async function () {
    const testTerms = terms;
    testTerms.royaltyPolicy = RoyaltyPolicyLAP;
    testTerms.defaultMintingFee = 160;
    testTerms.commercialUse = true;
    testTerms.commercialRevShare = 101 * 10 ** 6;
    testTerms.currency = MockERC20;

    const connectedLicense = this.licenseTemplate.connect(signers[0]);
    const tx = await expect(
        connectedLicense.registerLicenseTerms(terms)
    ).to.not.be.rejectedWith(Error);
    await tx.wait();
    
    console.log("Transaction hash: ", tx.hash);
    expect(tx.hash).not.to.be.empty.and.to.be.a("HexString");

    const licenseTermsId = await connectedLicense.getLicenseTermsId(testTerms);
    console.log("licenseTermsId: ", licenseTermsId);

    expect(licenseTermsId).and.to.be.a("bigint");
  });

  it("Register license terms without mandatory fields", async function () {
    const testTerms: Partial<typeof terms> = { ...terms };

    delete testTerms.commercialUse;
    await expect(
      this.licenseTemplate.registerLicenseTerms(testTerms)
    ).to.be.rejectedWith("missing value for component commercialUse");

    delete testTerms.expiration;
    await expect(
      this.licenseTemplate.registerLicenseTerms(testTerms)
    ).to.be.rejectedWith("missing value for component expiration");
  });

  it("Should revert predictMintingLicenseFee with invalid inputs", async function () {
    // Register license terms with default values
    const testTerms = {
      ...terms,
      royaltyPolicy: RoyaltyPolicyLAP,
      defaultMintingFee: 100,
      commercialUse: true,
      currency: MockERC20,
    };
    const termsId = await this.licenseTemplate.registerLicenseTerms(testTerms);
    await termsId.wait();
    const licenseTermsId = await this.licenseTemplate.getLicenseTermsId(testTerms);
    console.log("Registered licenseTermsId:", licenseTermsId);

    // Create and register an IP
    const result = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    const ipId = result.ipId;
    console.log("ipId:", ipId);

    // Attach license terms to the IP
    await this.licensingModule.connect(signers[0]).attachLicenseTerms(ipId, PILicenseTemplate, licenseTermsId);

    const receiver = signers[1].address;

    // Should revert when amount is 0
    await expect(
      this.licensingModule.predictMintingLicenseFee(
        ipId,
        PILicenseTemplate,
        licenseTermsId,
        0,
        receiver,
        "0x"
      )
    ).to.be.revertedWithCustomError(this.errors, "LicensingModule__MintAmountZero");

    // Should revert when receiver is zero address
    await expect(
      this.licensingModule.predictMintingLicenseFee(
        ipId,
        PILicenseTemplate,
        licenseTermsId,
        1,
        hre.ethers.ZeroAddress,
        "0x"
      )
    ).to.be.revertedWithCustomError(this.errors, "LicensingModule__ReceiverZeroAddress");
  });

  it("Should revert predictMintingLicenseFee when licensing hook minting fee is below license terms", async function () {
    // Register commercial remix license terms with mintingFee = 300
    const commRemixTerms = {
      ...terms,
      royaltyPolicy: RoyaltyPolicyLAP,
      defaultMintingFee: 300,
      commercialRevShare: 10,
      commercialUse: true,
      currency: MockERC20,
    };
    
    const tx = await this.licenseTemplate.registerLicenseTerms(commRemixTerms);
    await tx.wait();
    const commRemixTermsId = await this.licenseTemplate.getLicenseTermsId(commRemixTerms);
    console.log("Registered commRemixTermsId:", commRemixTermsId);

    // Create and register an IP
    const result = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    const ipId = result.ipId;
    console.log("ipId:", ipId);

    // Attach license terms to the IP
    await this.licensingModule.connect(signers[1]).attachLicenseTerms(ipId, PILicenseTemplate, commRemixTermsId);

    // Get ModuleRegistry
    const moduleRegistry = await hre.ethers.getContractAt("ModuleRegistry", ModuleRegistry);
    
    // Try to get existing MockLicensingHook from registry first
    let licensingHookAddress = await moduleRegistry.getModule("MockLicensingHook");
    console.log("Existing MockLicensingHook address:", licensingHookAddress);
    
    // If not registered yet (address is zero), deploy and register a new one
    if (licensingHookAddress === hre.ethers.ZeroAddress) {
      console.log("MockLicensingHook not found, deploying new one...");
      const MockLicensingHookFactory = await hre.ethers.getContractFactory("MockLicensingHook");
      const licensingHook = await MockLicensingHookFactory.deploy();
      await licensingHook.waitForDeployment();
      licensingHookAddress = await licensingHook.getAddress();
      console.log("MockLicensingHook deployed at:", licensingHookAddress);
      
      try {
        console.log("Attempting to register MockLicensingHook...");
        const registerTx = await moduleRegistry.connect(signers[0]).registerModule("MockLicensingHook", licensingHookAddress);
        await registerTx.wait();
        console.log("✅ MockLicensingHook registered in ModuleRegistry");
      } catch (error: any) {
        console.error("❌ Failed to register MockLicensingHook");
        console.error("Error:", error.message);
        console.error("⚠️  You may need admin privileges to register modules.");
        throw error;
      }
    } else {
      console.log("✅ Using existing MockLicensingHook at:", licensingHookAddress);
    }

    // Set licensing config with hook that returns mintingFee = 100 (amount * 100 = 1 * 100)
    // This is below the license terms defaultMintingFee of 300
    const licensingConfig = {
      isSet: true,
      mintingFee: 400,
      licensingHook: licensingHookAddress,
      hookData: hre.ethers.AbiCoder.defaultAbiCoder().encode(["address"], [hre.ethers.ZeroAddress]),
      disabled: false,
      commercialRevShare: 0,
      expectMinimumGroupRewardShare: 0,
      expectGroupRewardPool: hre.ethers.ZeroAddress,
    };

    await this.licensingModule.connect(signers[1]).setLicensingConfig(
      ipId,
      PILicenseTemplate,
      commRemixTermsId,
      licensingConfig
    );
    console.log("✅ Licensing config set with hook");
    await new Promise(resolve => setTimeout(resolve, 10000));

    await expect(
      this.licensingModule.predictMintingLicenseFee(
        ipId,
        PILicenseTemplate,
        commRemixTermsId,
        1,
        signers[2].address,
        "0x"
      )
    ).to.be.revertedWithCustomError(this.errors, "LicensingModule__LicensingHookMintingFeeBelowLicenseTerms");
  });
});
