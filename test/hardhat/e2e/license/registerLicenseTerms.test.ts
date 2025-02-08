// Test: PILicenseTemplate - registerLicenseTerms

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { MockERC20, RoyaltyPolicyLAP, RoyaltyPolicyLRP } from "../constants";
import { terms } from "../licenseTermsTemplate";

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
});
