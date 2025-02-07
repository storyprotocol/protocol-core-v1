// Test: Group IP Asset Royalty Distribution

import "../setup"
import { expect } from "chai"
import { EvenSplitGroupPool, MockERC20, PILicenseTemplate, RoyaltyPolicyLRP } from "../constants"
import { LicensingConfig, registerPILTerms } from "../utils/licenseHelper";
import { mintNFTAndRegisterIPA, mintNFTAndRegisterIPAWithLicenseTerms, registerGroupIPA } from "../utils/mintNFTAndRegisterIPA";
import { getErc20Balance } from "../utils/erc20Helper";
import hre from "hardhat";

describe("Group IP Asset Royalty Distribution", function () {
  let groupId: any;
  let commRemixTermsId: any;
  let ipId1: any;
  let ipId2: any;
  
  let rewardPoolBalanceBefore: any;
  let ip1BalanceBefore: any;
  let ip2BalanceBefore: any;

  before(async function () {
    // Register group
    console.log("============ Register Group ============");
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

    console.log("============ Register IP2 ============");
    ({ ipId: ipId2 } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId, this.user2, this.user2));
    await expect(
      this.licensingModule.connect(this.user2).setLicensingConfig(ipId2, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    // Add IP to the group
    console.log("============ Add IPs to group ============");
    await expect(
      this.groupingModule.addIp(groupId, [ipId1, ipId2], 20 * 10 ** 6)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    expect(
      await this.evenSplitGroupPool.getTotalIps(groupId)
    ).to.be.equal(2);
  });

  it("Group royalties even split by member IPs", async function () {
    // Register drivative IP
    console.log("============ Register Derivative IP3 ============");
    const {ipId: ipId3} = await mintNFTAndRegisterIPA();
    await expect(
      this.licensingModule.registerDerivative(ipId3, [groupId], [commRemixTermsId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    rewardPoolBalanceBefore = await getErc20Balance(EvenSplitGroupPool);

    // Pay royalty to IP3
    console.log("============ Pay rayalty to IP3 ============");
    await expect(
      this.royaltyModule.payRoyaltyOnBehalf(ipId3, ipId3, MockERC20, 1000)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    // console.log("============ Transfer to vault ============");
    await expect(
      this.royaltyPolicyLRP.transferToVault(ipId3, groupId, MockERC20)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    // Collect royalty 
    console.log("============ Collect royalty ============");
    await expect(
      this.groupingModule.collectRoyalties(groupId, MockERC20)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    
    // Check reward pool balance after royalty collection
    expect(
      await getErc20Balance(EvenSplitGroupPool)
    ).to.be.equal(rewardPoolBalanceBefore + 100n);

    // Get claimable
    console.log("============ Get claimable ============");
    const claimableIp1 = await expect(
      this.groupingModule.connect(this.user1).getClaimableReward(groupId, MockERC20, [ipId1])
    ).not.to.be.rejectedWith(Error);
    console.log("IP1 claimable", claimableIp1);
    const claimableIp2 = await expect(
      this.groupingModule.connect(this.user2).getClaimableReward(groupId, MockERC20, [ipId2])
    ).not.to.be.rejectedWith(Error);
    console.log("IP2 claimable", claimableIp2);

    // Mint license token to trigger vault creation 
    console.log("============ Mint license token ============");
    await expect(
      this.licensingModule.mintLicenseTokens(ipId1, PILicenseTemplate, commRemixTermsId, 1, this.owner.address, "0x", 0, 0)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    await expect(
      this.licensingModule.mintLicenseTokens(ipId2, PILicenseTemplate, commRemixTermsId, 1, this.owner.address, "0x", 0, 0)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    const vaultIp1 = await this.royaltyModule.ipRoyaltyVaults(ipId1);
    console.log("vaultIp1", vaultIp1);
    const vaultIp2 = await this.royaltyModule.ipRoyaltyVaults(ipId2);
    console.log("vaultIp2", vaultIp2);

    ip1BalanceBefore = await getErc20Balance(vaultIp1);
    ip2BalanceBefore = await getErc20Balance(vaultIp2);

    console.log("============ IP1 claim rewards ============");
    await expect(
      this.groupingModule.connect(this.user1).claimReward(groupId, MockERC20, [ipId1])
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    console.log("============ IP2 claim rewards ============");
    await expect(
      this.groupingModule.connect(this.user2).claimReward(groupId, MockERC20, [ipId2])
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    console.log("============ Check the balance after claim rewards ============");
    const rewardPoolBalance = await getErc20Balance(EvenSplitGroupPool);
    const ip1Balance = await getErc20Balance(vaultIp1);
    const ip2Balance = await getErc20Balance(vaultIp2);
    expect(rewardPoolBalance).to.be.equal(rewardPoolBalanceBefore);
    expect(ip1Balance).to.be.equal(ip1BalanceBefore + 50n);
    expect(ip2Balance).to.be.equal(ip2BalanceBefore + 50n);
  });
});

describe("Non-Owner/Member Claim Group Royalty", function () {
  let groupId: any;
  let commRemixTermsId: any;
  let ipId1: any;
  let ipId2: any;

  before(async function () {
    // Register group
    console.log("============ Register Group ============");
    commRemixTermsId = await registerPILTerms(true, 0, 10 * 10 ** 6, RoyaltyPolicyLRP);
    const groupLicensingConfig = { ...LicensingConfig };
    groupLicensingConfig.expectGroupRewardPool = hre.ethers.ZeroAddress;
    groupId = await registerGroupIPA(EvenSplitGroupPool, commRemixTermsId, groupLicensingConfig);

    // Register IP
    console.log("============ Register IP1 ============");
    ({ ipId: ipId1 } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId));
    await expect(
      this.licensingModule.setLicensingConfig(ipId1, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    console.log("============ Register IP2 ============");
    ({ ipId: ipId2 } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId, this.user2, this.user2));
    await expect(
      this.licensingModule.connect(this.user2).setLicensingConfig(ipId2, PILicenseTemplate, commRemixTermsId, LicensingConfig)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    // Add IP to the group
    console.log("============ Add IPs to group ============");
    await expect(
      this.groupingModule.addIp(groupId, [ipId1, ipId2], 20 * 10 ** 6)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    expect(
      await this.evenSplitGroupPool.getTotalIps(groupId)
    ).to.be.equal(2);

    // Mint license token
    console.log("============ Mint license token ============");
    await expect(
      this.licensingModule.mintLicenseTokens(groupId, PILicenseTemplate, commRemixTermsId, 1, this.owner.address, "0x", 0, 0)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    await expect(
      this.licensingModule.mintLicenseTokens(ipId1, PILicenseTemplate, commRemixTermsId, 1, this.owner.address, "0x", 0, 0)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    await expect(
      this.licensingModule.mintLicenseTokens(ipId2, PILicenseTemplate, commRemixTermsId, 1, this.owner.address, "0x", 0, 0)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
  });

  it("Non-Owner/Member collects group royalties", async function () {
    // Pay royalty
    console.log("============ Pay royalty to group ============");
    await expect(
      this.royaltyModule.payRoyaltyOnBehalf(groupId, this.owner.address, MockERC20, 100)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    const rewardPoolBalanceBefore = await getErc20Balance(EvenSplitGroupPool);

    console.log("============ Collect royalty ============");
    await expect(
      this.groupingModule.connect(this.user1).collectRoyalties(groupId, MockERC20)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    // Check reward pool balance after royalty collection
    expect(
      await getErc20Balance(EvenSplitGroupPool)
    ).to.be.equal(rewardPoolBalanceBefore + 100n);

    const vaultIp1 = await this.royaltyModule.ipRoyaltyVaults(ipId1);
    const vaultIp2 = await this.royaltyModule.ipRoyaltyVaults(ipId2);
    const ip1BalanceBefore = await getErc20Balance(vaultIp1);
    const ip2BalanceBefore = await getErc20Balance(vaultIp2);
    
    console.log("============ Claim rewards ============");
    await expect(
      this.groupingModule.connect(this.user1).claimReward(groupId, MockERC20, [ipId1, ipId2])
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    expect(
      await getErc20Balance(EvenSplitGroupPool)
    ).to.be.equal(rewardPoolBalanceBefore);
    expect(
      await getErc20Balance(vaultIp1)
    ).to.be.equal(ip1BalanceBefore + 50n);
    expect(
      await getErc20Balance(vaultIp2)
    ).to.be.equal(ip2BalanceBefore + 50n);
  });
});
