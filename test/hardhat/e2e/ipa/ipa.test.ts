// Test: IP Asset

import "../setup"
import { expect } from "chai"
import { mintNFT } from "../utils/nftHelper"
import hre from "hardhat";
import { MockERC721 } from "../constants";
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";

describe("IP Asset", function () {
  let signers:any;

  this.beforeAll("Get Signers", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners();   
  })

  it("NFT owner register IP Asset with an NFT token", async function () {
    const tokenId = await mintNFT(signers[0]);
    const connectedRegistry = this.ipAssetRegistry.connect(signers[0]);

    const ipId = await expect(
      connectedRegistry.register(this.chainId, MockERC721, tokenId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[2].args[0]);
    console.log("ipId:", ipId);

    expect(ipId).to.not.be.empty.and.to.be.a("HexString");

    const isRegistered = await expect(
      connectedRegistry.isRegistered(ipId)
    ).not.to.be.rejectedWith(Error);

    expect(isRegistered).to.equal(true);
  });

  it("Non-NFT owner register IP asset with an NFT token", async function () {
    const tokenId = await mintNFT(signers[0]);
    const connectedRegistry = this.ipAssetRegistry.connect(signers[1]);

    const ipId = await expect(
      connectedRegistry.register(this.chainId, MockERC721, tokenId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[2].args[0]);
    console.log("ipId:", ipId);

    expect(ipId).to.not.be.empty.and.to.be.a("HexString");

    const isRegistered = await expect(
      connectedRegistry.isRegistered(ipId)
    ).not.to.be.rejectedWith(Error);

    expect(isRegistered).to.equal(true);
  });

  it("Register IP asset, the caller doesn’t have enough IP token", async function () {
    const tokenId = await mintNFT(signers[0]);

    // generate random wallet
    const randomWallet = hre.ethers.Wallet.createRandom();
    const randomSigner = randomWallet.connect(hre.ethers.provider);
    const connectedRegistry = this.ipAssetRegistry.connect(randomSigner);

    await expect(
      connectedRegistry.register(this.chainId, MockERC721, tokenId)
    ).to.be.rejectedWith(`insufficient funds`, `"code": -32000, "message": "insufficient funds for gas * price + value: balance 0`);
  });

  it("Check the default license after registering IP asset", async function () {
    console.log("============ Register IPA ============");
    const { ipId } = await mintNFTAndRegisterIPA();

    console.log("============ Get Default License Terms ============");
    const { licenseTermsId: defaultId } = await this.licenseRegistry.getDefaultLicenseTerms();
    console.log("defaultId", defaultId);

    console.log("============ Get Attached License Terms ============");
    expect(await this.licenseRegistry.getAttachedLicenseTermsCount(ipId)).to.be.equal(0);
  });
});
