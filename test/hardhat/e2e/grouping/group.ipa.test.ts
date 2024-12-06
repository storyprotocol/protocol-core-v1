// Test: Group IP Asset

import "../setup"
import { expect } from "chai"
import { EvenSplitGroupPool, PILicenseTemplate, RoyaltyPolicyLRP } from "../constants"
import { mintNFTAndRegisterIPA, mintNFTAndRegisterIPAWithLicenseTerms } from "../utils/mintNFTAndRegisterIPA";
import { LicensingConfig, registerPILTerms } from "../utils/licenseHelper";

describe("Register Group IPA", function () {
  it("Register Group IPA with whitelisted group pool", async function () {
    const groupId = await expect(
      this.groupingModule.registerGroup(EvenSplitGroupPool)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[5].args[0]);

    console.log("groupId", groupId)
    expect(groupId).to.be.properHex(40);

    const isRegisteredGroup = await this.ipAssetRegistry.isRegisteredGroup(groupId);
    expect(isRegisteredGroup).to.be.true;
  });

  it("Register Group IPA with non-whitelisted group pool", async function () {
    const nonWhitelistedGroupPool = this.user1.address;
    await expect(
      this.groupingModule.registerGroup(nonWhitelistedGroupPool)
    ).to.be.revertedWithCustomError(this.errors, "GroupIPAssetRegistry__GroupRewardPoolNotRegistered");
  });
});

describe("Add/Remove IP from Group IPA", function () {
  let groupId: any;
  let commRemixTermsId: any;

  before(async function () {
    groupId = await expect(
      this.groupingModule.registerGroup(EvenSplitGroupPool)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[5].args[0]);
    console.log("groupId", groupId);

    commRemixTermsId = await registerPILTerms(true, 0, 10 * 10 ** 6, RoyaltyPolicyLRP);
    await expect(
      this.licensingModule.attachLicenseTerms(groupId, PILicenseTemplate, commRemixTermsId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
  });

  it("Add/Remove an IP to the group", async function () {
    // Register IP
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
    await expect(
      this.licensingModule.setLicensingConfig(ipId, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    // Add IP to the group
    await expect(
      this.groupingModule.addIp(groupId, [ipId])
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    
    let containsIp = await this.ipAssetRegistry.containsIp(groupId, ipId);
    expect(containsIp).to.be.true;

    // Remove IP from the group
    await expect(
      this.groupingModule.removeIp(groupId, [ipId])
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    containsIp = await this.ipAssetRegistry.containsIp(groupId, ipId);
    expect(containsIp).to.be.false;
  });

  it("Add/Remove multiple IPs to the group", async function () {
    // Register IPs
    const {ipId: ipId1} = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
    await expect(
      this.licensingModule.setLicensingConfig(ipId1, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    const {ipId: ipId2} = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId, this.user1, this.user1);
    await expect(
      this.licensingModule.connect(this.user1).setLicensingConfig(ipId2, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
   
    // Add multiple IPs to the group
    await expect(
      this.groupingModule.addIp(groupId, [ipId1, ipId2])
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    let containsIp1 = await this.ipAssetRegistry.containsIp(groupId, ipId1);
    expect(containsIp1).to.be.true;
    let containsIp2 = await this.ipAssetRegistry.containsIp(groupId, ipId2);
    expect(containsIp2).to.be.true;

    // Remove multiple IPs from the group
    await expect(
      this.groupingModule.removeIp(groupId, [ipId1, ipId2])
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    containsIp1 = await this.ipAssetRegistry.containsIp(groupId, ipId1);
    expect(containsIp1).to.be.false;
    containsIp2 = await this.ipAssetRegistry.containsIp(groupId, ipId2);
    expect(containsIp2).to.be.false;
  });

  it("Non-owner add IP to the group", async function () {
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
    await expect(
      this.licensingModule.setLicensingConfig(ipId, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    await expect(
      this.groupingModule.connect(this.user1).addIp(groupId, [ipId])
    ).to.be.revertedWithCustomError(this.errors, "AccessController__PermissionDenied");;

    const containsIp = await this.ipAssetRegistry.containsIp(groupId, ipId);
    expect(containsIp).to.be.false;
  });

  it("Non-owner remove IP from the group", async function () {
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
    await expect(
      this.licensingModule.setLicensingConfig(ipId, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    await expect(
      this.groupingModule.addIp(groupId, [ipId])
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    let containsIp = await this.ipAssetRegistry.containsIp(groupId, ipId);
    expect(containsIp).to.be.true;

    // Remove IP from the group
    await expect(
      this.groupingModule.connect(this.user1).removeIp(groupId, [ipId])
    ).to.be.revertedWithCustomError(this.errors, "AccessController__PermissionDenied");
    containsIp = await this.ipAssetRegistry.containsIp(groupId, ipId);
    expect(containsIp).to.be.true;
  });

  it("Add IP with none/different license term to the group", async function () {
    const { ipId } = await mintNFTAndRegisterIPA();
    // IP has no license term attached
    await expect(
      this.groupingModule.addIp(groupId, [ipId])
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__IpHasNoGroupLicenseTerms");

    // IP has different license term attached
    await expect(
      this.licensingModule.attachLicenseTerms(ipId, PILicenseTemplate, this.commericialUseLicenseId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    await expect(
      this.groupingModule.addIp(groupId, [ipId])
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__IpHasNoGroupLicenseTerms");
  });
});
