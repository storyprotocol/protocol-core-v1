/* solhint-disable no-console */
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { BaseTest } from "../utils/BaseTest.t.sol";
import { Test } from "forge-std/Test.sol";
import { DisputeModule } from "contracts/modules/dispute/DisputeModule.sol";
import { IIPAssetRegistry } from "contracts/interfaces/registries/IIPAssetRegistry.sol";
import { PILFlavors } from "../../../contracts/lib/PILFlavors.sol";

/// @notice Harness contract for DisputeModule
contract DisputeHarness is Test {
    /// @notice DisputeModule contract
    DisputeModule public disputeModule;

    /// @notice IPAssetRegistry contract
    IIPAssetRegistry public ipAssetRegistry;

    /// @notice Array of dispute tags
    bytes32[] public tags;

    /// @notice Array of IP accounts
    address[] public ipAccounts;

    /// @notice Counter to keep track of successful dispute operations
    uint256 public counter;

    constructor(
        address _disputeModule,
        address _ipAssetRegistry,
        bytes32[] memory _tags,
        address[] memory _ipAccounts
    ) {
        disputeModule = DisputeModule(_disputeModule);
        ipAssetRegistry = IIPAssetRegistry(_ipAssetRegistry);
        tags = _tags;
        ipAccounts = _ipAccounts;

        // push some invalid tags
        tags.push("invalid");
        tags.push("invalid1");

        // push some invalid ipAccounts
        ipAccounts.push(address(0));
        ipAccounts.push(address(1));
        ipAccounts.push(address(2));
    }

    /// @notice Function to raise a dispute
    /// @dev This function is used to raise a dispute, and catch any revert.
    /// It increments the counter if the dispute is raised successfully
    function raiseDispute(
        uint256 targetIpIdIdx,
        bytes32 disputeEvidenceHash,
        uint256 targetTagIdx,
        bytes calldata data
    ) public {
        try
            disputeModule.raiseDispute(
                ipAccounts[targetIpIdIdx % ipAccounts.length],
                disputeEvidenceHash,
                tags[targetTagIdx % tags.length],
                data
            )
        {
            counter++;
        } catch {}
    }

    /// @notice Function to set dispute judgement
    function setDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) public {
        try disputeModule.setDisputeJudgement(disputeId, decision, data) {} catch {}
    }

    /// @notice Function to cancel a dispute
    function cancelDispute(uint256 disputeId, bytes calldata data) public {
        try disputeModule.cancelDispute(disputeId, data) {} catch {}
    }

    /// @notice Function to tag derivative if parent infringed
    function tagDerivativeIfParentInfringed(
        uint256 parentIpIdIdx,
        uint256 derivativeIpIdIdx,
        uint256 parentDisputeId
    ) public {
        try
            disputeModule.tagDerivativeIfParentInfringed(
                ipAccounts[parentIpIdIdx % ipAccounts.length],
                ipAccounts[derivativeIpIdIdx % ipAccounts.length],
                parentDisputeId
            )
        {
            counter++;
        } catch {}
    }

    /// @notice Function to resolve a dispute
    function resolveDispute(uint256 disputeId, bytes calldata data) public {
        try disputeModule.resolveDispute(disputeId, data) {} catch {}
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract DisputeInvariants is BaseTest {
    /// @notice DisputeHarness contract
    DisputeHarness public harness;

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setUp() public virtual override {
        super.setUp();

        bytes32[] memory tags = new bytes32[](10);
        tags[0] = "INAPPROPRIATE_CONTENT";
        tags[1] = "COPYRIGHT_INFRINGEMENT";
        tags[2] = "TRADEMARK_INFRINGEMENT";
        tags[3] = "PLAGIARISM";
        tags[4] = "RANDOM_TAG5";
        tags[5] = "RANDOM_TAG";
        tags[6] = "RANDOM_TAG1";
        tags[7] = "RANDOM_TAG2";
        tags[8] = "RANDOM_TAG3";
        tags[9] = "RANDOM_TAG4";

        vm.startPrank(u.admin);
        for (uint256 i = 0; i < tags.length; i++) {
            disputeModule.whitelistDisputeTag((tags[i]), true);
        }
        vm.stopPrank();

        mockNFT.mintId(address(this), 300);
        mockNFT.mintId(address(this), 301);

        address _ipAccount = ipAssetRegistry.register(block.chainid, address(mockNFT), 300);
        address _ipAccount1 = ipAssetRegistry.register(block.chainid, address(mockNFT), 301);

        address[] memory ipAccounts = new address[](2);
        ipAccounts[0] = _ipAccount;
        ipAccounts[1] = _ipAccount1;

        harness = new DisputeHarness(address(disputeModule), address(ipAssetRegistry), tags, ipAccounts);

        mockToken.mint(address(harness), 1000 ether);
        vm.startPrank(address(harness));
        mockToken.approve(address(mockArbitrationPolicy), type(uint256).max);
        vm.stopPrank();
        mockNFT.transferFrom(address(this), address(harness), 300);
        mockNFT.transferFrom(address(this), address(harness), 301);

        uint256 commRemixTermsId = registerSelectedPILicenseTerms(
            "commercial_remix",
            PILFlavors.commercialRemix({
                commercialRevShare: 100,
                mintingFee: 1 ether,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(USDC)
            })
        );

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commRemixTermsId;

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = _ipAccount;

        vm.prank(address(harness));
        mockToken.approve(address(royaltyModule), type(uint256).max);

        vm.prank(address(harness));
        licensingModule.attachLicenseTerms(_ipAccount, address(pilTemplate), commRemixTermsId);

        vm.prank(address(harness));
        licensingModule.registerDerivative({
            childIpId: _ipAccount1,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: ""
        });

        /*         targetContract(address(harness));

        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = harness.raiseDispute.selector;
        selectors[1] = harness.setDisputeJudgement.selector;
        selectors[2] = harness.cancelDispute.selector;
        selectors[3] = harness.tagDerivativeIfParentInfringed.selector;
        selectors[4] = harness.resolveDispute.selector;
        targetSelector(FuzzSelector(address(harness), selectors)); */
    }

    /// @notice Invariant to check dispute id should be equal to counter
    function invariant_dispute_id() public {
        assertEq(harness.counter(), disputeModule.disputeCounter());
    }

    /// @notice Invariant to check dispute
    function invariant_dispute() public {
        // get last dispute
        uint256 disputeCounter = disputeModule.disputeCounter();
        if (disputeCounter > 0) {
            (
                address targetIpId,
                address disputeInitiator,
                address arbitrationPolicy,
                bytes32 _disputeEvidenceHash,
                bytes32 targetTag,
                bytes32 _currentTag,
                uint256 parentDisputeId
            ) = disputeModule.disputes(disputeCounter);

            assertTrue(ipAssetRegistry.isRegistered(targetIpId), "targetIpId not registered");

            assertNotEq(disputeInitiator, address(0), "zero address disputeInitiator");
            assertNotEq(arbitrationPolicy, address(0), "zero address arbitrationPolicy");

            assertNotEq(targetTag, bytes32("IN_DISPUTE"), "targetTag should not be IN_DISPUTE");

            // parentDisputeId either 0, or less than current dispute id
            assertLe(parentDisputeId + 1, disputeCounter, "parentDisputeId should be less than current dispute id");
        }
    }
}
