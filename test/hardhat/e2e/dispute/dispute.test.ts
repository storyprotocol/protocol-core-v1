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

describe("Dispute Flow", function () {
  describe("Raise dispute for an IP asset, set judgement to true", function () {
    step("Register IP asset", async function () {
      const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialRemixLicenseId);
      this.ipId = ipId;
    });
        
    step("Raise dispute", async function () {
      // Construct UMA data
      const abiCoder = new ethers.AbiCoder();
      const minLiveness = await this.arbitrationPolicyUMA.minLiveness();
      const minimumBond = this.minimumBond;
      this.data = abiCoder.encode(["uint64", "address", "uint256"], [minLiveness, MockERC20, minimumBond]);
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      this.disputeId = await expect(
        this.disputeModule.connect(this.user1).raiseDispute(this.ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, this.data)
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then(extractDisputeId(this.disputeModule, this.arbitrationPolicyUMA));
    });

    step("Verify dispute details", async function () {
      const dispute = await this.disputeModule.disputes(this.disputeId);
      expect(dispute.targetIpId).to.equal(this.ipId);
      expect(dispute.disputeInitiator).to.equal(this.user1.address);
    });

    step("Set dispute judgement to true", async function () {
      await expect(
        this.disputeModule.setDisputeJudgement(this.disputeId, true, "0x")
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    });

    step("Verify IP is tagged after judgement", async function () {
      expect(await this.disputeModule.isIpTagged(this.ipId)).to.be.true;
    });

    step("Resolve dispute", async function () {
      await expect(
        this.disputeModule.connect(this.user1).resolveDispute(this.disputeId, "0x")
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    });

    step("Verify IP is untagged after resolve dispute", async function () {
      expect(await this.disputeModule.isIpTagged(this.ipId)).to.be.false;
    });
  });

  describe("Raise dispute for an IP asset, set judgement to false", function () {
    step("Register IP asset", async function () {
      const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialRemixLicenseId);
      this.ipId = ipId;
    });
        
    step("Raise dispute", async function () {
      // Construct UMA data
      const abiCoder = new ethers.AbiCoder();
      const minLiveness = await this.arbitrationPolicyUMA.minLiveness();
      const minimumBond = this.minimumBond;
      this.data = abiCoder.encode(["uint64", "address", "uint256"], [minLiveness, MockERC20, minimumBond]);
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      this.disputeId = await expect(
        this.disputeModule.connect(this.user1).raiseDispute(this.ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, this.data)
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then(extractDisputeId(this.disputeModule, this.arbitrationPolicyUMA));
    });

    step("Verify dispute details", async function () {
      const dispute = await this.disputeModule.disputes(this.disputeId);
      expect(dispute.targetIpId).to.equal(this.ipId);
      expect(dispute.disputeInitiator).to.equal(this.user1.address);
    });

    step("Set dispute judgement to false", async function () {
      await expect(
        this.disputeModule.setDisputeJudgement(this.disputeId, false, "0x")
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    });

    step("Verify IP is not tagged after false judgement", async function () {
      expect(await this.disputeModule.isIpTagged(this.ipId)).to.be.false;
    });

    step("Resolve dispute", async function () {
      await expect(
        this.disputeModule.connect(this.user1).resolveDispute(this.disputeId, "0x")
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    });

    step("Verify IP remains untagged after resolve dispute", async function () {
      expect(await this.disputeModule.isIpTagged(this.ipId)).to.be.false;
    });
  });

  describe("Set tags to the derivative IP assets if the parent infringed", function () {
    step("Setup license terms and register root IP", async function () {
      const testTerms = { ...terms };
      testTerms.commercialUse = true;
      testTerms.commercialRevShare = 10 * 10 ** 6;
      testTerms.royaltyPolicy = RoyaltyPolicyLAP;
      testTerms.derivativesReciprocal = true;
      testTerms.currency = MockERC20;

      await expect(
        this.licenseTemplate.registerLicenseTerms(testTerms)
      ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
      this.commRemixTermsId = await this.licenseTemplate.getLicenseTermsId(testTerms);
      
      const { ipId: rootIpId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commRemixTermsId);
      this.rootIpId = rootIpId;
    });

    step("Register derivative IPs", async function () {
      const { ipId: childIpId1 } = await mintNFTAndRegisterIPA(this.user2, this.user2);
      await expect(
        this.licensingModule.connect(this.user2).registerDerivative(childIpId1, [this.rootIpId], [this.commRemixTermsId], PILicenseTemplate, "0x", 0, 100e6, 0)
      ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
      this.childIpId1 = childIpId1;

      const { ipId: childIpId2 } = await mintNFTAndRegisterIPA();
      await expect(
        this.licensingModule.registerDerivative(childIpId2, [this.childIpId1], [this.commRemixTermsId], PILicenseTemplate, "0x", 0, 100e6, 0)
      ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
      this.childIpId2 = childIpId2;
    });

    step("Raise dispute for root IP", async function () {
      // Construct UMA data
      const abiCoder = new ethers.AbiCoder();
      const minLiveness = await this.arbitrationPolicyUMA.minLiveness();
      const minimumBond = this.minimumBond;
      this.data = abiCoder.encode(["uint64", "address", "uint256"], [minLiveness, MockERC20, minimumBond]);
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      this.disputeId = await expect(
        this.disputeModule.connect(this.user1).raiseDispute(this.rootIpId, disputeEvidenceHash, IMPROPER_REGISTRATION, this.data)
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then(extractDisputeId(this.disputeModule, this.arbitrationPolicyUMA));
    });

    step("Set dispute judgement to true", async function () {
      await expect(
        this.disputeModule.setDisputeJudgement(this.disputeId, true, "0x")
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    });

    step("Verify root IP is tagged, derivatives are not", async function () {
      expect(await this.disputeModule.isIpTagged(this.rootIpId)).to.be.true;
      expect(await this.disputeModule.isIpTagged(this.childIpId1)).to.be.false;
      expect(await this.disputeModule.isIpTagged(this.childIpId2)).to.be.false;
    });

    step("Tag first derivative IP", async function () {
      const tx1 = await expect(
        this.disputeModule.connect(this.user2).tagIfRelatedIpInfringed(this.childIpId1, this.disputeId)
      ).not.to.be.rejectedWith(Error);

      const receipt1 = await tx1.wait();
      this.disputeIp1 = await this.disputeModule.disputeCounter();

      const event1 = this.disputeModule.interface.parseLog(receipt1.logs[0]);
      expect(event1?.name).to.equal("IpTaggedOnRelatedIpInfringement");
      expect(event1?.args?.disputeId).to.equal(this.disputeIp1);
      expect(event1?.args?.infringingIpId).to.equal(this.rootIpId);
      expect(event1?.args?.ipIdToTag).to.equal(this.childIpId1);
      expect(event1?.args?.infringerDisputeId).to.equal(this.disputeId);
      expect(event1?.args?.tag).to.equal(IMPROPER_REGISTRATION);

      expect(await this.disputeModule.isIpTagged(this.childIpId1)).to.be.true;
      expect(await this.disputeModule.isIpTagged(this.childIpId2)).to.be.false;
    });

    step("Tag second derivative IP", async function () {
      const tx2 = await expect(
        this.disputeModule.connect(this.user2).tagIfRelatedIpInfringed(this.childIpId2, this.disputeIp1)
      ).not.to.be.rejectedWith(Error);

      const receipt2 = await tx2.wait();
      this.disputeIp2 = await this.disputeModule.disputeCounter();

      const event2 = this.disputeModule.interface.parseLog(receipt2.logs[0]);
      expect(event2?.name).to.equal("IpTaggedOnRelatedIpInfringement");
      expect(event2?.args?.disputeId).to.equal(this.disputeIp2);
      expect(event2?.args?.infringingIpId).to.equal(this.childIpId1);
      expect(event2?.args?.ipIdToTag).to.equal(this.childIpId2);
      expect(event2?.args?.infringerDisputeId).to.equal(this.disputeIp1);
      expect(event2?.args?.tag).to.equal(IMPROPER_REGISTRATION);

      expect(await this.disputeModule.isIpTagged(this.childIpId1)).to.be.true;
      expect(await this.disputeModule.isIpTagged(this.childIpId2)).to.be.true;
    });

    step("Resolve dispute for root IP", async function () {
      await expect(
        this.disputeModule.connect(this.user1).resolveDispute(this.disputeId, "0x")
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
      expect(await this.disputeModule.isIpTagged(this.rootIpId)).to.be.false;
    });

    step("Resolve dispute for first derivative", async function () {
      await expect(
        this.disputeModule.connect(this.user2).resolveDispute(this.disputeIp1, "0x")
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
      expect(await this.disputeModule.isIpTagged(this.childIpId1)).to.be.false;
    });

    step("Resolve dispute for second derivative", async function () {
      await expect(
        this.disputeModule.connect(this.user2).resolveDispute(this.disputeIp2, "0x")
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
      expect(await this.disputeModule.isIpTagged(this.childIpId2)).to.be.false;
    });
  });

  describe("Set tags to the derivative IP assets if the parent has not infringed", function () {
    step("Register parent and child IP assets", async function () {
      const { ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commercialUseLicenseId);
      this.ipId = ipId;

      const { ipId: childIpId } = await mintNFTAndRegisterIPA();
      await expect(
        this.licensingModule.registerDerivative(childIpId, [this.ipId], [this.commercialUseLicenseId], PILicenseTemplate, "0x", 0, 100e6, 0)
      ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
      this.childIpId = childIpId;
    });

    step("Raise dispute", async function () {
      // Construct UMA data
      const abiCoder = new ethers.AbiCoder();
      const minLiveness = await this.arbitrationPolicyUMA.minLiveness();
      const minimumBond = this.minimumBond;
      this.data = abiCoder.encode(["uint64", "address", "uint256"], [minLiveness, MockERC20, minimumBond]);
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      this.disputeId = await expect(
        this.disputeModule.connect(this.user1).raiseDispute(this.ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, this.data)
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then(extractDisputeId(this.disputeModule, this.arbitrationPolicyUMA));
    });

    step("Set dispute judgement to false", async function () {
      await expect(
        this.disputeModule.setDisputeJudgement(this.disputeId, false, "0x")
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
    });

    step("Verify tagging derivative fails without infringement", async function () {
      await expect(
        this.disputeModule.connect(this.user2).tagIfRelatedIpInfringed(this.ipId, this.disputeId)
      ).to.be.revertedWithCustomError(this.errors, "DisputeModule__DisputeWithoutInfringementTag");
      expect(await this.disputeModule.isIpTagged(this.childIpId)).to.be.false;
    });
  });


  describe("IPA dispute assertion", function () {
    step("Register IP asset and raise dispute", async function () {
      const { tokenId, ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commericialRemixLicenseId);
      this.tokenId = tokenId;
      this.ipId = ipId;
      
      const abiCoder = new ethers.AbiCoder();
      const maxLiveness = await this.arbitrationPolicyUMA.maxLiveness();
      const minimumBond = this.minimumBond;
      const data = abiCoder.encode(["uint64", "address", "uint256"], [maxLiveness, MockERC20, minimumBond]);
      
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      this.disputeId = await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, data)
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then(extractDisputeId(this.disputeModule, this.arbitrationPolicyUMA));
    });

    step("Get assertion ID and IP Account details", async function () {
      this.assertionId = await this.arbitrationPolicyUMA.disputeIdToAssertionId(this.disputeId);
      this.ipAccount = await this.ipAssetRegistry.ipAccount(this.chainId, MockERC721, this.tokenId);
      this.ipAccountContract = await hre.ethers.getContractAt("IPAccountImpl", this.ipAccount);
      this.toAddress = await this.arbitrationPolicyUMA.getAddress();
    });
    
    step("Setup ERC20 tokens and allowance for IP Account", async function () {
      const assertion = await this.oov3.getAssertion(this.assertionId);
      const mockERC20 = await hre.ethers.getContractAt("IERC20", MockERC20);
      
      // Transfer tokens to IP Account if needed
      const ipAccountBalance = await mockERC20.balanceOf(this.ipAccount);
      if (ipAccountBalance < assertion.bond) {
        await mockERC20.connect(this.owner).transfer(this.ipAccount, assertion.bond);
      }
      
      // Setup allowance for ArbitrationPolicyUMA
      const approveData = mockERC20.interface.encodeFunctionData("approve", [this.toAddress, assertion.bond]);
      const approveTx = await this.ipAccountContract.connect(this.owner).execute(await mockERC20.getAddress(), 0, approveData);
      await approveTx.wait();
      
      // Verify allowance
      const allowance = await mockERC20.allowance(this.ipAccount, this.toAddress);
      expect(allowance).to.be.gte(assertion.bond);
    });
    
    step("Execute IPA dispute assertion", async function () {
      const assertionData = this.arbitrationPolicyUMA.interface.encodeFunctionData(
        "disputeAssertion", [this.assertionId, encodeBytes32String("COUNTER_EVIDENCE_HASH")]
      );
      
      const tx = await expect(
        this.ipAccountContract.execute(this.toAddress, 0, assertionData)
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());
      
      expect(tx.hash).to.be.a('string');
    });

    step("Verify IP tagging status after dispute assertion", async function () {
      expect(await this.disputeModule.isIpTagged(this.ipId)).to.be.false;
    });
  });

  describe("Dispute negative operations", function () {
    let ipId: string;
    let disputeId: bigint;
    let data: string;

    before(async function () {
      console.log("============ Register IP ============");
      ({ ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commercialUseLicenseId));

      console.log("============ Raise Dispute ============");
      const disputeEvidenceHash = generateUniqueDisputeEvidenceHash();
      
      console.log("============ Construct UMA data ============");
      const abiCoder = new ethers.AbiCoder();
      const minLiveness = await this.arbitrationPolicyUMA.minLiveness();
      const minimumBond = this.minimumBond;
      data = abiCoder.encode(["uint64", "address", "uint256"], [minLiveness, MockERC20, minimumBond]);
      
      // Call raiseDispute and wait for transaction to complete
      disputeId = await expect(
        this.disputeModule.connect(this.user1).raiseDispute(ipId, disputeEvidenceHash, IMPROPER_REGISTRATION, data)
      ).not.to.be.rejectedWith(Error).then((tx) => tx.wait()).then(extractDisputeId(this.disputeModule, this.arbitrationPolicyUMA));
      
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

// New feature tests for v1.3.3
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
      
      console.log("============ Construct UMA data ============");
      const abiCoder = new ethers.AbiCoder();
      const minLiveness = await this.arbitrationPolicyUMA.minLiveness();
      const minimumBond = this.minimumBond;
      const data = abiCoder.encode(["uint64", "address", "uint256"], [minLiveness, MockERC20, minimumBond]);
      
      const tx = await this.disputeModule.connect(caller).raiseDisputeOnBehalf(
        ipId, 
        disputeInitiator, 
        disputeEvidenceHash, 
        IMPROPER_REGISTRATION, 
        data
      );
      
      const receipt = await tx.wait();
      const disputeId = extractDisputeId(this.disputeModule, this.arbitrationPolicyUMA)(receipt);
      
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
      expect(callerBalanceBefore - callerBalanceAfter).to.equal(this.minimumBond);
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

      console.log("============ Construct UMA data ============");
      const abiCoder = new ethers.AbiCoder();
      const minLiveness = await this.arbitrationPolicyUMA.minLiveness();
      const minimumBond = this.minimumBond;
      const data = abiCoder.encode(["uint64", "address", "uint256"], [minLiveness, MockERC20, minimumBond]);

      // Raise dispute on behalf
      const tx = await this.disputeModule.connect(caller).raiseDisputeOnBehalf(
        ipId, 
        disputeInitiator.address, 
        disputeEvidenceHash, 
        IMPROPER_REGISTRATION, 
        data
      );
      
      const receipt = await tx.wait();
      const disputeId = extractDisputeId(this.disputeModule, this.arbitrationPolicyUMA)(receipt);
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

  // New feature tests for v1.3.3
  describe("Raise Dispute On Behalf - Error Cases", function () {
    let ipId: string;
    let data: string;

    before(async function () {
      console.log("============ Register IP for raiseDisputeOnBehalf error tests ============");
      ({ ipId } = await mintNFTAndRegisterIPAWithLicenseTerms(this.commercialUseLicenseId));
      
      console.log("============ Construct UMA data ============");
      const abiCoder = new ethers.AbiCoder();
      const minLiveness = await this.arbitrationPolicyUMA.minLiveness();
      const minimumBond = this.minimumBond;
      data = abiCoder.encode(["uint64", "address", "uint256"], [minLiveness, MockERC20, minimumBond]);
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

// Helper function to extract disputeId from transaction receipt
function extractDisputeId(disputeModule, arbitrationPolicyUMA) {
  return function(receipt) {
    // Try to find DisputeRaised event from DisputeModule
    let disputeRaisedEvent = receipt.logs.find(log => {
      try {
        const parsed = disputeModule.interface.parseLog(log);
        return parsed.name === 'DisputeRaised';
      } catch {
        return false;
      }
    });
    
    if (disputeRaisedEvent) {
      const parsedEvent = disputeModule.interface.parseLog(disputeRaisedEvent);
      return parsedEvent.args[0]; // disputeId is the first argument in DisputeRaised event
    }
    
    // Fallback: try to find DisputeRaisedUMA event from ArbitrationPolicyUMA
    const disputeRaisedUMAEvent = receipt.logs.find(log => {
      try {
        const parsed = arbitrationPolicyUMA.interface.parseLog(log);
        return parsed.name === 'DisputeRaisedUMA';
      } catch {
        return false;
      }
    });
    
    if (disputeRaisedUMAEvent) {
      const parsedEvent = arbitrationPolicyUMA.interface.parseLog(disputeRaisedUMAEvent);
      return parsedEvent.args[0]; // disputeId is the first argument in DisputeRaisedUMA event
    }
    
    throw new Error("Neither DisputeRaised nor DisputeRaisedUMA event found in transaction logs");
  };
}
