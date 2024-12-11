// Test: Group Authorization

import { EvenSplitGroupPool } from "../constants";
import "../setup"
import { expect } from "chai"

describe("Grouping Module Authorization", function () {
  it("Non-admin whitelist group reward pool", async function () {
    await expect(
      this.groupingModule.connect(this.user1).whitelistGroupRewardPool(EvenSplitGroupPool, false)
    ).to.be.rejectedWith(Error);

    const isWhitelisted = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(EvenSplitGroupPool);
    expect(isWhitelisted).to.be.true;
  });
});

