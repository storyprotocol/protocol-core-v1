// Test: Group Authorization

import { EvenSplitGroupPool } from "../constants";
import "../setup"
import { expect } from "chai"

describe("Grouping Module Authorization", function () {
  it("Non-admin whitelist group reward pool", async function () {
    await expect(
      this.groupingModule.connect(this.user1).whitelistGroupRewardPool(EvenSplitGroupPool, false)
    ).to.be.rejectedWith(Error).then((error) => { console.log(JSON.stringify(error, null, 2)), expect(error.data).to.contain("0x068ca9d8") });

    const isWhitelisted = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(EvenSplitGroupPool);
    expect(isWhitelisted).to.be.true;
  });

  it("Admin whitelist group reward pool", async function () {
    await expect(
      this.groupingModule.whitelistGroupRewardPool(EvenSplitGroupPool, false)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    let isWhitelisted = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(EvenSplitGroupPool);
    expect(isWhitelisted).to.be.false;

    await expect(
      this.groupingModule.whitelistGroupRewardPool(EvenSplitGroupPool, true)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    isWhitelisted = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(EvenSplitGroupPool);
    expect(isWhitelisted).to.be.true;
  });

  it("Admin whitelist invalid group reward pool", async function () {
    const invalidGroupPool = "0xDA5b9f185ac6b5b61BF84892d94BF1826984dA5A";
    await expect(
      this.groupingModule.whitelistGroupRewardPool(invalidGroupPool, true)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    let isWhitelisted = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(invalidGroupPool);
    expect(isWhitelisted).to.be.true;

    await expect(
      this.groupingModule.whitelistGroupRewardPool(invalidGroupPool, false)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    isWhitelisted = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(invalidGroupPool);
    expect(isWhitelisted).to.be.false;
  });
});

