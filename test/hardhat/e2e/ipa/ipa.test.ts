import "../setup"
import { expect } from "chai"
import { mintNFT } from "../utils/nftHelper"

describe("IP Asset", function () {
  it("Create ipa", async function () {

    const tokenId = await mintNFT();
    const ipId = await expect(
      this.ipAssetRegistry.register(1315, "0x7411143ef90b7744fc8233f01cce0b2c379651b3", tokenId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[2].args[0]);

    console.log("ipId", ipId)

    const isRegistered = await expect(
      this.ipAssetRegistry.isRegistered(ipId)
    ).not.to.be.rejectedWith(Error)

    expect(isRegistered).to.equal(true)
    
    // const paused =  await ipaContract.paused();
    // const authority = await ipaContract.authority();
    // console.log("authority", authority);
    // assert that the value is correct
    // expect(paused).to.equal(false);
  })

  it("get ipa", async function () {
    const paused =  await this.ipAssetRegistry.paused();
    expect(paused).to.equal(false);
  })
})

