// Test: Dispute Flow

import { expect } from "chai";
import "../setup"
import { mintNFTAndRegisterIPA, mintNFTAndRegisterIPAWithLicenseTerms } from "../utils/mintNFTAndRegisterIPA";
import { ethers, encodeBytes32String } from "ethers";
import { MockERC20, PILicenseTemplate, RoyaltyPolicyLAP } from "../constants";
import { terms } from "../licenseTermsTemplate";

const disputeEvidenceHashExample = "0xb7b94ecbd1f9f8cb209909e5785fb2858c9a8c4b220c017995a75346ad1b5db5";
const IMPROPER_REGISTRATION = encodeBytes32String("IMPROPER_REGISTRATION");
const data = new ethers.AbiCoder().encode(["uint64", "address", "uint256"], [2595600, MockERC20, 100]);

describe("Dispute Flow", function () {
  it("Raise dispute for an IP asset, set judgement to true", async function () {
    console.log("============ Register IP ============");
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialRemixLicenseId);
    
    console.log("============ Construct UMA data ============");
    const abiCoder = new ethers.AbiCoder();
    const minLiveness = await this.arbitrationPolicyUMA.minLiveness();
    const data = abiCoder.encode(["uint64", "address", "uint256"], [minLiveness, MockERC20, 0]);
    console.log("data", data);
    
    console.log("============ Raise Dispute ============");
    const disputeId = await expect(
      this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHashExample, IMPROPER_REGISTRATION, data)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[5].args[0]);
    console.log("disputeId", disputeId);

    console.log("============ Get Dispute ============");
    const dispute = await this.disputeModule.disputes(disputeId);
    expect(dispute.targetIpId).to.equal(ipId);
    expect(dispute.disputeInitiator).to.equal(this.user1.address);

    console.log("============ Set Dispute Judgement ============");
    await expect(
      this.disputeModule.setDisputeJudgement(disputeId, true, "0x")
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    console.log("============ Check Is Ip Tagged ============");
    expect(await this.disputeModule.isIpTagged(ipId)).to.be.true;

    console.log("============ Resolve Dispute ============");
    await expect(
      this.disputeModule.connect(this.user1).resolveDispute(disputeId, "0x")
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    console.log("============ Check Is Ip Tagged After Resolve ============");
    expect(await this.disputeModule.isIpTagged(ipId)).to.be.false;
  });

  it("Raise dispute for an IP asset, set judgement to false", async function () {
    console.log("============ Register IP ============");
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialRemixLicenseId);
    
    console.log("============ Raise Dispute ============");
    const disputeId = await expect(
      this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHashExample, IMPROPER_REGISTRATION, data)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[5].args[0]);
    console.log("disputeId", disputeId);

    console.log("============ Get Dispute ============");
    const dispute = await this.disputeModule.disputes(disputeId);
    expect(dispute.targetIpId).to.equal(ipId);
    expect(dispute.disputeInitiator).to.equal(this.user1.address);

    console.log("============ Set Dispute Judgement ============");
    await expect(
      this.disputeModule.setDisputeJudgement(disputeId, false, "0x")
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    console.log("============ Check Is Ip Tagged ============");
    expect(await this.disputeModule.isIpTagged(ipId)).to.be.false;
  });

  it("Set tags to the derivative IP assets if the parent infringed", async function () {
    const testTerms = { ...terms };
    testTerms.commercialUse = true;
    testTerms.commercialRevShare = 10 * 10 ** 6;
    testTerms.royaltyPolicy = RoyaltyPolicyLAP;
    testTerms.derivativesReciprocal = true;
    testTerms.currency = MockERC20;

    console.log("============ Register license terms ============")
    await expect(
      this.licenseTemplate.registerLicenseTerms(testTerms)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    const commRemixTermsId = await this.licenseTemplate.getLicenseTermsId(testTerms);
    console.log("Commercial-remix licenseTermsId: ", commRemixTermsId);

    console.log("============ Register root IP ============")
    const { ipId: rootIpId } = await mintNFTAndRegisterIPAWithLicenseTerms(commRemixTermsId);

    console.log("============ Register derivative from root ============")
    const { ipId: childIpId1 } = await mintNFTAndRegisterIPA(this.user2, this.user2);
    await expect(
      this.licensingModule.connect(this.user2).registerDerivative(childIpId1, [rootIpId], [commRemixTermsId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log("============ Register derivative from child 1 ============")
    const { ipId: childIpId2 } = await mintNFTAndRegisterIPA();
    await expect(
      this.licensingModule.registerDerivative(childIpId2, [childIpId1], [commRemixTermsId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    
    console.log("============ Raise Dispute ============");
    const disputeId = await expect(
      this.disputeModule.connect(this.user1).raiseDispute(rootIpId, disputeEvidenceHashExample, IMPROPER_REGISTRATION, data)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[5].args[0]);
    console.log("disputeId", disputeId);

    console.log("============ Set Dispute Judgement ============");
    await expect(
      this.disputeModule.setDisputeJudgement(disputeId, true, "0x")
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    console.log("============ Check Is Root Ip Tagged ============");
    expect(await this.disputeModule.isIpTagged(rootIpId)).to.be.true;

    console.log("============ Check Is Derivative Ip Tagged ============");
    expect(await this.disputeModule.isIpTagged(childIpId1)).to.be.false;
    expect(await this.disputeModule.isIpTagged(childIpId2)).to.be.false;

    console.log("============ Tag Derivative 1 ============");
    let disputeCounter = await this.disputeModule.disputeCounter();
    console.log("disputeCount before", disputeCounter);
    await expect(
      this.disputeModule.connect(this.user2).tagIfRelatedIpInfringed(childIpId1, disputeId)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    expect(await this.disputeModule.isIpTagged(childIpId1)).to.be.true;
    expect(await this.disputeModule.isIpTagged(childIpId2)).to.be.false;
    const disputeIp1 = await this.disputeModule.disputeCounter();
    console.log("disputeCount after", disputeIp1);

    console.log("============ Tag Derivative 2 ============");
    await expect(
      this.disputeModule.connect(this.user2).tagIfRelatedIpInfringed(childIpId2, disputeIp1)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    expect(await this.disputeModule.isIpTagged(childIpId1)).to.be.true;
    expect(await this.disputeModule.isIpTagged(childIpId2)).to.be.true;
    const disputeIp2 = await this.disputeModule.disputeCounter();
    console.log("disputeCount after", disputeIp2);

    console.log("============ Resolve Dispute for root IP ============");
    await expect(
      this.disputeModule.connect(this.user1).resolveDispute(disputeId, "0x")
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    expect(await this.disputeModule.isIpTagged(rootIpId)).to.be.false;

    console.log("============ Resolve Dispute for derivative 1 ============");
    await expect(
      this.disputeModule.connect(this.user2).resolveDispute(disputeIp1, "0x")
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    expect(await this.disputeModule.isIpTagged(childIpId1)).to.be.false;

    console.log("============ Resolve Dispute for derivative 2 ============");
    await expect(
      this.disputeModule.connect(this.user2).resolveDispute(disputeIp2, "0x")
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    expect(await this.disputeModule.isIpTagged(childIpId2)).to.be.false;
  });

  it("Set tags to the derivative IP assets if the parent has not infringed", async function () {
    console.log("============ Register IP ============");
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialUseLicenseId);

    console.log("============ Register derivative ============");
    const { ipId: childIpId } = await mintNFTAndRegisterIPA();
    await expect(
      this.licensingModule.registerDerivative(childIpId, [ipId], [this.commericialUseLicenseId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    
    console.log("============ Raise Dispute ============");
    const disputeId = await expect(
      this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHashExample, IMPROPER_REGISTRATION, data)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[5].args[0]);
    console.log("disputeId", disputeId);

    console.log("============ Set Dispute Judgement ============");
    await expect(
      this.disputeModule.setDisputeJudgement(disputeId, false, "0x")
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    console.log("============ Tag Derivative ============");
    await expect(
      this.disputeModule.connect(this.user2).tagIfRelatedIpInfringed(ipId, disputeId)
    ).to.be.revertedWithCustomError(this.errors, "DisputeModule__DisputeWithoutInfringementTag");
    expect(await this.disputeModule.isIpTagged(childIpId)).to.be.false;
  });

  describe("Dispute negative operations", function () {
    let ipId: string;
    let disputeId: bigint;

    before(async function () {
      console.log("============ Register IP ============");
      ({ ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialUseLicenseId));

      console.log("============ Raise Dispute ============");
      disputeId = await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHashExample, IMPROPER_REGISTRATION, data)
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[5].args[0]);
      console.log("disputeId", disputeId);
    });

    it("Resolve dispute before set judgement to true", async function () {
      await expect(
        this.disputeModule.connect(this.user1).resolveDispute(disputeId, "0x")
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__NotAbleToResolve");
    });
    
    it("Cancel a dispute, UMA policy should revert", async function () {
      await expect(
        this.disputeModule.connect(this.user1).cancelDispute(disputeId, "0x")
      ).to.be.revertedWithCustomError(this.errors, "ArbitrationPolicyUMA__CannotCancel");
    });

    it("Non-ArbitrationRelayer should not set dipsute judgement", async function () {
      await expect(
        this.disputeModule.connect(this.user1).setDisputeJudgement(disputeId, true, "0x")
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__NotArbitrationRelayer");
    });

    it("Set dipsute judgement twice should revert", async function () {
      await expect(
        this.disputeModule.setDisputeJudgement(disputeId, true, "0x")
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
      await expect(
        this.disputeModule.setDisputeJudgement(disputeId, true, "0x")
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__NotInDisputeState");
    });

    it("Non-Initiator resolve dispute should revert", async function () {
      await expect(
        this.disputeModule.resolveDispute(disputeId, "0x")
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__NotDisputeInitiator");
    });

    it("Raise dispute with non-whitelisted tag should revert", async function () {
      await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHashExample, encodeBytes32String("INVALID_TAG"), data)
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__NotWhitelistedDisputeTag");
    });

    it("Raise dispute less than minLiveness should revert", async function () {
      const liveness = await this.arbitrationPolicyUMA.minLiveness() - 1n;
      const data = new ethers.AbiCoder().encode(["uint64", "address", "uint256"], [liveness, MockERC20, 100]);
      await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHashExample, IMPROPER_REGISTRATION, data)
      ).to.be.revertedWithCustomError(this.errors, "ArbitrationPolicyUMA__LivenessBelowMin");
    });

    it("Raise dispute greater than minLiveness should revert", async function () {
      const liveness = await this.arbitrationPolicyUMA.maxLiveness() + 1n;
      const data = new ethers.AbiCoder().encode(["uint64", "address", "uint256"], [liveness, MockERC20, 100]);
      await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHashExample, IMPROPER_REGISTRATION, data)
      ).to.be.revertedWithCustomError(this.errors, "ArbitrationPolicyUMA__LivenessAboveMax");
    });

    it("Raise dispute greater than maxBonds should revert", async function () {
      const bonds = await this.arbitrationPolicyUMA.maxBonds(MockERC20) + 1n;
      const data = new ethers.AbiCoder().encode(["uint64", "address", "uint256"], [2595600, MockERC20, bonds]);
      await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHashExample, IMPROPER_REGISTRATION, data)
      ).to.be.revertedWithCustomError(this.errors, "ArbitrationPolicyUMA__BondAboveMax");
    });
  });
});