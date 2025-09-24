// Test: LicensingModule - License Template Tests

import "../setup";
import { expect } from "chai";
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";
import { RoyaltyPolicyLRP, RoyaltyPolicyLAP, PILicenseTemplate } from "../constants";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { registerPILTerms } from "../utils/licenseHelper";
import hre from "hardhat";

describe("LicensingModule - License Template Tests", function () {
  let signers: SignerWithAddress[];
  let ipId1: string;

  beforeEach(async function () {
    signers = await hre.ethers.getSigners();

    // Create IPs
    const result1 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    ipId1 = result1.ipId;
  });

  it("Should revert when minting license token with different template from existing", async function () {
    // Register first license terms
    const termsId1 = await registerPILTerms(true, 0, 10, RoyaltyPolicyLRP);
    console.log("termsId1", termsId1);

    // Attach first license terms
    await this.licensingModule.attachLicenseTerms(ipId1, PILicenseTemplate, termsId1);

    // Deploy and register second template
    const MockLicenseTemplateFactory = await hre.ethers.getContractFactory("contracts/MockLicenseTemplate.sol:MockLicenseTemplate");
    const pilTemplate2 = await MockLicenseTemplateFactory.deploy();
    await pilTemplate2.waitForDeployment();
    const pilTemplate2Address = await pilTemplate2.getAddress();
    console.log("pilTemplate2", pilTemplate2Address);

    // Register license template
    const tx = await this.licenseRegistry.registerLicenseTemplate(pilTemplate2Address);
    await tx.wait();

    // Register license terms
    const tx2 = await pilTemplate2.registerLicenseTerms();
    await tx2.wait();
    const termsCounter = await pilTemplate2.totalRegisteredLicenseTerms();
    const termsId2 = termsCounter - BigInt(1);
    console.log("termsId2: ", termsId2);

    const exists = await pilTemplate2.exists(termsId2);
    expect(exists).to.be.true;

    // Should revert when mint with different template
    await expect(
        this.licensingModule.mintLicenseTokens(ipId1, pilTemplate2Address, termsId2, 1, signers[1].address, hre.ethers.ZeroAddress, 0, 0)
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__UnmatchedLicenseTemplate");
  });

  it("Should revert when attach license terms with different template from existing", async function () {
    // Register first license terms
    const termsId1 = await registerPILTerms(true, 0, 10, RoyaltyPolicyLRP);
    console.log("termsId1", termsId1);

    // Mint license token
    await this.licensingModule.mintLicenseTokens(ipId1, PILicenseTemplate, termsId1, 1, signers[1].address, hre.ethers.ZeroAddress, 0, 0);

    // Deploy and register second template
    const MockLicenseTemplateFactory = await hre.ethers.getContractFactory("contracts/MockLicenseTemplate.sol:MockLicenseTemplate");
    const pilTemplate2 = await MockLicenseTemplateFactory.deploy();
    await pilTemplate2.waitForDeployment();
    const pilTemplate2Address = await pilTemplate2.getAddress();
    console.log("pilTemplate2", pilTemplate2Address);

    // Register license template
    const tx = await this.licenseRegistry.registerLicenseTemplate(pilTemplate2Address);
    await tx.wait();

    // Register license terms
    const tx2 = await pilTemplate2.registerLicenseTerms();
    await tx2.wait();
    const termsCounter = await pilTemplate2.totalRegisteredLicenseTerms();
    const termsId2 = termsCounter - BigInt(1);
    console.log("termsId2: ", termsId2);

    const exists = await pilTemplate2.exists(termsId2);
    expect(exists).to.be.true;

    // Attach second terms of different template
    await expect(
        this.licensingModule.attachLicenseTerms(ipId1, pilTemplate2Address, termsId2)
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__UnmatchedLicenseTemplate");
  });

  it("Should allow minting license token with same template as existing", async function () {
    // Generate random commercial rev share for the first terms, range from 0 to 100*1000000
    const randomCommercialRevShare1 = Math.floor(Math.random() * 100 * 1000000);
    console.log("randomCommercialRevShare for first terms:", randomCommercialRevShare1);
    const termsId1 = await registerPILTerms(true, 0, randomCommercialRevShare1, RoyaltyPolicyLRP);
    console.log("termsId1", termsId1);

    // Generate random commercial rev share for the second terms, range from 0 to 100*1000000
    const randomCommercialRevShare2 = Math.floor(Math.random() * 100 * 1000000);
    console.log("randomCommercialRevShare for second terms:", randomCommercialRevShare2);
    const termsId2 = await registerPILTerms(true, 0, randomCommercialRevShare2, RoyaltyPolicyLAP);
    console.log("termsId2", termsId2);

    // Attach first license terms
    await this.licensingModule.attachLicenseTerms(ipId1, PILicenseTemplate, termsId1);

    // Should allow minting license tokens with second terms of the same template
    await expect(
        this.licensingModule.mintLicenseTokens(
            ipId1,
            PILicenseTemplate,
            termsId2,
            1,
            signers[1].address,
            "0x",
            0,
            0
        )
    ).not.to.be.rejectedWith(Error);
  });

  it("Should allow attaching license terms with same template as existing", async function () {
    // Generate random commercial rev share for the first terms, range from 0 to 100*1000000
    const randomCommercialRevShare1 = Math.floor(Math.random() * 100 * 1000000);
    console.log("randomCommercialRevShare for first terms:", randomCommercialRevShare1);
    const termsId1 = await registerPILTerms(true, 0, randomCommercialRevShare1, RoyaltyPolicyLRP);
    console.log("termsId1", termsId1);

    // mint license token
    await this.licensingModule.mintLicenseTokens(ipId1, PILicenseTemplate, termsId1, 1, signers[1].address, hre.ethers.ZeroAddress, 0, 0);

    // Generate random commercial rev share for the second terms, range from 0 to 100*1000000
    const randomCommercialRevShare2 = Math.floor(Math.random() * 100 * 1000000);
    console.log("randomCommercialRevShare for second terms:", randomCommercialRevShare2);
    const termsId2 = await registerPILTerms(true, 0, randomCommercialRevShare2, RoyaltyPolicyLAP);
    console.log("termsId2", termsId2);

    // Should allow attaching second terms
    await expect (
        this.licensingModule.attachLicenseTerms(ipId1, PILicenseTemplate, termsId2)
    ).not.to.be.rejectedWith(Error);
  });

  it("Should revert when minting license token and attach license terms with unregistered license template", async function () {
    // Deploy license template
    const MockLicenseTemplateFactory = await hre.ethers.getContractFactory("contracts/MockLicenseTemplate.sol:MockLicenseTemplate");
    const pilTemplate2 = await MockLicenseTemplateFactory.deploy();
    await pilTemplate2.waitForDeployment();
    const pilTemplate2Address = await pilTemplate2.getAddress();
    console.log("pilTemplate2", pilTemplate2Address);

    // Register license terms
    const tx = await pilTemplate2.registerLicenseTerms();
    await tx.wait();
    const termsCounter = await pilTemplate2.totalRegisteredLicenseTerms();
    const termsId2 = termsCounter - BigInt(1);
    console.log("termsId2", termsId2);

    // Should revert when mint with unregistered license template
    await expect(
        this.licensingModule.mintLicenseTokens(ipId1, pilTemplate2Address, termsId2, 1, signers[1].address, hre.ethers.ZeroAddress, 0, 0)
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__LicenseTermsNotExists");

    // Should revert when attach with unregistered license template
    await expect(
        this.licensingModule.attachLicenseTerms(ipId1, pilTemplate2Address, termsId2)
    ).to.be.revertedWithCustomError(this.errors, "LicensingModule__LicenseTermsNotFound");
  });
}); 
