// Test: IPAccount - state update on asset changes and ERC1271 validation

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";
import { AccessController, LicensingModule, MockERC721, PILicenseTemplate } from "../constants";
import { mintNFT } from "../utils/nftHelper";

/**
 * This test suite verifies the behavior of IPAccount contract, specifically focusing on:
 * 1. State updates when IP assets are modified
 * 2. ERC1271 signature validation functionality
 */
describe("IPAccount", function () {
  /**
   * This test verifies that the IPAccount's state (nonce) is properly updated
   * when various operations are performed on the IP asset, including:
   * - Registering an IP asset
   * - Attaching license terms
   * - Registering derivatives
   * - Minting license tokens
   * 
   * The state should change after each operation to ensure proper transaction ordering
   * and prevent replay attacks.
   */
  it("Update nonce state of IPAsset on asset changes", async function () {
    console.log("============ Register IP1 ============");
    const { tokenId: tokenId1, ipId: ipId1 } = await mintNFTAndRegisterIPA();
    console.log("IP1: ", ipId1);

    console.log("============ Get state of IP1 ============");
    const ipAccount1 = await this.ipAssetRegistry.ipAccount(this.chainId, MockERC721, tokenId1);
    console.log("IPAccount1: ", ipAccount1);
    const ipAccount1Contract = await hre.ethers.getContractAt("IPAccountImpl", ipAccount1);
    const state1 = await ipAccount1Contract.state();
    console.log("State of IP1: ", state1);

    console.log("============ Attach license to IP1 ============");
    await expect(
      this.licensingModule.attachLicenseTerms(ipId1, PILicenseTemplate, this.commericialRemixLicenseId)
    ).not.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log("============ Get state of IP1 after attaching license ============");
    const stateAfterLicense = await ipAccount1Contract.state();
    console.log("State of IP1 after attaching license: ", stateAfterLicense);
    expect(stateAfterLicense).to.not.equal(state1);

    console.log("============Register IP2 as IP1's derivative ============");
    const { tokenId: tokenId2, ipId: ipId2 } = await mintNFTAndRegisterIPA();
    console.log("IP2: ", ipId2);
    const ipAccount2 = await this.ipAssetRegistry.ipAccount(this.chainId, MockERC721, tokenId2);
    const ipAccount2Contract = await hre.ethers.getContractAt("IPAccountImpl", ipAccount2);
    const state2 = await ipAccount2Contract.state();
    console.log("State of IP2: ", state2);
    await expect(
      this.licensingModule.registerDerivative(ipId2, [ipId1], [this.commericialRemixLicenseId], PILicenseTemplate, "0x", 0, 100e6, 0)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    console.log("============ Get state of IP2 after registering as derivative ============");
    const state2After = await ipAccount2Contract.state();
    console.log("State of IP2 after registering as derivative: ", state2After);
    expect(state2After).to.not.equal(state2);

    console.log("============ Mint License Token for IP1 ============");
    await expect(
      this.licensingModule.mintLicenseTokens(ipId1, PILicenseTemplate, this.commericialRemixLicenseId, 1, this.owner.address, "0x", 0, 0)
    ).not.to.be.rejectedWith(Error).then((tx) => tx.wait());

    console.log("============ Get state of IP1 after minting license token ============");
    const stateAfterMint = await ipAccount1Contract.state();
    console.log("State of IP1 after minting license token: ", stateAfterMint);
    expect(stateAfterMint).to.not.equal(stateAfterLicense);
  });

  /**
   * This test suite focuses on verifying the ERC1271 signature validation behavior
   * of the IPAccount contract. ERC1271 is a standard for signature validation
   * in smart contracts, and IPAccount specifically disables this functionality
   * by always returning a failure magic value (0xffffffff).
   * 
   * The tests verify that:
   * 1. All signatures are rejected regardless of validity
   * 2. Empty signatures are handled properly
   * 3. The behavior is consistent across different scenarios
   */
  describe("ERC1271 Signature Validation", function () {
    let ipAccount: any;
    let owner: any;
    const MAGIC_VALUE_FAILURE = "0xffffffff";

    /**
     * Setup function that runs before each test case.
     * Creates a new IPAccount and gets its owner for testing.
     */
    beforeEach(async function () {
      const { tokenId, ipId } = await mintNFTAndRegisterIPA();
      ipAccount = await hre.ethers.getContractAt("IPAccountImpl", ipId);
      const ownerAddress = await ipAccount.owner();
      owner = await hre.ethers.getSigner(ownerAddress);
    });

    /**
     * Verifies that the IPAccount always returns the failure magic value
     * (0xffffffff) for any signature validation attempt, effectively
     * disabling ERC1271 functionality.
     * 
     * This test focuses on verifying the basic behavior of the contract
     * by testing with a simple message and signature.
     */
    it("should always return failure magic value", async function () {
      console.log("============ Testing basic ERC1271 behavior ============");
      const message = "Test message";
      console.log("Message to sign:", message);
      
      const messageHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes(message));
      console.log("Message hash:", messageHash);
      
      const signature = await owner.signMessage(hre.ethers.getBytes(messageHash));
      console.log("Generated signature:", signature);
      
      console.log("============ Verifying signature ============");
      const result = await ipAccount.isValidSignature(messageHash, signature);
      console.log("Signature validation result:", result);
      expect(result).to.equal(MAGIC_VALUE_FAILURE);
      console.log("✓ Test passed: Contract always returns failure magic value");
    });

    /**
     * Verifies that the IPAccount rejects all signatures regardless of
     * who the signer is. This test specifically focuses on testing
     * different types of signatures and edge cases:
     * - Valid signature from owner
     * - Invalid signature
     * - Malformed signature
     */
    it("should reject all signatures regardless of signer", async function () {
      console.log("============ Testing different signature types ============");
      
      // Test 1: Valid signature from owner
      console.log("Test 1: Valid signature from owner");
      const message1 = "Test message 1";
      const messageHash1 = hre.ethers.keccak256(hre.ethers.toUtf8Bytes(message1));
      const validSignature = await owner.signMessage(hre.ethers.getBytes(messageHash1));
      const result1 = await ipAccount.isValidSignature(messageHash1, validSignature);
      expect(result1).to.equal(MAGIC_VALUE_FAILURE);
      console.log("✓ Test 1 passed: Valid owner signature rejected");
      
      // Test 2: Invalid signature (wrong message)
      console.log("Test 2: Invalid signature");
      const message2 = "Test message 2";
      const messageHash2 = hre.ethers.keccak256(hre.ethers.toUtf8Bytes(message2));
      const result2 = await ipAccount.isValidSignature(messageHash2, validSignature);
      expect(result2).to.equal(MAGIC_VALUE_FAILURE);
      console.log("✓ Test 2 passed: Invalid signature rejected");
      
      // Test 3: Malformed signature
      console.log("Test 3: Malformed signature");
      const message3 = "Test message 3";
      const messageHash3 = hre.ethers.keccak256(hre.ethers.toUtf8Bytes(message3));
      const malformedSignature = validSignature.slice(0, -2) + "00"; // Corrupt the last byte
      const result3 = await ipAccount.isValidSignature(messageHash3, malformedSignature);
      expect(result3).to.equal(MAGIC_VALUE_FAILURE);
      console.log("✓ Test 3 passed: Malformed signature rejected");
    });

    /**
     * Verifies that the IPAccount properly handles empty signatures
     * by returning the failure magic value. This is important for
     * maintaining consistent behavior and preventing potential
     * edge cases in signature validation.
     */
    it("should handle empty signature", async function () {
      console.log("============ Testing empty signature handling ============");
      const message = "Test message";
      console.log("Message to sign:", message);
      
      const messageHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes(message));
      console.log("Message hash:", messageHash);
      
      const emptySignature = "0x";
      console.log("Empty signature:", emptySignature);
      
      console.log("============ Verifying empty signature ============");
      const result = await ipAccount.isValidSignature(messageHash, emptySignature);
      console.log("Signature validation result:", result);
      expect(result).to.equal(MAGIC_VALUE_FAILURE);
      console.log("✓ Test passed: Contract properly handles empty signature");
    });
  });

  it("IP Owner execute AccessController module", async function () {
    console.log("============ Register IP Account ============");
    const { tokenId: tokenId1, ipId: ipId1 } = await mintNFTAndRegisterIPA(this.user1, this.user1);
    const ipAccount1 = await this.ipAssetRegistry.ipAccount(this.chainId, MockERC721, tokenId1, this.user1);
    console.log("IPAccount1: ", ipAccount1);
    const ipAccount1Contract = await hre.ethers.getContractAt("IPAccountImpl", ipId1, this.user1);

    await expect(
      ipAccount1Contract.execute(
        AccessController, 
        0,
        this.accessController.interface.encodeFunctionData(
          "setPermission",
          [
            ipAccount1,
            ipAccount1,
            LicensingModule,
            this.licensingModule.interface.getFunction("attachLicenseTerms").selector,
            1
          ]
        )
      )
    ).not.to.be.rejectedWith(Error);
  });

  it("Non-IP Owner execute AccessController module", async function () {
    console.log("============ Register IP Account1 ============");
    const { tokenId: tokenId1, ipId: ipId1 } = await mintNFTAndRegisterIPA(this.user1, this.user1);
    const ipAccount1 = await this.ipAssetRegistry.ipAccount(this.chainId, MockERC721, tokenId1, this.user1);
    console.log("IPAccount1: ", ipAccount1);
    const ipAccount1Contract = await hre.ethers.getContractAt("IPAccountImpl", ipId1, this.user1);

    console.log("============ Register IP Account1 ============");
    const { tokenId: tokenId2, ipId: ipId2 } = await mintNFTAndRegisterIPA(this.user2, this.user2);
    const ipAccount2 = await this.ipAssetRegistry.ipAccount(this.chainId, MockERC721, tokenId2, this.user2);
    console.log("IPAccount2: ", ipAccount1);
    const ipAccount2Contract = await hre.ethers.getContractAt("IPAccountImpl", ipAccount2, this.user2);

    await expect(
      ipAccount2Contract.execute(
        AccessController, 
        0,
        this.accessController.interface.encodeFunctionData(
          "setPermission",
          [
            ipAccount1,
            ipAccount1,
            LicensingModule,
            this.licensingModule.interface.getFunction("attachLicenseTerms").selector,
            1
          ]
        )
      )
    ).to.be.revertedWithCustomError(this.errors, "AccessController__CallerIsNotIPAccountOrOwner");
  });

  it("Set permission fail as OwnerIsIPAccount - IPAccountCannotSetPermissionForNestedIpAccount", async function () {
    console.log("============ Register IP Account 1 ============");
    const { tokenId: tokenId1, ipId: ipId1 } = await mintNFTAndRegisterIPA(this.owner, this.owner);
    const ipAccount1 = await this.ipAssetRegistry.ipAccount(this.chainId, MockERC721, tokenId1, this.owner);
    console.log("IPAccount1: ", ipAccount1);
    const ipAccount1Contract = await hre.ethers.getContractAt("IPAccountImpl", ipAccount1, this.owner);

    console.log("============ Register IP Account 2 (Nested IP Account) ============");
    const signers = await hre.ethers.getSigners(); 
    const tokenId2 = await mintNFT(this.user1, ipAccount1);
    const connectedRegistry = await this.ipAssetRegistry.connect(signers[1]);
    const ipId2 = await connectedRegistry.register(this.chainId, MockERC721, tokenId2, this.user1).then((tx: any) => tx.wait());
    const ipAccount2 = await connectedRegistry.ipAccount(this.chainId, MockERC721, tokenId2);
    console.log("IPAccount2: ", ipAccount2);
    const ipAccount2Contract = await hre.ethers.getContractAt("IPAccountImpl", ipAccount2, this.user1);

    await expect(
      ipAccount1Contract.execute(
        AccessController, 
        0,
        this.accessController.interface.encodeFunctionData(
          "setPermission",
          [
            ipAccount2,
            ipAccount1,
            LicensingModule,
            this.licensingModule.interface.getFunction("attachLicenseTerms").selector,
            1
          ]
        )
      )
    ).to.be.revertedWithCustomError(this.errors, "AccessController__OwnerIsIPAccount");
  });

  it("Set permission fail as OwnerIsIPAccount - NestedIpAccountCannotSetPermission", async function () {
    console.log("============ Register IP Account 1 ============");
    const { tokenId: tokenId1, ipId: ipId1 } = await mintNFTAndRegisterIPA(this.owner, this.owner);
    const ipAccount1 = await this.ipAssetRegistry.ipAccount(this.chainId, MockERC721, tokenId1);
    console.log("IPAccount1: ", ipAccount1);
    const ipAccount1Contract = await hre.ethers.getContractAt("IPAccountImpl", ipAccount1, this.owner);

    console.log("============ Register IP Account 2 (Nested IP Account) ============");
    const signers = await hre.ethers.getSigners(); 
    const tokenId2 = await mintNFT(this.user1, ipAccount1);
    const connectedRegistry = await this.ipAssetRegistry.connect(signers[1]);
    const ipId2 = await connectedRegistry.register(this.chainId, MockERC721, tokenId2, this.user1).then((tx: any) => tx.wait());
    const ipAccount2 = await connectedRegistry.ipAccount(this.chainId, MockERC721, tokenId2);
    console.log("IPAccount2: ", ipAccount2);
    const ipAccount2Contract = await hre.ethers.getContractAt("IPAccountImpl", ipAccount2, this.user1);

    await expect(
      ipAccount1Contract.execute(
        ipAccount2, 
        0,
        ipAccount1Contract.interface.encodeFunctionData(
          "execute(address,uint256,bytes)",
          [
            AccessController,
            0,
            this.accessController.interface.encodeFunctionData(
              "setPermission",
              [
                ipAccount2,
                ipAccount1,
                LicensingModule,
                this.licensingModule.interface.getFunction("attachLicenseTerms").selector,
                1
              ]
            )
          ]
        )
      )
    ).to.be.revertedWithCustomError(this.errors, "AccessController__OwnerIsIPAccount");
  });
});
