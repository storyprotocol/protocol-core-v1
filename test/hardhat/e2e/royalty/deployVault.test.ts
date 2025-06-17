// Test: RoyaltyModule - deployVault function

import "../setup";
import { expect } from "chai";
import hre from "hardhat";
import { MockERC20, PILicenseTemplate, RoyaltyPolicyLAP } from "../constants";
import { mintNFTAndRegisterIPA } from "../utils/mintNFTAndRegisterIPA";
import { terms } from "../licenseTermsTemplate";

describe("RoyaltyModule - deployVault", function () {
  let signers: any;
  let ipId1: any;
  let ipId2: any;
  let licenseTermsLAPId: any;
  let user1ConnectedRoyaltyModule: any;
  let user2ConnectedRoyaltyModule: any;
  let user1ConnectedLicensingModule: any;
  let user2ConnectedLicensingModule: any;
  const testTerms = terms;

  this.beforeAll("Get Signers and register license terms", async function () {
    // Get the signers
    signers = await hre.ethers.getSigners();

    // Register a commercial remix license with royalty policy LAP
    testTerms.royaltyPolicy = RoyaltyPolicyLAP;
    testTerms.defaultMintingFee = 100;
    testTerms.commercialUse = true;
    testTerms.derivativesReciprocal = true;
    testTerms.commercialRevShare = 10 * 10 ** 6;
    testTerms.currency = MockERC20;

    const connectedLicense = this.licenseTemplate.connect(signers[0]);
    const registerLicenseLAPTx = await expect(
      connectedLicense.registerLicenseTerms(testTerms)
    ).to.not.be.rejectedWith(Error);
    await registerLicenseLAPTx.wait();

    licenseTermsLAPId = await connectedLicense.getLicenseTermsId(terms);
    console.log("licenseTermsLAPId: ", licenseTermsLAPId);

    user1ConnectedRoyaltyModule = this.royaltyModule.connect(signers[0]);
    user2ConnectedRoyaltyModule = this.royaltyModule.connect(signers[1]);
    user1ConnectedLicensingModule = this.licensingModule.connect(signers[0]);
    user2ConnectedLicensingModule = this.licensingModule.connect(signers[1]);
  });

  it("Should deploy vault for registered IP", async function () {
    console.log("============ Deploy Vault Test ============");
    
    // Create and register IP
    const mintAndRegisterResp1 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    ipId1 = mintAndRegisterResp1.ipId;
    console.log("Registered IP ID: ", ipId1);

    // Check that vault doesn't exist initially
    const initialVaultAddress = await user1ConnectedRoyaltyModule.ipRoyaltyVaults(ipId1);
    console.log("Initial vault address: ", initialVaultAddress);
    expect(initialVaultAddress).to.equal(hre.ethers.ZeroAddress);

    // Deploy vault for the IP
    const deployVaultTx = await expect(
      user1ConnectedRoyaltyModule.deployVault(ipId1)
    ).to.not.be.rejectedWith(Error);
    await deployVaultTx.wait();
    console.log("Deploy vault transaction hash: ", deployVaultTx.hash);
    expect(deployVaultTx.hash).to.not.be.empty.and.to.be.a("HexString");

    // Check that vault was deployed
    const vaultAddress = await user1ConnectedRoyaltyModule.ipRoyaltyVaults(ipId1);
    console.log("Deployed vault address: ", vaultAddress);
    expect(vaultAddress).to.not.equal(hre.ethers.ZeroAddress);

    // Verify vault is a valid contract
    const vaultContract = await hre.ethers.getContractAt("IpRoyaltyVault", vaultAddress);
    const vaultIpId = await vaultContract.ipId();
    expect(vaultIpId).to.equal(ipId1);
    console.log("Vault deployed successfully for IP: ", ipId1);
  });

  it("Should revert when trying to deploy vault for unregistered IP", async function () {
    console.log("============ Deploy Vault for Unregistered IP Test ============");
    
    // Try to deploy vault for non-existent IP
    const fakeIpId = "0x1234567890123456789012345678901234567890";
    
    await expect(
      user1ConnectedRoyaltyModule.deployVault(fakeIpId)
    ).to.be.revertedWithCustomError(this.royaltyModule, "RoyaltyModule__IpIdNotRegistered");
    
    console.log("Correctly reverted for unregistered IP");
  });

  it("Should revert when trying to deploy vault twice for same IP", async function () {
    console.log("============ Deploy Vault Twice Test ============");
    
    // Create and register IP
    const mintAndRegisterResp2 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    ipId2 = mintAndRegisterResp2.ipId;
    console.log("Registered IP ID: ", ipId2);

    // Deploy vault first time
    const deployVaultTx1 = await expect(
      user2ConnectedRoyaltyModule.deployVault(ipId2)
    ).to.not.be.rejectedWith(Error);
    await deployVaultTx1.wait();
    console.log("First deploy vault transaction hash: ", deployVaultTx1.hash);

    // Try to deploy vault second time - should revert
    await expect(
      user2ConnectedRoyaltyModule.deployVault(ipId2)
    ).to.be.revertedWithCustomError(this.royaltyModule, "RoyaltyModule__VaultAlreadyDeployed");
    
    console.log("Correctly reverted when trying to deploy vault twice");
  });

  it("Should allow vault deployment independent of license minting", async function () {
    console.log("============ Independent Vault Deployment Test ============");
    
    // Create and register IP
    const mintAndRegisterResp3 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    const ipId3 = mintAndRegisterResp3.ipId;
    console.log("Registered IP ID: ", ipId3);

    // Deploy vault before any licensing activity
    const deployVaultTx = await expect(
      user1ConnectedRoyaltyModule.deployVault(ipId3)
    ).to.not.be.rejectedWith(Error);
    await deployVaultTx.wait();
    console.log("Deploy vault transaction hash: ", deployVaultTx.hash);

    // Verify vault exists
    const vaultAddress = await user1ConnectedRoyaltyModule.ipRoyaltyVaults(ipId3);
    expect(vaultAddress).to.not.equal(hre.ethers.ZeroAddress);

    // Now attach license terms and verify vault still works
    const attachLicenseTx = await expect(
      user1ConnectedLicensingModule.attachLicenseTerms(ipId3, PILicenseTemplate, licenseTermsLAPId)
    ).not.to.be.rejectedWith(Error);
    await attachLicenseTx.wait();

    // Verify vault address hasn't changed
    const vaultAddressAfterLicense = await user1ConnectedRoyaltyModule.ipRoyaltyVaults(ipId3);
    expect(vaultAddressAfterLicense).to.equal(vaultAddress);
    
    console.log("Vault deployment works independently of licensing");
  });

  it("Should emit VaultDeployed event when vault is deployed", async function () {
    console.log("============ Vault Deployment Event Test ============");
    
    // Create and register IP
    const mintAndRegisterResp4 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    const ipId4 = mintAndRegisterResp4.ipId;
    console.log("Registered IP ID: ", ipId4);

    // Deploy vault and check for event
    const deployVaultTx = await user2ConnectedRoyaltyModule.deployVault(ipId4);
    const receipt = await deployVaultTx.wait();
    
    // Get the deployed vault address
    const vaultAddress = await user2ConnectedRoyaltyModule.ipRoyaltyVaults(ipId4);
    
    // Verify the event was emitted
    expect(receipt).to.not.be.null;
    expect(receipt.logs).to.not.be.empty;
    
    // Find the IpRoyaltyVaultDeployed event
    const event = receipt.logs.find(
      (log: any) => 
        log.fragment && 
        log.fragment.name === "IpRoyaltyVaultDeployed" &&
        log.address === this.royaltyModule.target
    );
    
    expect(event).to.not.be.undefined;
    expect(event.args[0]).to.equal(ipId4);
    expect(event.args[1]).to.equal(vaultAddress);
    
    console.log("VaultDeployed event emitted correctly");
  });

  it("Should handle license minting after vault deployment - validates minting fee revenue collection", async function () {
    console.log("============ License Minting After Vault Deployment Test ============");
    
    // Create and register licensor IP
    const mintAndRegisterResp5 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    const licensorIpId = mintAndRegisterResp5.ipId;
    console.log("Registered licensor IP ID: ", licensorIpId);

    // Deploy vault first
    const deployVaultTx = await expect(
      user1ConnectedRoyaltyModule.deployVault(licensorIpId)
    ).to.not.be.rejectedWith(Error);
    await deployVaultTx.wait();
    console.log("Deploy vault transaction hash: ", deployVaultTx.hash);

    // Get vault address before licensing
    const vaultAddressBefore = await user1ConnectedRoyaltyModule.ipRoyaltyVaults(licensorIpId);
    expect(vaultAddressBefore).to.not.equal(hre.ethers.ZeroAddress);

    // Attach license terms to the licensor IP
    const attachLicenseTx = await expect(
      user1ConnectedLicensingModule.attachLicenseTerms(licensorIpId, PILicenseTemplate, licenseTermsLAPId)
    ).not.to.be.rejectedWith(Error);
    await attachLicenseTx.wait();
    console.log("Attach license transaction hash: ", attachLicenseTx.hash);

    // Create and register derivative IP
    const mintAndRegisterResp6 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    const derivativeIpId = mintAndRegisterResp6.ipId;
    console.log("Registered derivative IP ID: ", derivativeIpId);

    // Register derivative with license minting
    const registerDerivativeTx = await expect(
      user2ConnectedLicensingModule.registerDerivative(
        derivativeIpId, 
        [licensorIpId], 
        [licenseTermsLAPId], 
        PILicenseTemplate, 
        hre.ethers.ZeroAddress, 
        0, 
        100, // minting fee
        10 * 10 ** 6 // 10% royalty
      )
    ).not.to.be.rejectedWith(Error);
    await registerDerivativeTx.wait();
    console.log("Register derivative transaction hash: ", registerDerivativeTx.hash);

    // Verify vault address hasn't changed after license minting
    const vaultAddressAfter = await user1ConnectedRoyaltyModule.ipRoyaltyVaults(licensorIpId);
    expect(vaultAddressAfter).to.equal(vaultAddressBefore);

    // Verify vault received the minting fee
    const vaultContract = await hre.ethers.getContractAt("IpRoyaltyVault", vaultAddressAfter);
    const claimableRevenue = await vaultContract.claimableRevenue(licensorIpId, MockERC20);
    expect(claimableRevenue).to.be.greaterThan(0);
    
    console.log("License minting works correctly after vault deployment");
    console.log("Claimable revenue: ", claimableRevenue.toString());
  });

  it("Should handle linking to parents after vault deployment - validates royalty policy inheritance", async function () {
    console.log("============ Link to Parents After Vault Deployment Test ============");
    
    // Create and register parent IPs
    const mintAndRegisterResp7 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    const parentIpId1 = mintAndRegisterResp7.ipId;
    const mintAndRegisterResp8 = await mintNFTAndRegisterIPA(signers[0], signers[0]);
    const parentIpId2 = mintAndRegisterResp8.ipId;
    console.log("Registered parent IP IDs: ", parentIpId1, parentIpId2);

    // Attach license terms to parent IPs
    await expect(
      user1ConnectedLicensingModule.attachLicenseTerms(parentIpId1, PILicenseTemplate, licenseTermsLAPId)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    
    await expect(
      user1ConnectedLicensingModule.attachLicenseTerms(parentIpId2, PILicenseTemplate, licenseTermsLAPId)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());

    // Create and register child IP
    const mintAndRegisterResp9 = await mintNFTAndRegisterIPA(signers[1], signers[1]);
    const childIpId = mintAndRegisterResp9.ipId;
    console.log("Registered child IP ID: ", childIpId);

    // Deploy vault for child IP first
    const deployVaultTx = await expect(
      user2ConnectedRoyaltyModule.deployVault(childIpId)
    ).to.not.be.rejectedWith(Error);
    await deployVaultTx.wait();
    console.log("Deploy vault transaction hash: ", deployVaultTx.hash);

    // Get vault address before linking
    const vaultAddressBefore = await user2ConnectedRoyaltyModule.ipRoyaltyVaults(childIpId);
    expect(vaultAddressBefore).to.not.equal(hre.ethers.ZeroAddress);

    // Register derivative (link to parents) after vault deployment
    const registerDerivativeTx = await expect(
      user2ConnectedLicensingModule.registerDerivative(
        childIpId,
        [parentIpId1, parentIpId2],
        [licenseTermsLAPId, licenseTermsLAPId],
        PILicenseTemplate,
        hre.ethers.ZeroAddress,
        0,
        200, // total minting fee for both parents
        20 * 10 ** 6 // 20% total royalty
      )
    ).not.to.be.rejectedWith(Error);
    await registerDerivativeTx.wait();
    console.log("Register derivative transaction hash: ", registerDerivativeTx.hash);

    // Verify vault address hasn't changed after linking
    const vaultAddressAfter = await user2ConnectedRoyaltyModule.ipRoyaltyVaults(childIpId);
    expect(vaultAddressAfter).to.equal(vaultAddressBefore);

    // Verify child IP has accumulated royalty policies from parents
    const accumulatedPolicies = await user2ConnectedRoyaltyModule.accumulatedRoyaltyPolicies(childIpId);
    expect(accumulatedPolicies.length).to.be.greaterThan(0);
    console.log("Accumulated royalty policies: ", accumulatedPolicies.length);

    // Verify global royalty stack is calculated
    const globalRoyaltyStack = await user2ConnectedRoyaltyModule.globalRoyaltyStack(childIpId);
    expect(globalRoyaltyStack).to.be.greaterThan(0);
    console.log("Global royalty stack: ", globalRoyaltyStack.toString());
    
    console.log("Linking to parents works correctly after vault deployment");
  });

  it("Should revert when trying to deploy vault for group IP with non-whitelisted reward pool", async function () {
    console.log("============ Deploy Vault for Group IP with Non-Whitelisted Reward Pool Test ============");
    
    // Create a non-whitelisted reward pool address (using a random address)
    const nonWhitelistedRewardPool = "0x1234567890123456789012345678901234567890";
    
    // First, whitelist the non-whitelisted pool temporarily to create the group
    const adminConnectedGroupingModule = this.groupingModule.connect(signers[0]);
    await expect(
      adminConnectedGroupingModule.whitelistGroupRewardPool(nonWhitelistedRewardPool, true)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    
    // Verify it's whitelisted
    const isWhitelistedBefore = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(nonWhitelistedRewardPool);
    expect(isWhitelistedBefore).to.be.true;
    console.log("Temporarily whitelisted reward pool: ", nonWhitelistedRewardPool);

    // Register a group IP with the temporarily whitelisted reward pool
    const registerGroupTx = await expect(
      adminConnectedGroupingModule.registerGroup(nonWhitelistedRewardPool)
    ).not.to.be.rejectedWith(Error);
    const receipt = await registerGroupTx.wait();
    const groupId = receipt.logs[5].args[0];
    console.log("Registered group IP ID: ", groupId);

    // Verify it's a registered group
    const isRegisteredGroup = await this.ipAssetRegistry.isRegisteredGroup(groupId);
    expect(isRegisteredGroup).to.be.true;

    // Now remove the reward pool from whitelist
    await expect(
      adminConnectedGroupingModule.whitelistGroupRewardPool(nonWhitelistedRewardPool, false)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
    
    // Verify it's no longer whitelisted
    const isWhitelistedAfter = await this.ipAssetRegistry.isWhitelistedGroupRewardPool(nonWhitelistedRewardPool);
    expect(isWhitelistedAfter).to.be.false;
    console.log("Removed reward pool from whitelist: ", nonWhitelistedRewardPool);

    // Try to deploy vault for the group IP - should revert with GroupRewardPoolNotWhitelisted
    await expect(
      user1ConnectedRoyaltyModule.deployVault(groupId)
    ).to.be.revertedWithCustomError(this.royaltyModule, "RoyaltyModule__GroupRewardPoolNotWhitelisted");
    
    console.log("Correctly reverted with RoyaltyModule__GroupRewardPoolNotWhitelisted for non-whitelisted reward pool");
    
    // Clean up: re-whitelist the reward pool for potential future tests
    await expect(
      adminConnectedGroupingModule.whitelistGroupRewardPool(nonWhitelistedRewardPool, true)
    ).not.to.be.rejectedWith(Error).then((tx: any) => tx.wait());
  });
}); 