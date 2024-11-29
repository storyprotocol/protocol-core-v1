import { expect } from "chai"
import { getIpAssetRegistry } from "../fixtures"
import { mintNFT } from "../utils/nftHelper"

describe.only("IPA", function () {
  it("Create ipa", async function () {

    const tokenId = await mintNFT();
    const ipaContract = await getIpAssetRegistry();
  
    const ipId = await expect(
      ipaContract.register(1315, "0x7411143ef90b7744fc8233f01cce0b2c379651b3", tokenId)
    ).not.to.be.rejectedWith(Error);

    console.log("ipa", ipId)

    const isRegistered = await expect(
      ipaContract.isRegistered(ipId)
    ).not.to.be.rejectedWith(Error)

    expect(isRegistered).to.equal(true)
    
    // const paused =  await ipaContract.paused();
    // const authority = await ipaContract.authority();
    // console.log("authority", authority);
    // assert that the value is correct
    // expect(paused).to.equal(false);
  })
})

