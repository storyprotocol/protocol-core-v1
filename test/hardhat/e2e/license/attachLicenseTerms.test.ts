import "../setup";
import { expect } from "chai";
import { network } from "hardhat";
import hre from "hardhat";
import { MockERC20, MockERC721, PILicenseTemplate, RoyaltyPolicyLAP, RoyaltyPolicyLRP } from "../constants";
import { mintNFT } from "../utils/nftHelper";

const terms = {
  transferable: true,
  royaltyPolicy: hre.ethers.ZeroAddress,
  defaultMintingFee: 0,
  expiration: 0,
  commercialUse: false,
  commercialAttribution: false,
  commercializerChecker: hre.ethers.ZeroAddress,
  commercializerCheckerData: hre.ethers.ZeroAddress,
  commercialRevShare: 0,
  commercialRevCeiling: 0,
  derivativesAllowed: true,
  derivativesAttribution: false,
  derivativesApproval: false,
  derivativesReciprocal: false,
  derivativeRevCeiling: 0,
  currency: hre.ethers.ZeroAddress,
  uri: "",
};

describe("Attach license terms", function () {
  let signers: any;
  let chainId: number;

  this.beforeAll("Get Signers", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners();
    const networkConfig = network.config;
    chainId = networkConfig.chainId || 1516;
    console.log(chainId);
  });

  it("IP Asset attach a license except for default one", async function () {
    const tokenId = await mintNFT(signers[0].address);
    const connectedRegistry = this.ipAssetRegistry.connect(signers[0]);

    const ipId = await expect(
      connectedRegistry.register(1315, MockERC721, tokenId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[2].args[0]);
    console.log("ipId:", ipId);
    expect(ipId).to.not.be.empty.and.to.be.a("HexString");

    const connectedLicensingModule = this.licensingModule.connect(signers[0]);
    console.log(this.nonCommericialLicenseId);

    const attachLicenseTx = await expect(
      connectedLicensingModule.attachLicenseTerms(ipId, PILicenseTemplate, this.commericialUseLicenseId)
    ).not.to.be.rejectedWith(Error);
    console.log(attachLicenseTx.hash);
    expect(attachLicenseTx.hash).to.not.be.empty.and.to.be.a("HexString");
  });
});
