// Test: IPAccount - state update on asset changes

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";
import { MockERC721, PILicenseTemplate } from "../constants";

describe("IPAccount", function () {
  it("Update nonce state of IPAsset on asset changes", async function () {
    console.log("============ Register IP1 ============");
    const { tokenId: tokenId1, ipId: ipId1 } = await mintNFTAndRegisterIPA();
    console.log("IP1: ", ipId1);

    console.log("============ Get state of IP1 ============");
    const ipAccount1 = await this.ipAssetRegistry.ipAccount(this.chainId, MockERC721, tokenId1);
    console.log("IPAccount1: ", ipAccount1);
    const ipAccount1Contract = await hre.ethers.getContractAt("IPAccountImpl", ipAccount1);
    const state1 = await ipAccount1Contract.state();
    console.log("State of IP1: ", state1);

    console.log("============ Attach license to IP1 ============");
    await expect(
      this.licensingModule.attachLicenseTerms(ipId1, PILicenseTemplate, this.commericialRemixLicenseId)
    ).not.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log("============ Get state of IP1 after attaching license ============");
    const stateAfterLicense = await ipAccount1Contract.state();
    console.log("State of IP1 after attaching license: ", stateAfterLicense);
    expect(stateAfterLicense).to.not.equal(state1);

    console.log("============Register IP2 as IP1's derivative ============");
    const { tokenId: tokenId2, ipId: ipId2 } = await mintNFTAndRegisterIPA();
    console.log("IP2: ", ipId2);
    const ipAccount2 = await this.ipAssetRegistry.ipAccount(this.chainId, MockERC721, tokenId2);
    const ipAccount2Contract = await hre.ethers.getContractAt("IPAccountImpl", ipAccount2);
    const state2 = await ipAccount2Contract.state();
    console.log("State of IP2: ", state2);
    await expect(
      this.licensingModule.registerDerivative(ipId2, [ipId1], [this.commericialRemixLicenseId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log("============ Get state of IP2 after registering as derivative ============");
    const state2After = await ipAccount2Contract.state();
    console.log("State of IP2 after registering as derivative: ", state2After);
    expect(state2After).to.not.equal(state2);

    console.log("============ Mint License Token for IP1 ============");
    await expect(
      this.licensingModule.mintLicenseTokens(ipId1, PILicenseTemplate, this.commericialRemixLicenseId, 1, this.owner.address, "0x", 0, 0)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    console.log("============ Get state of IP1 after minting license token ============");
    const stateAfterMint = await ipAccount1Contract.state();
    console.log("State of IP1 after minting license token: ", stateAfterMint);
    expect(stateAfterMint).to.not.equal(stateAfterLicense);
  });
});