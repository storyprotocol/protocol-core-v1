// Test: IP Asset Metadata

import "../setup"
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";
import { encodeBytes32String } from "ethers";
import { expect } from "chai";

describe("IP Asset Set Metadata", function () {
  let ipId: string;
  before("Register IPA", async function () {
    console.log(`================= Register IPA =================`);
    ({ ipId } = await mintNFTAndRegisterIPA());
  });
  
  it("Update NFT token URI", async function() {
    console.log(`================= Update NFT token URI =================`);
    const newNFTMetadataHash = encodeBytes32String("test-nft-metadata-hash");
    await expect(
      this.coreMetadataModule.updateNftTokenURI(ipId, newNFTMetadataHash)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log(`================= Get NftMetadataHash =================`);
    const nftMetadataHash = await expect(
      this.CoreMetadataViewModule.getNftMetadataHash(ipId)
    ).not.to.be.rejectedWith(Error);
    expect(nftMetadataHash).to.equal(nftMetadataHash);
  });

  it("Set Metadata URI", async function() {
    console.log(`================= Set Metadata URI =================`);
    const newMetaURI = "https://ipfs/bafkreiguk57p";
    const newMetaHash = encodeBytes32String("test-metadata-hash");
    await expect(
      this.coreMetadataModule.setMetadataURI(ipId, newMetaURI, newMetaHash)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log(`================= Get MetadataHash =================`);
    const metadataHash = await expect(
      this.CoreMetadataViewModule.getMetadataHash(ipId)
    ).not.to.be.rejectedWith(Error);
    expect(metadataHash).to.equal(newMetaHash);

    console.log(`================= Get MetadataURI =================`);
    const metadataURI = await expect(
      this.CoreMetadataViewModule.getMetadataURI(ipId)
    ).not.to.be.rejectedWith(Error);
    expect(metadataURI).to.equal(newMetaURI);
  });

  it("Update metadata after freeze metadata", async function() {
    console.log(`================= Freeze metadata =================`);
    await expect(
      this.coreMetadataModule.freezeMetadata(ipId)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log(`================= Update metadata after freeze metadata =================`);
    const newMetaURI = "https://ipfs/bafkreiguk99p";
    const newMetaHash = encodeBytes32String("test-metadata-hash-freeze");
    await expect(
      this.coreMetadataModule.setMetadataURI(ipId, newMetaURI, newMetaHash)
    ).to.be.revertedWithCustomError(this.errors, "CoreMetadataModule__MetadataAlreadyFrozen");

    console.log(`================= Update metadata after freeze metadata =================`);
    const newNFTMetadataHash = encodeBytes32String("test-nft-metadata-hash-freeze");
    await expect(
      this.coreMetadataModule.updateNftTokenURI(ipId, newNFTMetadataHash)
    ).to.be.revertedWithCustomError(this.errors, "CoreMetadataModule__MetadataAlreadyFrozen");
  });
});
