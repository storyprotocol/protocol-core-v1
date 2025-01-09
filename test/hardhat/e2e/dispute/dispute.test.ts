// Test: Dispute Flow

import { expect } from "chai";
import "../setup"
import { mintNFTAndRegisterIPAWithLicenseTerms } from "../utils/mintNFTAndRegisterIPA";
import { ethers, encodeBytes32String } from "ethers";
import { MockERC20 } from "../constants";

const disputeEvidenceHashExample = "0xb7b94ecbd1f9f8cb209909e5785fb2858c9a8c4b220c017995a75346ad1b5db5";
const IMPROPER_REGISTRATION = encodeBytes32String("IMPROPER_REGISTRATION"); 

describe.skip("Dispute Flow", function () {
  it("Raise dispute", async function () {
    console.log("============ Register IP ============");
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialRemixLicenseId);
    
    console.log("============ Construct UMA data ============");
    const abiCoder = new ethers.AbiCoder();
    const data = abiCoder.encode(["bytes", "uint64", "address", "uint256", "bytes32"],
      [Buffer.from("test claim abc"), 2592000, MockERC20, 100, encodeBytes32String("ASSERT_TRUTH")]);
    console.log("data", data);
    
    console.log("============ Raise Dispute ============");
    await expect(
      this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHashExample, IMPROPER_REGISTRATION, data)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
  });
});