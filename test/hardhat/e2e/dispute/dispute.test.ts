// Test: Dispute Flow

import hre from "hardhat";
import { expect } from "chai";
import "../setup"
import { mintNFTAndRegisterIPA, mintNFTAndRegisterIPAWithLicenseTerms } from "../utils/mintNFTAndRegisterIPA";
import { ethers, encodeBytes32String } from "ethers";
import { MockERC20, MockERC721, PILicenseTemplate, RoyaltyPolicyLAP } from "../constants";
import { terms } from "../licenseTermsTemplate";
import { getErc20Balance } from "../utils/erc20Helper";

const IMPROPER_REGISTRATION = encodeBytes32String("IMPROPER_REGISTRATION");
const arbitrationFee = 100;
const data = new ethers.AbiCoder().encode(["uint64", "address", "uint256"], [2595600, MockERC20, arbitrationFee]);

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
    console.log(`ipId: ${ipId}`);
    console.log(`this.user1: ${this.user1.address}`);

    const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
    const disputeId = await expect(
      this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, data)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then((receipt) => receipt.logs[5].args[0]);
    console.log("disputeId", disputeId);
    console.log("============ Raise Dispute END ============");

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
    let ipId: any;
    let disputeId: any;
    let disputeEvidenceHash: any;
    console.log("============ Register IP ============");
    try {
      const response = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialRemixLicenseId);
      ipId = response.ipId;
      console.log(`Successfully registered IP with ID: ${ipId}`);
    } catch (error) {
      console.error("Error registering IP:", error);
      throw error; // Rethrow to fail the test
    }
    console.log("============ Register IP END ============");

    console.log("============ Raise Dispute ============");
    try {
      disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      const tx = await this.disputeModule.connect(this.user1).raiseDispute(
        ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, data
      );
      
      console.log("Transaction sent! Hash:", tx.hash);
    
      // Capture the receipt
      const receipt = await tx.wait();
      console.log("Transaction confirmed! Receipt:", receipt);
    
      // Assertion on success
      await expect(Promise.resolve(receipt)).not.to.be.rejectedWith(Error);
    
      // Extract dispute ID if logs exist
      if (receipt.logs.length > 5) {
        disputeId = receipt.logs[5].args[0];
        console.log("Dispute raised successfully. Dispute ID:", disputeId);
      } else {
        console.warn("⚠️ Warning: Logs are empty or fewer than expected.");
      }
    
    } catch (error) {
      console.error("❌ Error raising dispute!");
    
      if (error.receipt) {
        console.error("Transaction Hash:", error.receipt.transactionHash);
        console.error("Block Number:", error.receipt.blockNumber);
        console.error("Transaction Logs:", error.receipt.logs);
      }
    
      if (error.reason) {
        console.error("Revert Reason:", error.reason);
      }
    
      console.error("🔴 Error Message:", error.message);
      console.error("📜 Error Data:", error.data || "No error data");
      console.error("Error Stack:", error.stack);
    
      throw error; // Ensure test failure
    }
    console.log("============ Raise Dispute END ============");
  
    console.log("============ Get Dispute ============");
    try {
      const dispute = await this.disputeModule.disputes(disputeId);
      console.log(`dispute: ${dispute}`);
      expect(dispute.targetIpId).to.equal(ipId);
      expect(dispute.disputeInitiator).to.equal(this.user1.address);
      console.log("Dispute details retrieved successfully.");
    } catch (error) {
      console.error("Error retrieving dispute:", error);
      throw error; // Rethrow to fail the test
    }
    console.log("============ Get Dispute END ============");
  
    console.log("============ Set Dispute Judgement ============");
    console.log("============ Set Dispute Judgement ============");

    try {
      // Send the transaction and get the transaction hash
      const tx = await this.disputeModule.setDisputeJudgement(disputeId, false, "0x");
      console.log("Transaction sent! Hash:", tx.hash);

      // Wait for transaction confirmation
      const receipt = await tx.wait();
      console.log("Transaction confirmed! Receipt:", receipt);

      console.log("✅ Dispute judgement set to false successfully.");
    } catch (error) {
      console.error("❌ Error setting dispute judgement!");
      console.error("🔍 Sender Address (msg.sender):", error.transaction?.from || "Unknown");

      // Log the transaction hash if available
      if (error.transactionHash) {
        console.error("🔗 Transaction Hash:", error.transactionHash);
      }

      // Log the transaction receipt if available
      if (error.receipt) {
        console.error("📜 Transaction Receipt:", error.receipt);
        if (error.receipt.logs) {
          console.error("📑 Transaction Logs:", error.receipt.logs);
        }
      }

      // Extract and log the revert reason
      if (error.data) {
        console.error("📜 Error Data:", error.data);
        const revertReason = decodeRevertReason(error.data);
        console.error("🔴 Revert Reason:", revertReason);
      }

      // Log generic error message and stack trace
      console.error("🔴 Error Message:", error.message);
      console.error("📜 Error Stack:", error.stack);

      throw error; // Ensure test failure
    }
    console.log("============ Set Dispute Judgement END ============");
  
    console.log("============ Check Is Ip Tagged ============");
    try {
      const isTagged = await this.disputeModule.isIpTagged(ipId);
      expect(isTagged).to.be.false;
      console.log("IP is not tagged, as expected.");
    } catch (error) {
      console.error("Error checking if IP is tagged:", error);
      throw error; // Rethrow to fail the test
    }
    console.log("============ Check Is Ip Tagged END ============");
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
    const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
    const disputeId = await expect(
      this.disputeModule.connect(this.user1).raiseDispute(rootIpId, disputeEvidenceHash, IMPROPER_REGISTRATION, data)
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
    const tx1 = await expect(
      this.disputeModule.connect(this.user2).tagIfRelatedIpInfringed(childIpId1, disputeId)
    ).not.to.be.rejectedWith(Error);
    console.log("Transaction sent! Hash:", tx1.hash);

    const receipt1 = await tx1.wait();
    const disputeIp1 = await this.disputeModule.disputeCounter();
    console.log("disputeCount after", disputeIp1);

    // Get the event from the transaction receipt
    const event1 = this.disputeModule.interface.parseLog(receipt1.logs[0]);
    console.log("event1", event1);
    expect(event1?.name).to.equal("IpTaggedOnRelatedIpInfringement");
    expect(event1?.args?.disputeId).to.equal(disputeIp1);
    expect(event1?.args?.infringingIpId).to.equal(rootIpId);
    expect(event1?.args?.ipIdToTag).to.equal(childIpId1);
    expect(event1?.args?.infringerDisputeId).to.equal(disputeId);
    expect(event1?.args?.tag).to.equal(IMPROPER_REGISTRATION);

    // Check if the derivative is tagged
    expect(await this.disputeModule.isIpTagged(childIpId1)).to.be.true;
    expect(await this.disputeModule.isIpTagged(childIpId2)).to.be.false;

    console.log("============ Tag Derivative 2 ============");
    const tx2 = await expect(
      this.disputeModule.connect(this.user2).tagIfRelatedIpInfringed(childIpId2, disputeIp1)
    ).not.to.be.rejectedWith(Error);
    console.log("Transaction sent! Hash:", tx2.hash);

    const receipt2 = await tx2.wait();
    const disputeIp2 = await this.disputeModule.disputeCounter();
    console.log("disputeCount after", disputeIp2);

    // Get the event from the transaction receipt
    const event2 = this.disputeModule.interface.parseLog(receipt2.logs[0]);
    console.log("event2", event2);
    expect(event2?.name).to.equal("IpTaggedOnRelatedIpInfringement");
    expect(event2?.args?.disputeId).to.equal(disputeIp2);
    expect(event2?.args?.infringingIpId).to.equal(childIpId1);
    expect(event2?.args?.ipIdToTag).to.equal(childIpId2);
    expect(event2?.args?.infringerDisputeId).to.equal(disputeIp1);
    expect(event2?.args?.tag).to.equal(IMPROPER_REGISTRATION);

    // Check if the derivative is tagged
    expect(await this.disputeModule.isIpTagged(childIpId1)).to.be.true;
    expect(await this.disputeModule.isIpTagged(childIpId2)).to.be.true;

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
    const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commercialUseLicenseId);

    console.log("============ Register derivative ============");
    const { ipId: childIpId } = await mintNFTAndRegisterIPA();
    await expect(
      this.licensingModule.registerDerivative(childIpId, [ipId], [this.commercialUseLicenseId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    
    console.log("============ Raise Dispute ============");
    const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
    const disputeId = await expect(
      this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, data)
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

  it("IPA dispute assertion", async function () {
    console.log("============ Register IP ============");
    const { tokenId, ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialRemixLicenseId);
    
    console.log("============ Construct UMA data ============");
    const abiCoder = new ethers.AbiCoder();
    const minLiveness = await this.arbitrationPolicyUMA.minLiveness();
    const data = abiCoder.encode(["uint64", "address", "uint256"], [minLiveness, MockERC20, 0]);
    console.log("data", data);
    
    console.log("============ Raise Dispute ============");
    const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
    const txRaiseDispute = await expect(
      this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, data)
    ).not.to.be.rejectedWith(Error);
    console.log("Transaction sent! Hash:", txRaiseDispute.hash);
    const receiptRaiseDispute = await txRaiseDispute.wait();
    const disputeId = receiptRaiseDispute.logs[5].args[0];
    console.log("disputeId", disputeId);
    const assertionId = await this.arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
    console.log("assertionId", assertionId);
    
    // Check the UMA event of raise dispute
    const eventRaiseDispute = this.arbitrationPolicyUMA.interface.parseLog(receiptRaiseDispute.logs[4]);
    console.log("eventRaiseDispute", eventRaiseDispute);
    expect(eventRaiseDispute?.name).to.equal("DisputeRaisedUMA");
    expect(eventRaiseDispute?.args?.disputeId).to.equal(disputeId);
    expect(eventRaiseDispute?.args?.assertionId).to.equal(assertionId);

    console.log("============ IPA Dispute Assertion ============");
    const ipAccount = await this.ipAssetRegistry.ipAccount(this.chainId, MockERC721, tokenId);
    console.log("tokenId:", tokenId, "ipId:", ipId, "ipAccount:", ipAccount);

    const ipAccountContract = await hre.ethers.getContractAt("IPAccountImpl", ipAccount);
    const assertionData = this.arbitrationPolicyUMA.interface.encodeFunctionData("disputeAssertion", [assertionId, encodeBytes32String("COUNTER_EVIDENCE_HASH")]);
    console.log("assertionData", assertionData);
    const toAddress = await this.arbitrationPolicyUMA.getAddress();
    console.log("toAddress", toAddress);
    const txAssertion =await expect(
      ipAccountContract.execute(toAddress, 0, assertionData)
    ).not.to.be.rejectedWith(Error);
    console.log("Transaction sent! Hash:", txAssertion.hash);

    // Check the UMA event of dispute assertion 
    const receiptAssertion = await txAssertion.wait();
    const eventAssertion = this.arbitrationPolicyUMA.interface.parseLog(receiptAssertion.logs[5]);
    console.log("eventAssertion", eventAssertion);
    expect(eventAssertion?.name).to.equal("AssertionDisputed");
    expect(eventAssertion?.args?.disputeId).to.equal(disputeId);
    expect(eventAssertion?.args?.assertionId).to.equal(assertionId);
  });

  describe("Dispute negative operations", function () {
    let ipId: string;
    let disputeId: bigint;

    before(async function () {
      console.log("============ Register IP ============");
      ({ ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commercialUseLicenseId));

      console.log("============ Raise Dispute ============");
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      disputeId = await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, data)
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
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHash, encodeBytes32String("INVALID_TAG"), data)
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__NotWhitelistedDisputeTag");
    });

    it("Raise dispute less than minLiveness should revert", async function () {
      const liveness = await this.arbitrationPolicyUMA.minLiveness() - 1n;
      const data = new ethers.AbiCoder().encode(["uint64", "address", "uint256"], [liveness, MockERC20, 100]);
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, data)
      ).to.be.revertedWithCustomError(this.errors, "ArbitrationPolicyUMA__LivenessBelowMin");
    });

    it("Raise dispute greater than minLiveness should revert", async function () {
      const liveness = await this.arbitrationPolicyUMA.maxLiveness() + 1n;
      const data = new ethers.AbiCoder().encode(["uint64", "address", "uint256"], [liveness, MockERC20, 100]);
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, data)
      ).to.be.revertedWithCustomError(this.errors, "ArbitrationPolicyUMA__LivenessAboveMax");
    });

    it("Raise dispute greater than maxBonds should revert", async function () {
      const bonds = await this.arbitrationPolicyUMA.maxBonds(MockERC20) + 1n;
      const data = new ethers.AbiCoder().encode(["uint64", "address", "uint256"], [2595600, MockERC20, bonds]);
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, data)
      ).to.be.revertedWithCustomError(this.errors, "ArbitrationPolicyUMA__BondAboveMax");
    });

    it("Raise dispute with evidence hash which already used should revert", async function () {
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash()
      console.log("✅ Generated a new evidence hash and using it to raise a dispute (should pass)");
      await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, data)
      ).not.to.be.rejectedWith(Error)

      console.log("🔁 Reusing the same evidence hash to raise a dispute (should revert)");

      console.log("============ Register IP ============");
      ({ ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commercialUseLicenseId))
      console.log(`ipId: ${ipId}`)

      console.log("🚨 Expecting dispute to revert due to EvidenceHashAlreadyUsed")

      await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, data)
      )
        .to.be.revertedWithCustomError(this.errors, "DisputeModule__EvidenceHashAlreadyUsed")
        .catch((error) => {
          console.error("❌ Test failed unexpectedly!")

          if (error.data) {
            console.error("📜 Error Data:", error.data)
            try {
              const revertReason = decodeRevertReason(error.data)
              console.error("🔴 Decoded Revert Reason:", revertReason)
            } catch (decodeError) {
              console.error("⚠️ Failed to decode revert reason:", decodeError)
            }
          }

          console.error("🔴 Error Message:", error.message)
          console.error("Error Stack:", error.stack)

          throw error // Ensure test failure
        })
    })
  });

  describe("Raise Dispute On Behalf - Normal Operations", function () {
    it("Should successfully raise dispute on behalf with valid dispute initiator", async function () {
      const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commercialUseLicenseId);
      const disputeInitiator = this.user2.address;
      const caller = this.user1;
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      console.log("============ Raise Dispute On Behalf ============");
      console.log(`ipId: ${ipId}`);
      console.log(`caller: ${caller.address}`);
      console.log(`disputeInitiator: ${disputeInitiator}`);

      // balance of caller before raising dispute
      const callerBalanceBefore = await getErc20Balance(caller.address);
      console.log(`Caller balance before: ${callerBalanceBefore}`);

      // balance of dispute initiator before raising dispute
      const disputeInitiatorBalanceBefore = await getErc20Balance(disputeInitiator);
      console.log(`Dispute initiator balance before: ${disputeInitiatorBalanceBefore}`);
      
      const tx = await this.disputeModule.connect(caller).raiseDisputeOnBehalf(
        ipId, 
        disputeInitiator, 
        disputeEvidenceHash, 
        IMPROPER_REGISTRATION, 
        data
      );
      
      const receipt = await tx.wait();
      const disputeId = receipt.logs[5].args[0];
      
      console.log("disputeId", disputeId);
      
      // Verify dispute details
      const dispute = await this.disputeModule.disputes(disputeId);
      expect(dispute.targetIpId).to.equal(ipId);
      expect(dispute.disputeInitiator).to.equal(disputeInitiator); // Should be user2
      expect(dispute.disputeTimestamp).to.be.greaterThan(0);
      expect(dispute.arbitrationPolicy).to.equal(await this.disputeModule.baseArbitrationPolicy());
      expect(dispute.disputeEvidenceHash).to.equal(disputeEvidenceHash);
      expect(dispute.targetTag).to.equal(IMPROPER_REGISTRATION);
      expect(dispute.currentTag).to.equal(encodeBytes32String("IN_DISPUTE"));
      expect(dispute.infringerDisputeId).to.equal(0);
      
      // Verify event emission with separate caller and dispute initiator
      const disputeRaisedEvent = receipt.logs.find(log => {
        try {
          const parsed = this.disputeModule.interface.parseLog(log);
          return parsed?.name === "DisputeRaised";
        } catch {
          return false;
        }
      });
      
      expect(disputeRaisedEvent).to.not.be.undefined;
      const parsedEvent = this.disputeModule.interface.parseLog(disputeRaisedEvent);
      expect(parsedEvent.args.caller).to.equal(caller.address); // Caller should be user1
      expect(parsedEvent.args.disputeInitiator).to.equal(disputeInitiator); // Initiator should be user2

      // balance of caller after raising dispute  
      const callerBalanceAfter = await getErc20Balance(caller.address);
      console.log(`Caller balance after raising dispute: ${callerBalanceAfter}`);

      // balance of dispute initiator after raising dispute
      const disputeInitiatorBalanceAfter = await getErc20Balance(disputeInitiator);
      console.log(`Dispute initiator balance after raising dispute: ${disputeInitiatorBalanceAfter}`);

      // caller should have paid the arbitration fee
      expect(callerBalanceBefore - callerBalanceAfter).to.equal(arbitrationFee);
      // dispute initiator should not change
      expect(disputeInitiatorBalanceAfter).to.equal(disputeInitiatorBalanceBefore);
    });

    it("Should only allow dispute initiator to resolve dispute after judgement", async function () {
      const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commercialUseLicenseId);
      const disputeInitiator = this.user2; // user2 is the dispute initiator
      const caller = this.user1; // user1 pays the fees
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      console.log("============ Raise Dispute On Behalf ============");
      console.log(`ipId: ${ipId}`);
      console.log(`caller: ${caller.address}`);
      console.log(`disputeInitiator: ${disputeInitiator.address}`);

      // Raise dispute on behalf
      const tx = await this.disputeModule.connect(caller).raiseDisputeOnBehalf(
        ipId, 
        disputeInitiator.address, 
        disputeEvidenceHash, 
        IMPROPER_REGISTRATION, 
        data
      );
      
      const receipt = await tx.wait();
      const disputeId = receipt.logs[5].args[0];
      console.log("disputeId", disputeId);

      // Set dispute judgement to true (dispute wins)
      console.log("============ Set Dispute Judgement ============");
      await this.disputeModule.setDisputeJudgement(disputeId, true, "0x");
      
      // Only dispute initiator should be able to resolve (not the caller who paid)
      console.log("============ Resolve Dispute (should revert) ============");
      await expect(
        this.disputeModule.connect(caller).resolveDispute(disputeId, "0x")
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__NotDisputeInitiator");

      // sleep 10 seconds
      await new Promise(resolve => setTimeout(resolve, 10000));

      console.log("============ Resolve Dispute (should succeed) ============");
      // The actual dispute initiator should be able to resolve
      await expect(
        this.disputeModule.connect(disputeInitiator).resolveDispute(disputeId, "0x")
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
      
      // Verify dispute is resolved
      console.log("============ Verify Dispute Resolved ============");
      const dispute = await this.disputeModule.disputes(disputeId);
      expect(dispute.currentTag).to.equal("0x0000000000000000000000000000000000000000000000000000000000000000");
    });
  });

  describe("Raise Dispute On Behalf - Error Cases", function () {
    let ipId: string;

    before(async function () {
      console.log("============ Register IP for raiseDisputeOnBehalf error tests ============");
      ({ ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commercialUseLicenseId));
    });

    it("Should revert when raising dispute on behalf with already used evidence hash", async function () {
      const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commercialUseLicenseId);
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      // random fake user address
      const fakeUser = hre.ethers.Wallet.createRandom().address;

      console.log("First dispute");
      // First dispute should succeed
      await expect(
        this.disputeModule.connect(this.user1).raiseDisputeOnBehalf(
          ipId, 
          this.user2.address, 
          disputeEvidenceHash, 
          IMPROPER_REGISTRATION, 
          data
        )
      ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

      console.log("Second dispute");

      // Second dispute with same evidence hash should fail
      await expect(
        this.disputeModule.connect(this.user1).raiseDisputeOnBehalf(
          ipId, 
          fakeUser, // Different dispute initiator
          disputeEvidenceHash, // Same evidence hash
          IMPROPER_REGISTRATION, 
          data
        )
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__EvidenceHashAlreadyUsed");
    });

    it("Should revert when dispute initiator is zero address", async function () {
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      await expect(
        this.disputeModule.connect(this.user1).raiseDisputeOnBehalf(
          ipId, 
          ethers.ZeroAddress, // Zero address as dispute initiator
          disputeEvidenceHash, 
          IMPROPER_REGISTRATION, 
          data
        )
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__InvalidDisputeInitiator");
    });

    it("Should revert when dispute initiator is the target IP", async function () {
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      await expect(
        this.disputeModule.connect(this.user1).raiseDisputeOnBehalf(
          ipId, 
          ipId, // Target IP as dispute initiator
          disputeEvidenceHash, 
          IMPROPER_REGISTRATION, 
          data
        )
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__InvalidDisputeInitiator");
    });

    it("Should revert when raising dispute on behalf with non-whitelisted tag", async function () {
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      await expect(
        this.disputeModule.connect(this.user1).raiseDisputeOnBehalf(
          ipId, 
          this.user2.address, 
          disputeEvidenceHash, 
          encodeBytes32String("NOT_WHITELISTED"), // Non-whitelisted tag
          data
        )
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__NotWhitelistedDisputeTag");
    });

    it("Should revert when raising dispute on behalf with liveness below minimum", async function () {
      const liveness = await this.arbitrationPolicyUMA.minLiveness() - 1n;
      const invalidData = new ethers.AbiCoder().encode(["uint64", "address", "uint256"], [liveness, MockERC20, 100]);
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      await expect(
        this.disputeModule.connect(this.user1).raiseDisputeOnBehalf(
          ipId, 
          this.user2.address, 
          disputeEvidenceHash, 
          IMPROPER_REGISTRATION, 
          invalidData
        )
      ).to.be.revertedWithCustomError(this.errors, "ArbitrationPolicyUMA__LivenessBelowMin");
    });

    it("Should revert when raising dispute on behalf with liveness above maximum", async function () {
      const liveness = await this.arbitrationPolicyUMA.maxLiveness() + 1n;
      const invalidData = new ethers.AbiCoder().encode(["uint64", "address", "uint256"], [liveness, MockERC20, 100]);
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      await expect(
        this.disputeModule.connect(this.user1).raiseDisputeOnBehalf(
          ipId, 
          this.user2.address, 
          disputeEvidenceHash, 
          IMPROPER_REGISTRATION, 
          invalidData
        )
      ).to.be.revertedWithCustomError(this.errors, "ArbitrationPolicyUMA__LivenessAboveMax");
    });

    it("Should revert when raising dispute on behalf with bonds above maximum", async function () {
      const bonds = await this.arbitrationPolicyUMA.maxBonds(MockERC20) + 1n;
      const invalidData = new ethers.AbiCoder().encode(["uint64", "address", "uint256"], [2595600, MockERC20, bonds]);
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      await expect(
        this.disputeModule.connect(this.user1).raiseDisputeOnBehalf(
          ipId, 
          this.user2.address, 
          disputeEvidenceHash, 
          IMPROPER_REGISTRATION, 
          invalidData
        )
      ).to.be.revertedWithCustomError(this.errors, "ArbitrationPolicyUMA__BondAboveMax");
    });

    it("Should revert when raising dispute on behalf with zero evidence hash", async function () {
      await expect(
        this.disputeModule.connect(this.user1).raiseDisputeOnBehalf(
          ipId, 
          this.user2.address, 
          ethers.ZeroHash, // Zero evidence hash
          IMPROPER_REGISTRATION, 
          data
        )
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__ZeroDisputeEvidenceHash");
    });

    it("Should revert when raising dispute on behalf with unregistered IP", async function () {
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      const unregisteredIpId = "0x1234567890123456789012345678901234567890"; // Fake IP address
      
      await expect(
        this.disputeModule.connect(this.user1).raiseDisputeOnBehalf(
          unregisteredIpId, 
          this.user2.address, 
          disputeEvidenceHash, 
          IMPROPER_REGISTRATION, 
          data
        )
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__NotRegisteredIpId");
    });
  });
});

function generateUniqueDisputeEvidenceHash() {
  console.error("⚠️ The evidence hash shall be unique...");
  const uniqueHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes(`unique-${Date.now()}`));
  console.log(`🆕 Generated unique dispute evidence hash: ${uniqueHash}`);
  return uniqueHash;
}

function decodeRevertReason(errorData: ethers.BytesLike) {
  const iface = new hre.ethers.Interface([
    "error DisputeModule__ZeroAccessManager()",
    "error DisputeModule__ZeroLicenseRegistry()",
    "error DisputeModule__ZeroIPAssetRegistry()",
    "error DisputeModule__ZeroAccessController()",
    "error DisputeModule__ZeroIPGraphACL()",
    "error DisputeModule__ZeroArbitrationPolicy()",
    "error DisputeModule__ZeroDisputeTag()",
    "error DisputeModule__NotAllowedToWhitelist()",
    "error DisputeModule__ZeroDisputeEvidenceHash()",
    "error DisputeModule__NotWhitelistedArbitrationPolicy()",
    "error DisputeModule__CannotBlacklistBaseArbitrationPolicy()",
    "error DisputeModule__NotArbitrationRelayer()",
    "error DisputeModule__NotWhitelistedDisputeTag()",
    "error DisputeModule__NotDisputeInitiator()",
    "error DisputeModule__NotInDisputeState()",
    "error DisputeModule__NotAbleToResolve()",
    "error DisputeModule__NotRegisteredIpId()",
    "error DisputeModule__DisputeWithoutInfringementTag()",
    "error DisputeModule__NotDerivativeOrGroupIp()",
    "error DisputeModule__DisputeAlreadyPropagated()",
    "error DisputeModule__RelatedDisputeNotResolved()",
    "error DisputeModule__ZeroArbitrationPolicyCooldown()",
    "error DisputeModule__EvidenceHashAlreadyUsed()",
    "error DisputeModule__InvalidDisputeInitiator()"
  ]);

  try {
    const decoded = iface.parseError(errorData);
    return decoded?.name || "Unknown Revert Reason";
  } catch (err) {
    return "Revert reason could not be decoded";
  }
}