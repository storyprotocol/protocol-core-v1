// Test: Group IP Asset

import "../setup"
import { expect } from "chai"
import { EvenSplitGroupPool, PILicenseTemplate, RoyaltyPolicyLRP, MockERC20 } from "../constants"
import { mintNFTAndRegisterIPA, mintNFTAndRegisterIPAWithLicenseTerms, registerGroupIPA } from "../utils/mintNFTAndRegisterIPA";
import { LicensingConfig, registerPILTerms } from "../utils/licenseHelper";
import hre from "hardhat";

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

    console.log("============ Group Set Licensing Config ============");
    const groupLicensingConfig = { ...LicensingConfig };
    groupLicensingConfig.expectGroupRewardPool = hre.ethers.ZeroAddress;
    await expect(
      this.licensingModule.setLicensingConfig(groupId, PILicenseTemplate, commRemixTermsId, groupLicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
  });

  it("Add/Remove an IP to the group", async function () {
    // Register IP
    console.log("============ Register IP ============");
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
    await expect(
      this.licensingModule.setLicensingConfig(ipId, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    // Add IP to the group
    console.log("============ Add IP to group ============");
    await expect(
      this.groupingModule.addIp(groupId, [ipId], 20 * 10 ** 6)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    
    
    let containsIp = await this.ipAssetRegistry.containsIp(groupId, ipId);
    expect(containsIp).to.be.true;

    // Remove IP from the group
    console.log("============ Remove IP from group ============");
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
      this.groupingModule.addIp(groupId, [ipId1, ipId2], 20 * 10 ** 6)
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
      this.groupingModule.connect(this.user1).addIp(groupId, [ipId], 20 * 10 ** 6)
    ).to.be.revertedWithCustomError(this.errors, "AccessController__PermissionDenied");

    const containsIp = await this.ipAssetRegistry.containsIp(groupId, ipId);
    expect(containsIp).to.be.false;
  });

  it("Non-owner remove IP from the group", async function () {
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
    await expect(
      this.licensingModule.setLicensingConfig(ipId, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    await expect(
      this.groupingModule.addIp(groupId, [ipId], 20 * 10 ** 6)
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
      this.groupingModule.addIp(groupId, [ipId], 20 * 10 ** 6)
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__IpHasNoGroupLicenseTerms");

    console.log(`IP has different license term attached START`);
    console.log(`this.commercialUseLicenseId: ${this.commercialUseLicenseId}`);
    // IP has different license term attached
    try {
      const tx = await this.licensingModule.attachLicenseTerms(
        ipId,
        PILicenseTemplate,
        this.commercialUseLicenseId
      );
      await tx.wait();
    } catch (error) {
      console.error("❌ Error attachLicenseTerms!");

      // Log the transaction hash if available
      if (error.transactionHash) {
        console.error("🔗 Transaction Hash:", error.transactionHash);
      }

      // Log the transaction receipt if available
      if (error.receipt) {
        console.error("📜 Transaction Receipt:", error.receipt);
        if (error.receipt.logs) {
          console.error("📑 Transaction Logs:", error.receipt.logs);
        }
      }

      // Extract and log the revert reason
      if (error.data) {
        console.error("📜 Error Data:", error.data);
        // const revertReason = decodeRevertReason(error.data);
        // console.error("🔴 Revert Reason:", revertReason);
      }

      // Log generic error message and stack trace
      console.error("🔴 Error Message:", error.message);
      console.error("📜 Error Stack:", error.stack);

      throw error; // Ensure test failure
    }

    await expect(
      this.groupingModule.addIp(groupId, [ipId], 20 * 10 ** 6)
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__IpHasNoGroupLicenseTerms");
  });
});

describe("Group is locked due to registered derivative", function () {
  let groupId: any;
  let commRemixTermsId: any;
  let ipId1: any;
  let ipId2: any;

  before(async function () {
    // Register group
    commRemixTermsId = await registerPILTerms(true, 0, 10 * 10 ** 6, RoyaltyPolicyLRP);
    const groupLicensingConfig = { ...LicensingConfig };
    groupLicensingConfig.expectGroupRewardPool = hre.ethers.ZeroAddress;
    groupId = await registerGroupIPA(EvenSplitGroupPool, commRemixTermsId, groupLicensingConfig);

    // Register IP
    console.log("============ Register IP1 ============");
    ({ ipId: ipId1 } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId, this.user1, this.user1));
    await expect(
      this.licensingModule.connect(this.user1).setLicensingConfig(ipId1, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    // Add IP to the group
    console.log("============ Add Ips to group ============");
    await expect(
      this.groupingModule.addIp(groupId, [ipId1], 20 * 10 ** 6)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    expect(
      await this.evenSplitGroupPool.getTotalIps(groupId)
    ).to.be.equal(1);

    // Register derivative IP
    console.log("============ Register IP2 ============");
    ({ ipId: ipId2 } = await mintNFTAndRegisterIPA(this.user2, this.user2));
    await expect(
      this.licensingModule.connect(this.user2).registerDerivative(ipId2, [groupId], [commRemixTermsId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
  });

  it("Add Ip to locked group", async function () {
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
    await expect(
      this.licensingModule.setLicensingConfig(ipId, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    await expect(
      this.groupingModule.addIp(groupId, [ipId], 20 * 10 ** 6)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
  });

  it("Remove Ip from locked group", async function () {
    await expect(
      this.groupingModule.removeIp(groupId, [ipId1])
    ).to.be.revertedWithCustomError(this.errors, "GroupingModule__GroupFrozenDueToHasDerivativeIps");
  });
});

describe("Group is locked due to minted license token", function () {
  let groupId: any;
  let commRemixTermsId: any;
  let ipId1: any;

  before(async function () {
    // Register group
    commRemixTermsId = await registerPILTerms(true, 0, 10 * 10 ** 6, RoyaltyPolicyLRP);
    const groupLicensingConfig = { ...LicensingConfig };
    groupLicensingConfig.expectGroupRewardPool = hre.ethers.ZeroAddress;
    groupId = await registerGroupIPA(EvenSplitGroupPool, commRemixTermsId, groupLicensingConfig);

    // Register IP
    console.log("============ Register IP1 ============");
    ({ ipId: ipId1 } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId, this.user1, this.user1));
    await expect(
      this.licensingModule.connect(this.user1).setLicensingConfig(ipId1, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    // Add IP to the group
    console.log("============ Add Ips to group ============");
    await expect(
      this.groupingModule.addIp(groupId, [ipId1], 20 * 10 ** 6)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    expect(
      await this.evenSplitGroupPool.getTotalIps(groupId)
    ).to.be.equal(1);

    // Mint license token
    console.log("============ Group mint license token ============");
    await expect(
      this.licensingModule.mintLicenseTokens(groupId, PILicenseTemplate, commRemixTermsId, 1, this.owner.address, "0x", 0, 0)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
  });

  it("Revert when mint license tokens for terms that aren't attached to it ", async function () {
    // create a new license terms
    const noAttachedlicenseTermsId = await registerPILTerms(true, 0, 20 * 10 ** 6, RoyaltyPolicyLRP, 0, MockERC20, true);

    await expect(
      this.licensingModule.mintLicenseTokens(groupId, PILicenseTemplate, noAttachedlicenseTermsId, 1, this.owner.address, "0x", 0, 0)
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__LicensorIpHasNoLicenseTerms");
  });

  it("Add Ip to locked group", async function () {
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);
    await expect(
      this.licensingModule.setLicensingConfig(ipId, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    await expect(
      this.groupingModule.addIp(groupId, [ipId], 20 * 10 ** 6)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
  });

  it("Remove Ip from locked group", async function () {
    await expect(
      this.groupingModule.removeIp(groupId, [ipId1])
    ).to.be.revertedWithCustomError(this.errors, "GroupingModule__GroupFrozenDueToAlreadyMintLicenseTokens");
  });
});

describe("Add IP to group - negative tests", function () {
  let groupId: any;
  let licenseTermsId: any;

  before(async function () {
    console.log("============ Register License Terms ============");
    const expiration = 6000;
    licenseTermsId = await registerPILTerms(true, 0, 10 * 10 ** 6, RoyaltyPolicyLRP, expiration);
    const groupLicensingConfig = { ...LicensingConfig };
    groupLicensingConfig.expectGroupRewardPool = hre.ethers.ZeroAddress;

    console.log("============ Register Group IPA ============");
    groupId = await registerGroupIPA(EvenSplitGroupPool, licenseTermsId, groupLicensingConfig);
  });

  it("Shall not add IP to group if IP have an expiration time", async function () {
    console.log("============ Register IP ============");
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(licenseTermsId);

    const { ipId: childIpId } = await mintNFTAndRegisterIPA(this.user1, this.user1);
    await expect(
      this.licensingModule.connect(this.user1).registerDerivative(childIpId, [ipId], [licenseTermsId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    console.log("============ IP Attach License Config ============");
    await expect(
      this.licensingModule.connect(this.user1).setLicensingConfig(childIpId, PILicenseTemplate, licenseTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    console.log("============ Add IP to group ============");
    await expect(
      this.groupingModule.addIp(groupId, [childIpId], 20 * 10 ** 6)
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__CannotAddIpWithExpirationToGroup");
  });

  it("Shall not add IP to group if IP does not share the same licensing terms as the group", async function () {
    console.log("============ Register IP ============");
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialRemixLicenseId, this.user1, this.user1);

    console.log("============ IP Attach License Config ============");
    await expect(
      this.licensingModule.connect(this.user1).setLicensingConfig(ipId, PILicenseTemplate, this.commericialRemixLicenseId, LicensingConfig)
    ).to.be.revertedWithCustomError(this.errors, "LicensingModule__LicensingConfigMintingFeeBelowLicenseTerms");

    console.log("============ Add IP to group ============");
    await expect(
      this.groupingModule.addIp(groupId, [ipId], 20 * 10 ** 6)
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__IpHasNoGroupLicenseTerms");
  });

  it("Shall not add non-exist IP to group", async function () {
    const ipId = "0xEc6Cc0941818B0F5c142C4d366a5Befa3CA4C634";

    console.log("============ Add IP to group ============");
    await expect(
      this.groupingModule.addIp(groupId, [ipId], 20 * 10 ** 6)
    ).to.be.revertedWithCustomError(this.errors, "GroupIPAssetRegistry__NotRegisteredIP");
  });
});

describe("Register Group and attach license terms", function () {
  it("Register Group and attach license terms", async function () {
    const groupId = await expect(
      this.groupingModule.registerGroup(EvenSplitGroupPool)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[5].args[0]);

    console.log("groupId", groupId)
    expect(groupId).to.be.properHex(40);

    // register license terms
    const trueLicenseTermsId = await registerPILTerms(true, 0, 10 * 10 ** 6, RoyaltyPolicyLRP, 0, MockERC20, true, true);
    console.log("licenseTermsId of derivativesApproval true:", trueLicenseTermsId);

    const falseLicenseTermsId = await registerPILTerms(true, 0, 10 * 10 ** 6, RoyaltyPolicyLRP, 0, MockERC20, true);
    console.log("licenseTermsId of derivativesApproval false:", falseLicenseTermsId);

    // attach license terms to group
    await expect(
      this.licensingModule.attachLicenseTerms(groupId, PILicenseTemplate, falseLicenseTermsId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    await expect(
      this.licensingModule.attachLicenseTerms(groupId, PILicenseTemplate, trueLicenseTermsId)
    ).to.be.revertedWithCustomError(this.errors, "LicenseRegistry__GroupIpAlreadyHasLicenseTerms");
  });
});
