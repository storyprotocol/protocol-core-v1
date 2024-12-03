// Test: Group IP Asset

import "../setup"
import { expect } from "chai"
import { EvenSplitGroupPool } from "../constants"

describe("Group IPA", function () {
  it("Register Group IPA with whitelisted group pool", async function () {

    const groupId = await expect(
      this.groupingModule.registerGroup(EvenSplitGroupPool)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[5].args[0]);

    console.log("groupId", groupId)
    expect(groupId).to.be.properHex(40);
  });

  it("Register Group IPA with non-whitelisted group pool", async function () {
    const nonWhitelistedGroupPool = "0xC384B56fD62d6679Cd62A2fE0dA3fe4560f33300"
    await expect(
      this.groupingModule.registerGroup(nonWhitelistedGroupPool)
    ).to.be.rejectedWith(Error)
  });
});
