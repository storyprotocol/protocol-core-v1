/* solhint-disable no-console */
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

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
        vault.claimRevenueByTokenBatch(snapshotId, tokenList);
    }

    function claimRevenueBySnapshotBatch(uint256[] memory snapshotIds, address token) public {
        vault.claimRevenueBySnapshotBatch(snapshotIds, token);
    }

    function collectRoyaltyTokens(address ancestorIpId) public {
        vault.collectRoyaltyTokens(ancestorIpId);
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
        royaltyPolicyLAP.setSnapshotInterval(7 days);
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));
        _setupMaxUniqueTree();
        vm.stopPrank();

        (, address IpRoyaltyVault2, ) = royaltyPolicyLAP.getRoyaltyData(address(2));
        ipRoyaltyVault = IpRoyaltyVault(IpRoyaltyVault2);

        harness = new IpRoyaltyVaultHarness(address(ipRoyaltyVault), address(royaltyModule));

        USDC.mint(address(harness), 1000 * 10 ** 6);

        targetContract(address(harness));

        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = harness.snapshot.selector;
        selectors[1] = harness.claimRevenueByTokenBatch.selector;
        selectors[2] = harness.claimRevenueBySnapshotBatch.selector;
        selectors[3] = harness.collectRoyaltyTokens.selector;
        selectors[4] = harness.warp.selector;
        selectors[5] = harness.payRoyaltyOnBehalf.selector;

        targetSelector(FuzzSelector(address(harness), selectors));

        ipId = ipRoyaltyVault.ipId();
    }

    function _setupMaxUniqueTree() internal {
        // init royalty policy for roots
        royaltyPolicyLAP.onLicenseMinting(address(7), abi.encode(uint32(7)), "");
        royaltyPolicyLAP.onLicenseMinting(address(8), abi.encode(uint32(8)), "");
        royaltyPolicyLAP.onLicenseMinting(address(9), abi.encode(uint32(9)), "");
        royaltyPolicyLAP.onLicenseMinting(address(10), abi.encode(uint32(10)), "");
        royaltyPolicyLAP.onLicenseMinting(address(11), abi.encode(uint32(11)), "");
        royaltyPolicyLAP.onLicenseMinting(address(12), abi.encode(uint32(12)), "");
        royaltyPolicyLAP.onLicenseMinting(address(13), abi.encode(uint32(13)), "");
        royaltyPolicyLAP.onLicenseMinting(address(14), abi.encode(uint32(14)), "");

        // init 2nd level with children
        address[] memory parents = new address[](2);
        uint32[] memory parentRoyalties1 = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);

        // 100 is child of 7 and 8
        parents[0] = address(7);
        parents[1] = address(8);
        parentRoyalties1[0] = 7 * 10 ** 5;
        parentRoyalties1[1] = 8 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(100), parents, encodedLicenseData, "");

        // 4 is child of 9 and 10
        parents[0] = address(9);
        parents[1] = address(10);
        parentRoyalties1[0] = 9 * 10 ** 5;
        parentRoyalties1[1] = 10 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(4), parents, encodedLicenseData, "");

        // 5 is child of 11 and 12
        parents[0] = address(11);
        parents[1] = address(12);
        parentRoyalties1[0] = 11 * 10 ** 5;
        parentRoyalties1[1] = 12 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(5), parents, encodedLicenseData, "");

        // 6 is child of 13 and 14
        parents[0] = address(13);
        parents[1] = address(14);
        parentRoyalties1[0] = 13 * 10 ** 5;
        parentRoyalties1[1] = 14 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(6), parents, encodedLicenseData, "");

        // init 3rd level with children
        // 1 is child of 100 and 4
        parents[0] = address(100);
        parents[1] = address(4);
        parentRoyalties1[0] = 3 * 10 ** 5;
        parentRoyalties1[1] = 4 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(1), parents, encodedLicenseData, "");

        // 2 is child of 5 and 6
        parents[0] = address(5);
        parents[1] = address(6);
        parentRoyalties1[0] = 5 * 10 ** 5;
        parentRoyalties1[1] = 6 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(2), parents, encodedLicenseData, "");

        address[] memory parentsIpIds100 = new address[](2);
        parentsIpIds100 = new address[](2);
        parentsIpIds100[0] = address(1);
        parentsIpIds100[1] = address(2);

        parents[0] = address(1);
        parents[1] = address(2);
        parentRoyalties1[0] = 1 * 10 ** 5;
        parentRoyalties1[1] = 2 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }

        vm.startPrank(address(licensingModule));
        royaltyModule.onLinkToParents(address(3), address(royaltyPolicyLAP), parents, encodedLicenseData, "");
    }

    /// @notice Invariant to check anyone's balance should be <= init (1000 * 10 ** 6)
    function invariant_usdc_balance() public {
        assertLe(USDC.balanceOf(address(harness)) + USDC.balanceOf(address(ipRoyaltyVault)), 1000 * 10 ** 6);
    }

    function invariant_impossibleChangeOfIpid() public {
        assertEq(ipRoyaltyVault.ipId(), ipId, "IP ID should not be changed");
    }
}
