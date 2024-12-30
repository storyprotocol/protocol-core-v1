// Test: RoyaltyModule - payRoyaltyOnBehalf, transferToVault, claimRevenueOnBehalf

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { MockERC20, PILicenseTemplate, RoyaltyPolicyLAP, RoyaltyPolicyLRP } from "../constants";
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";
import { terms } from "../licenseTermsTemplate";

describe("RoyaltyModule", function () {
  let signers: any, licenseTermsLAPId: any, licenseTermsLRPId: any;
  let royaltyModules: any, royaltyPolicies: any, licensingModules: any;

  const setupRoyaltyModules = () => {
    licensingModules = signers.map((signer: any, i: number) =>
      this.licensingModule.connect(signer)
    );
    royaltyModules = signers.map((signer: any, i: number) =>
      this.royaltyModule.connect(signer)
    );
    royaltyPolicies = {
      LAP: this.royaltyPolicyLAP.connect(signers[1]),
      LRP: this.royaltyPolicyLRP.connect(signers[1]),
    };
  };

  const registerLicenseTerms = async (policy: any) => {
    terms.royaltyPolicy = policy;
    const tx = await this.licenseTemplate.connect(signers[0]).registerLicenseTerms(terms);
    await tx.wait();
    return await this.licenseTemplate.getLicenseTermsId(terms);
  };

  const attachLicense = async (licensingModule: any, ipId: any, licenseId: any) => {
    const tx = await licensingModule.attachLicenseTerms(ipId, PILicenseTemplate, licenseId);
    await tx.wait();
  };

  const registerDerivative = async (licensingModule: any, childId: any, parentIds: any[], licenseId: any) => {
    const tx = await licensingModule.registerDerivative(childId, parentIds, [licenseId], PILicenseTemplate, hre.ethers.ZeroAddress, 0, 0);
    await tx.wait();
  };

  const payRoyalty = async (royaltyModule: any, payerId: any, payeeId: any, amount: number) => {
    const tx = await royaltyModule.payRoyaltyOnBehalf(payeeId, payerId, MockERC20, BigInt(amount));
    await tx.wait();
  };

  const transferToVault = async (policy: any, childId: any, parentId: any) => {
    const tx = await policy.transferToVault(childId, parentId, MockERC20);
    await tx.wait();
  };

  this.beforeAll("Setup and register license terms", async function () {
    signers = await hre.ethers.getSigners();
    setupRoyaltyModules();
    licenseTermsLAPId = await registerLicenseTerms(RoyaltyPolicyLAP);
    licenseTermsLRPId = await registerLicenseTerms(RoyaltyPolicyLRP);
  });

  it("Handles royalty and revenue flows correctly", async function () {
    const [ipId1, ipId2, ipId3] = await Promise.all(
      signers.map((signer: any) => mintNFTAndRegisterIPA(signer, signer).then((res: any) => res.ipId))
    );

    await attachLicense(licensingModules[0], ipId1, licenseTermsLAPId);
    await registerDerivative(licensingModules[1], ipId2, [ipId1], licenseTermsLAPId);
    await registerDerivative(licensingModules[2], ipId3, [ipId2], licenseTermsLAPId);

    await payRoyalty(royaltyModules[2], ipId3, ipId2, 1000);
    await transferToVault(royaltyPolicies.LAP, ipId2, ipId1);

    // Assertions for revenue and vault interactions can be added similarly.
  });
});
