// Test: Permission

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
    const ALLOW_permission = 1;
    const DENY_permission = 2;
    let permissionAfter: number;
    let result: any;

    const ipId = await expect(
      connectedRegistry.register(this.chainId, MockERC721, tokenId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[2].args[0]);
    console.log("ipId:", ipId);
    expect(ipId).to.not.be.empty.and.to.be.a("HexString");

    const connecedAccessController = this.accessController.connect(signers[0]);

    const permissionBefore = await connecedAccessController.getPermission(ipId, signers[0].address, LicensingModule, func);
    expect(permissionBefore).to.equal(0);

    // add ALLOW permission
    result = await connecedAccessController.setPermission(ipId, signers[0].address, LicensingModule, func, ALLOW_permission);
    expect(result.hash).to.not.be.empty.and.to.be.a("HexString");
    await result.wait();

    // check the permission
    permissionAfter = await connecedAccessController.getPermission(ipId, signers[0].address, LicensingModule, func);
    expect(permissionAfter).to.equal(ALLOW_permission);

    // Change to DENY permission
    result = await connecedAccessController.setPermission(ipId, signers[0].address, LicensingModule, func, DENY_permission);
    expect(result.hash).to.not.be.empty.and.to.be.a("HexString");
    await result.wait();

    // check the permission
    permissionAfter = await connecedAccessController.getPermission(ipId, signers[0].address, LicensingModule, func);
    expect(permissionAfter).to.equal(DENY_permission);
  });
});