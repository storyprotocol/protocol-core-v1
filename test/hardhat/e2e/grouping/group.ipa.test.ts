// Test: Group IP Asset

import "../setup";
import { expect } from "chai";
import { EvenSplitGroupPool, PILicenseTemplate, RoyaltyPolicyLRP } from "../constants";
import { mintNFTAndRegisterIPA, mintNFTAndRegisterIPAWithLicenseTerms } from "../utils/mintNFTAndRegisterIPA";
import { LicensingConfig, registerPILTerms } from "../utils/licenseHelper";

const registerGroupAndLicense = async function () {
  const groupId = await this.groupingModule
    .registerGroup(EvenSplitGroupPool)
    .then((tx) => tx.wait())
    .then((receipt) => receipt.logs[5].args[0]);
  expect(groupId).to.be.properHex(40);

  const commRemixTermsId = await registerPILTerms(true, 0, 10e6, RoyaltyPolicyLRP);
  await this.licensingModule.attachLicenseTerms(groupId, PILicenseTemplate, commRemixTermsId).then((tx) => tx.wait());
  return { groupId, commRemixTermsId };
};

describe("Group IP Asset Tests", function () {
  describe("Register Group IPA", function () {
    it("with whitelisted pool", async function () {
      const groupId = await this.groupingModule
        .registerGroup(EvenSplitGroupPool)
        .then((tx) => tx.wait())
        .then((receipt) => receipt.logs[5].args[0]);
      expect(await this.ipAssetRegistry.isRegisteredGroup(groupId)).to.be.true;
    });

    it("with non-whitelisted pool", async function () {
      await expect(this.groupingModule.registerGroup(this.user1.address)).to.be.revertedWithCustomError(
        this.errors,
        "GroupIPAssetRegistry__GroupRewardPoolNotRegistered"
      );
    });
  });

  describe("IP Management in Groups", function () {
    let groupId, commRemixTermsId;
    before(async function () {
      ({ groupId, commRemixTermsId } = await registerGroupAndLicense.call(this));
    });

    it("Add and remove a single IP", async function () {
      const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
      await this.groupingModule.addIp(groupId, [ipId]).then((tx) => tx.wait());
      expect(await this.ipAssetRegistry.containsIp(groupId, ipId)).to.be.true;

      await this.groupingModule.removeIp(groupId, [ipId]).then((tx) => tx.wait());
      expect(await this.ipAssetRegistry.containsIp(groupId, ipId)).to.be.false;
    });

    it("Add and remove multiple IPs", async function () {
      const { ipId: ip1 } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
      const { ipId: ip2 } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId, this.user1);
      await this.groupingModule.addIp(groupId, [ip1, ip2]).then((tx) => tx.wait());
      expect(await this.ipAssetRegistry.containsIp(groupId, ip1)).to.be.true;
      expect(await this.ipAssetRegistry.containsIp(groupId, ip2)).to.be.true;

      await this.groupingModule.removeIp(groupId, [ip1, ip2]).then((tx) => tx.wait());
      expect(await this.ipAssetRegistry.containsIp(groupId, ip1)).to.be.false;
      expect(await this.ipAssetRegistry.containsIp(groupId, ip2)).to.be.false;
    });

    it("Non-owner actions", async function () {
      const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
      await expect(this.groupingModule.connect(this.user1).addIp(groupId, [ipId])).to.be.revertedWithCustomError(
        this.errors,
        "AccessController__PermissionDenied"
      );
      await expect(this.groupingModule.connect(this.user1).removeIp(groupId, [ipId])).to.be.revertedWithCustomError(
        this.errors,
        "AccessController__PermissionDenied"
      );
    });

    it("Add IP with mismatched license", async function () {
      const { ipId } = await mintNFTAndRegisterIPA();
      await expect(this.groupingModule.addIp(groupId, [ipId])).to.be.revertedWithCustomError(
        this.errors,
        "LicenseRegistry__IpHasNoGroupLicenseTerms"
      );
    });
  });

  describe("Locked Groups", function () {
    let groupId, commRemixTermsId, ipId1, ipId2;

    before(async function () {
      ({ groupId, commRemixTermsId } = await registerGroupAndLicense.call(this));
      ({ ipId: ipId1 } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId));
      await this.groupingModule.addIp(groupId, [ipId1]).then((tx) => tx.wait());
      ({ ipId: ipId2 } = await mintNFTAndRegisterIPA(this.user2));
      await this.licensingModule
        .registerDerivative(ipId2, [groupId], [commRemixTermsId], PILicenseTemplate, "0x", 0, 100e6)
        .then((tx) => tx.wait());
    });

    it("Handle group frozen due to derivative", async function () {
      const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
      await expect(this.groupingModule.addIp(groupId, [ipId])).to.be.revertedWithCustomError(
        this.errors,
        "GroupingModule__GroupFrozenDueToHasDerivativeIps"
      );
      await expect(this.groupingModule.removeIp(groupId, [ipId1])).to.be.revertedWithCustomError(
        this.errors,
        "GroupingModule__GroupFrozenDueToHasDerivativeIps"
      );
    });

    it("Handle group frozen due to minted license", async function () {
      await this.licensingModule
        .mintLicenseTokens(groupId, PILicenseTemplate, commRemixTermsId, 1, this.owner.address, "0x", 0)
        .then((tx) => tx.wait());
      const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
      await expect(this.groupingModule.addIp(groupId, [ipId])).to.be.revertedWithCustomError(
        this.errors,
        "GroupingModule__GroupFrozenDueToAlreadyMintLicenseTokens"
      );
      await expect(this.groupingModule.removeIp(groupId, [ipId1])).to.be.revertedWithCustomError(
        this.errors,
        "GroupingModule__GroupFrozenDueToAlreadyMintLicenseTokens"
      );
    });
  });
});
