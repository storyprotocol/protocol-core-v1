// Test: Group Authorization

import { EvenSplitGroupPool } from "../constants";
import "../setup"
import { expect } from "chai";
import { executeWithEnvironmentExpectation, getCurrentEnvironment } from "../utils/environmentHelper";

describe("Grouping Module Authorization", function () {
  it("Non-admin whitelist group reward pool", async function () {
    await expect(
      this.groupingModule.connect(this.user1).whitelistGroupRewardPool(EvenSplitGroupPool, false)
    ).to.be.rejectedWith(Error).then((error) => { console.log(JSON.stringify(error, null, 2)), expect(error.data).to.contain("0x068ca9d8") });

    const isWhitelisted = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(EvenSplitGroupPool);
    expect(isWhitelisted).to.be.true;
  });

  it("Admin whitelist group reward pool", async function () {
    // Test whitelisting group reward pool with environment-aware expectations
    // In admin environments: should succeed
    // In non-admin environments: should fail with AccessControlUnauthorizedAccount error
    
    console.log("============ Testing Admin Whitelist Group Reward Pool ============");
    
    // Test disabling whitelist
    await executeWithEnvironmentExpectation(
      async () => {
        const tx = await this.groupingModule.whitelistGroupRewardPool(EvenSplitGroupPool, false);
        return await tx.wait();
      },
      "whitelistGroupRewardPool (disable)",
      'adminOperations'
    );

    // Only check state changes in admin environments where operation succeeds
    const env = getCurrentEnvironment();
    if (env.isAdminEnvironment) {
      let isWhitelisted = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(EvenSplitGroupPool);
      expect(isWhitelisted).to.be.false;

      // Test enabling whitelist
      await executeWithEnvironmentExpectation(
        async () => {
          const tx = await this.groupingModule.whitelistGroupRewardPool(EvenSplitGroupPool, true);
          return await tx.wait();
        },
        "whitelistGroupRewardPool (enable)",
        'adminOperations'
      );

      isWhitelisted = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(EvenSplitGroupPool);
      expect(isWhitelisted).to.be.true;
    } else {
      console.log("⚠️  Skipping state verification in non-admin environment - operations expected to fail");
    }
  });

  it("Admin whitelist invalid group reward pool", async function () {
    const invalidGroupPool = "0xDA5b9f185ac6b5b61BF84892d94BF1826984dA5A";
    
    console.log("============ Testing Admin Whitelist Invalid Group Reward Pool ============");
    
    // Test enabling whitelist for invalid pool
    await executeWithEnvironmentExpectation(
      async () => {
        const tx = await this.groupingModule.whitelistGroupRewardPool(invalidGroupPool, true);
        return await tx.wait();
      },
      "whitelistGroupRewardPool (enable invalid pool)",
      'adminOperations'
    );

    // Only check state changes in admin environments where operation succeeds
    const env = getCurrentEnvironment();
    if (env.isAdminEnvironment) {
      let isWhitelisted = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(invalidGroupPool);
      expect(isWhitelisted).to.be.true;

      // Test disabling whitelist for invalid pool
      await executeWithEnvironmentExpectation(
        async () => {
          const tx = await this.groupingModule.whitelistGroupRewardPool(invalidGroupPool, false);
          return await tx.wait();
        },
        "whitelistGroupRewardPool (disable invalid pool)",
        'adminOperations'
      );

      isWhitelisted = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(invalidGroupPool);
      expect(isWhitelisted).to.be.false;
    } else {
      console.log("⚠️  Skipping state verification in non-admin environment - operations expected to fail");
    }
  });
});

