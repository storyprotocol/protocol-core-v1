import "../setup"
import { expect } from "chai"
import { mintNFT } from "../utils/nftHelper"
import hre from "hardhat";
import { LicensingModule, MockERC721 } from "../constants";

describe("Permission", function () {
  let signers:any;

  this.beforeAll("Get Signers", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners();  
    console.log("signers:", signers[0].address);
  })

  it("Add a new ALLOW permission of IP asset for an signer and change the permission to DENY", async function () {
    const tokenId = await mintNFT(signers[0].address);
    const connectedRegistry = this.ipAssetRegistry.connect(signers[0]);
    const func = hre.ethers.encodeBytes32String("attachLicenseTerms").slice(0, 10);
    console.log(func);
    const ALLOW_permission = 1;
    const DENY_permission = 2;

    const ipId = await expect(
      connectedRegistry.register(this.chainId, MockERC721, tokenId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[2].args[0]);
    console.log("ipId:", ipId);
    expect(ipId).to.not.be.empty.and.to.be.a("HexString");

    const connecedAccessController = this.accessController.connect(signers[0]);

    const permissionBefore = await connecedAccessController.getPermission(ipId, signers[0].address, LicensingModule, func);
    console.log("permissionBefore:", permissionBefore);
    expect(permissionBefore).to.equal(0);

    // add ALLOW permission
    const result1 = await connecedAccessController.setPermission(ipId, signers[0].address, LicensingModule, func, ALLOW_permission);
    expect(result1.hash).to.not.be.empty.and.to.be.a("HexString");
    await result1.wait();

    // get the permission
    const permissionAfter1 = await connecedAccessController.getPermission(ipId, signers[0].address, LicensingModule, func);
    console.log("permissionAfter:", permissionAfter1);
    expect(permissionAfter1).to.equal(ALLOW_permission);

    // Change to DENY permission
    const result2 = await connecedAccessController.setPermission(ipId, signers[0].address, LicensingModule, func, DENY_permission);
    expect(result2.hash).to.not.be.empty.and.to.be.a("HexString");
    await result2.wait();

    // get the permission
    const permissionAfter2 = await connecedAccessController.getPermission(ipId, signers[0].address, LicensingModule, func);
    console.log("permissionAfter:", permissionAfter2);
    expect(permissionAfter2).to.equal(DENY_permission);
  });
});