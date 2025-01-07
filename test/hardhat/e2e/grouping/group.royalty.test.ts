// Test: Group IP Asset Royalty Distribution

import "../setup";
import { expect } from "chai";
import {
  EvenSplitGroupPool,
  MockERC20,
  PILicenseTemplate,
  RoyaltyPolicyLAP,
} from "../constants";
import {
  LicensingConfig,
  registerPILTerms,
} from "../utils/licenseHelper";
import {
  mintNFTAndRegisterIPA,
  mintNFTAndRegisterIPAWithLicenseTerms,
} from "../utils/mintNFTAndRegisterIPA";
import { getErc20Balance } from "../utils/erc20Helper";

describe("Group IP Asset Royalty Distribution", function () {
  let groupId, commRemixTermsId, ipId1, ipId2, rewardPoolBalanceBefore;

  const setupGroupAndIPs = async (users) => {
    groupId = await this.groupingModule
      .registerGroup(EvenSplitGroupPool)
      .then((tx) => tx.wait())
      .then((receipt) => receipt.logs[5].args[0]);

    commRemixTermsId = await registerPILTerms(true, 0, 10e6, RoyaltyPolicyLAP);
    await this.licensingModule
      .attachLicenseTerms(groupId, PILicenseTemplate, commRemixTermsId)
      .then((tx) => tx.wait());

    [ipId1, ipId2] = await Promise.all(
      users.map(async (user) => {
        const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(
          commRemixTermsId,
          user,
          user
        );
        await this.licensingModule
          .connect(user)
          .setLicensingConfig(ipId, PILicenseTemplate, commRemixTermsId, LicensingConfig)
          .then((tx) => tx.wait());
        return ipId;
      })
    );

    await this.groupingModule
      .addIp(groupId, [ipId1, ipId2])
      .then((tx) => tx.wait());
    expect(await this.evenSplitGroupPool.getTotalIps(groupId)).to.equal(2);
  };

  before(async function () {
    await setupGroupAndIPs([this.user1, this.user2]);
  });

  it("distributes royalties evenly among member IPs", async function () {
    const { ipId: ipId3 } = await mintNFTAndRegisterIPA();

    await this.licensingModule
      .registerDerivative(ipId3, [groupId], [commRemixTermsId], PILicenseTemplate, "0x", 0, 100e6)
      .then((tx) => tx.wait());

    rewardPoolBalanceBefore = await getErc20Balance(EvenSplitGroupPool);

    await this.royaltyModule
      .payRoyaltyOnBehalf(ipId3, ipId3, MockERC20, 1000)
      .then((tx) => tx.wait());

    await this.royaltyPolicyLAP
      .transferToVault(ipId3, groupId, MockERC20)
      .then((tx) => tx.wait());

    await this.groupingModule
      .collectRoyalties(groupId, MockERC20)
      .then((tx) => tx.wait());

    expect(await getErc20Balance(EvenSplitGroupPool)).to.equal(
      rewardPoolBalanceBefore + 100n
    );

    const claimable = await Promise.all(
      [ipId1, ipId2].map((ipId, index) =>
        this.groupingModule
          .connect(index === 0 ? this.user1 : this.user2)
          .getClaimableReward(groupId, MockERC20, [ipId])
      )
    );
    console.log("Claimable Rewards:", claimable);

    const vaults = await Promise.all(
      [ipId1, ipId2].map((ipId) =>
        this.royaltyModule.ipRoyaltyVaults(ipId)
      )
    );

    const balancesBefore = await Promise.all(
      vaults.map((vault) => getErc20Balance(vault))
    );

    await Promise.all(
      [this.user1, this.user2].map((user, index) =>
        this.groupingModule
          .connect(user)
          .claimReward(groupId, MockERC20, [index === 0 ? ipId1 : ipId2])
          .then((tx) => tx.wait())
      )
    );

    const balancesAfter = await Promise.all(
      vaults.map((vault) => getErc20Balance(vault))
    );

    balancesBefore.forEach((balance, index) => {
      expect(balancesAfter[index]).to.equal(balance + 50n);
    });
  });
});
