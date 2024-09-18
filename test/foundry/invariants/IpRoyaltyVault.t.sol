/* solhint-disable no-console */
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { BaseTest } from "../utils/BaseTest.t.sol";
import { Test } from "forge-std/Test.sol";
import { IpRoyaltyVault } from "contracts/modules/royalty/policies/IpRoyaltyVault.sol";
import { RoyaltyModule } from "contracts/modules/royalty/RoyaltyModule.sol";

contract IpRoyaltyVaultHarness is Test {
    IpRoyaltyVault public vault;
    RoyaltyModule public royaltyModule;

    constructor(address _vault, address _royaltyModule) {
        vault = IpRoyaltyVault(_vault);
        royaltyModule = RoyaltyModule(_royaltyModule);
    }

    function snapshot() public {
        vault.snapshot();
    }

    function payRoyaltyOnBehalf(address receiverIpId, address payerIpId, address token, uint256 amount) external {
        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, token, amount);
    }

    function claimRevenueByTokenBatch(uint256 snapshotId, address[] calldata tokenList) public {
        vault.claimRevenueOnBehalfByTokenBatch(snapshotId, tokenList, address(this));
    }

    function claimRevenueBySnapshotBatch(uint256[] memory snapshotIds, address token) public {
        vault.claimRevenueOnBehalfBySnapshotBatch(snapshotIds, token, address(this));
    }

    function claimByTokenBatchAsSelf(uint256 snapshotId, address[] calldata tokenList, address targetIpId) public {
        vault.claimByTokenBatchAsSelf(snapshotId, tokenList, targetIpId);
    }

    function claimBySnapshotBatchAsSelf(uint256[] memory snapshotIds, address token, address targetIpId) public {
        vault.claimBySnapshotBatchAsSelf(snapshotIds, token, targetIpId);
    }

    function updateVaultBalance(address token, uint256 amount) public {
        vm.startPrank(address(royaltyModule));
        vault.updateVaultBalance(token, amount);
    }

    function warp() public {
        vm.warp(block.timestamp + 7 days + 1);
    }
}

contract IpRoyaltyVaultInvariant is BaseTest {
    IpRoyaltyVault public ipRoyaltyVault;
    IpRoyaltyVaultHarness public harness;
    address public ipId;

    function setUp() public override {
        super.setUp();

        vm.startPrank(u.admin);
        // whitelist royalty policy
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        royaltyModule.whitelistRoyaltyToken(address(LINK), true);
        royaltyModule.setSnapshotInterval(7 days);
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        _setupTree();
        vm.stopPrank();

        address vault = royaltyModule.ipRoyaltyVaults(address(50));
        ipRoyaltyVault = IpRoyaltyVault(vault);

        harness = new IpRoyaltyVaultHarness(address(ipRoyaltyVault), address(royaltyModule));

        USDC.mint(address(harness), 1000 * 10 ** 6);

        targetContract(address(harness));

        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = harness.snapshot.selector;
        selectors[1] = harness.claimRevenueByTokenBatch.selector;
        selectors[2] = harness.claimRevenueBySnapshotBatch.selector;
        selectors[3] = harness.payRoyaltyOnBehalf.selector;
        selectors[4] = harness.claimByTokenBatchAsSelf.selector;
        selectors[5] = harness.claimBySnapshotBatchAsSelf.selector;
        selectors[6] = harness.updateVaultBalance.selector;
        selectors[7] = harness.warp.selector;

        targetSelector(FuzzSelector(address(harness), selectors));

        ipId = ipRoyaltyVault.ipId();
    }

    function _setupTree() internal {
        // mint license for roots
        royaltyModule.onLicenseMinting(address(10), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        royaltyModule.onLicenseMinting(address(20), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        royaltyModule.onLicenseMinting(address(30), address(royaltyPolicyLRP), uint32(7 * 10 ** 6), "");

        // link 40 to parents
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(20);
        parents[2] = address(30);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[2] = address(royaltyPolicyLRP);
        parentRoyalties[0] = uint32(10 * 10 ** 6);
        parentRoyalties[1] = uint32(10 * 10 ** 6);
        parentRoyalties[2] = uint32(7 * 10 ** 6);
        ipGraph.addParentIp(address(40), parents);
        royaltyModule.onLinkToParents(address(40), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        // mint license for 40
        royaltyModule.onLicenseMinting(address(40), address(royaltyPolicyLRP), uint32(5 * 10 ** 6), "");

        // link 50 to 40
        parents = new address[](1);
        licenseRoyaltyPolicies = new address[](1);
        parentRoyalties = new uint32[](1);
        parents[0] = address(40);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLRP);
        parentRoyalties[0] = uint32(5 * 10 ** 6);
        ipGraph.addParentIp(address(50), parents);
        royaltyModule.onLinkToParents(address(50), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        // mint license for 50
        royaltyModule.onLicenseMinting(address(50), address(royaltyPolicyLRP), uint32(15 * 10 ** 6), "");

        // link 60 to 50
        parents = new address[](1);
        licenseRoyaltyPolicies = new address[](1);
        parentRoyalties = new uint32[](1);
        parents[0] = address(50);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLRP);
        parentRoyalties[0] = uint32(15 * 10 ** 6);
        ipGraph.addParentIp(address(60), parents);
        royaltyModule.onLinkToParents(address(60), parents, licenseRoyaltyPolicies, parentRoyalties, "");
    }

    /// @notice Invariant to check anyone's balance should be <= init (1000 * 10 ** 6)
    function invariant_usdc_balance() public {
        assertLe(USDC.balanceOf(address(harness)) + USDC.balanceOf(address(ipRoyaltyVault)), 1000 * 10 ** 6);
    }

    function invariant_impossibleChangeOfIpid() public {
        assertEq(ipRoyaltyVault.ipId(), ipId, "IP ID should not be changed");
    }
}
