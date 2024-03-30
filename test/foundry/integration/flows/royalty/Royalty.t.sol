// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IRoyaltyModule } from "contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IpPool } from "contracts/modules/royalty/policies/IpPool.sol";
import { IIpPool } from "contracts/interfaces/modules/royalty/policies/IIpPool.sol";

// test
import { BaseIntegration } from "test/foundry/integration/BaseIntegration.t.sol";

contract Flows_Integration_Disputes is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for *;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    address internal royaltyPolicyAddr; // must be assigned AFTER super.setUp()
    address internal mintingFeeToken; // must be assigned AFTER super.setUp()
    uint32 internal defaultCommRevShare = 10 * 10 ** 6; // 10%
    uint256 internal mintingFee = 7 ether;

    function setUp() public override {
        super.setUp();

        // Register PIL Framework
        _setPILPolicyFrameworkManager();

        royaltyPolicyAddr = address(royaltyPolicyLAP);
        mintingFeeToken = address(erc20);

        // Register a License
        _mapPILPolicyCommercial({
            name: "commercial-remix",
            derivatives: true,
            reciprocal: true,
            commercialRevShare: defaultCommRevShare,
            royaltyPolicy: royaltyPolicyAddr,
            mintingFeeToken: mintingFeeToken,
            mintingFee: mintingFee
        });
        _registerPILPolicyFromMapping("commercial-remix");

        // Register an original work with both policies set
        mockNFT.mintId(u.alice, 1);
        mockNFT.mintId(u.bob, 2);
        mockNFT.mintId(u.carl, 3);
    }

    function test_Integration_Royalty() public {
        {
            vm.startPrank(u.alice);

            ipAcct[1] = _getIpId(mockNFT, 1);
            vm.label(ipAcct[1], "IPAccount1");

            registerIpAccount(mockNFT, 1, u.alice);
            licensingModule.addPolicyToIp(ipAcct[1], _getPilPolicyId("commercial-remix"));
            vm.stopPrank();
        }

        // Bob mints 1 license of policy "pil-commercial-remix" from IPAccount1 and registers the derivative IP for
        // NFT tokenId 2.
        {
            vm.startPrank(u.bob);

            ipAcct[2] = _getIpId(mockNFT, 2);
            vm.label(ipAcct[2], "IPAccount2");

            uint256 mintAmount = 3;
            erc20.approve(address(royaltyPolicyAddr), mintAmount * mintingFee);

            uint256[] memory licenseIds = new uint256[](1);

            vm.expectEmit(address(royaltyModule));
            emit IRoyaltyModule.LicenseMintingFeePaid(ipAcct[1], u.bob, address(erc20), mintAmount * mintingFee);
            licenseIds[0] = licensingModule.mintLicense(
                _getPilPolicyId("commercial-remix"),
                ipAcct[1],
                mintAmount,
                u.bob,
                ""
            );

            address ipId = ipAssetRegistry.register(address(mockNFT), 2);
            if (licenseIds.length != 0) {
                licensingModule.linkIpToParents(licenseIds, ipId, "");
            }
            vm.stopPrank();
        }

        // Carl mints 1 license of policy "pil-commercial-remix" from IPAccount1 and IPAccount2 and registers the
        // derivative IP for NFT tokenId 3. Thus, IPAccount3 is a derivative of both IPAccount1 and IPAccount2.
        // More precisely, IPAccount1 is a grandparent and IPAccount2 is a parent of IPAccount3.
        {
            vm.startPrank(u.carl);

            ipAcct[3] = _getIpId(mockNFT, 3);
            vm.label(ipAcct[3], "IPAccount3");

            uint256 mintAmount = 1;
            uint256[] memory licenseIds = new uint256[](2);

            erc20.approve(address(royaltyPolicyAddr), 2 * mintAmount * mintingFee);

            vm.expectEmit(address(royaltyModule));
            emit IRoyaltyModule.LicenseMintingFeePaid(ipAcct[1], u.carl, address(erc20), mintAmount * mintingFee);
            licenseIds[0] = licensingModule.mintLicense(
                _getPilPolicyId("commercial-remix"),
                ipAcct[1], // grandparent, root IP
                1,
                u.carl,
                ""
            );

            vm.expectEmit(address(royaltyModule));
            emit IRoyaltyModule.LicenseMintingFeePaid(ipAcct[2], u.carl, address(erc20), mintAmount * mintingFee);
            licenseIds[1] = licensingModule.mintLicense(
                _getPilPolicyId("commercial-remix"),
                ipAcct[2], // parent, is child IP of ipAcct[1]
                1,
                u.carl,
                ""
            );

            address ipId = ipAssetRegistry.register(address(mockNFT), 3);
            if (licenseIds.length != 0) {
                licensingModule.linkIpToParents(licenseIds, ipId, "");
            }
            vm.stopPrank();
        }

        // IPAccount1 and IPAccount2 have commercial policy, of which IPAccount3 has used to mint licenses and link.
        // Thus, any payment to IPAccount3 will get split to IPAccount1 and IPAccount2 accordingly to policy.

        uint256 totalPaymentToIpAcct3;

        // A new user, who likes IPAccount3, decides to pay IPAccount3 some royalty (1 token).
        {
            address newUser = address(0xbeef);
            vm.startPrank(newUser);

            mockToken.mint(newUser, 1 ether);

            mockToken.approve(address(royaltyPolicyLAP), 1 ether);
            // ipAcct[3] is the receiver, the actual token is paid by the caller (newUser).
            royaltyModule.payRoyaltyOnBehalf(ipAcct[3], ipAcct[3], address(mockToken), 1 ether);
            totalPaymentToIpAcct3 += 1 ether;

            vm.stopPrank();
        }

        // Owner of IPAccount2, Bob, claims his RTs from IPAccount3 pool
        {
            vm.startPrank(u.bob);

            ERC20[] memory tokens = new ERC20[](1);
            tokens[0] = mockToken;

            (, address ipPool, , , ) = royaltyPolicyLAP.getRoyaltyData(ipAcct[3]);

            vm.warp(block.timestamp + 7 days + 1);
            IpPool(ipPool).snapshot();

            vm.expectEmit(ipPool);
            emit IERC20.Transfer({ from: ipPool, to: ipAcct[2], value: 10_000_000 }); // 10%

            vm.expectEmit(ipPool);
            emit IIpPool.Claimed(ipAcct[2]);

            IpPool(ipPool).collectRoyaltyTokens(ipAcct[2]);
        }

        // Owner of IPAccount1, Alice, claims her RTs from IPAccount2 and IPAccount3 pools
        {
            vm.startPrank(u.alice);

            ERC20[] memory tokens = new ERC20[](1);
            tokens[0] = mockToken;

            (, address ipPool2, , , ) = royaltyPolicyLAP.getRoyaltyData(ipAcct[2]);
            (, address ipPool3, , , ) = royaltyPolicyLAP.getRoyaltyData(ipAcct[3]);

            vm.warp(block.timestamp + 7 days + 1);
            IpPool(ipPool2).snapshot();
            IpPool(ipPool3).snapshot();

            vm.expectEmit(ipPool2);
            emit IERC20.Transfer({ from: ipPool2, to: ipAcct[1], value: 10_000_000 }); // 10%
            vm.expectEmit(ipPool2);
            emit IIpPool.Claimed(ipAcct[1]);
            IpPool(ipPool2).collectRoyaltyTokens(ipAcct[1]);

            vm.expectEmit(ipPool3);
            // reason for 20%: absolute stack, so 10% from IPAccount2 and 10% from IPAccount3
            emit IERC20.Transfer({ from: ipPool3, to: ipAcct[1], value: 20_000_000 }); // 20%
            vm.expectEmit(ipPool3);
            emit IIpPool.Claimed(ipAcct[1]);
            IpPool(ipPool3).collectRoyaltyTokens(ipAcct[1]);
        }

        // Owner of IPAccount2, Bob, takes snapshot on IPAccount3 pool and claims his revenue from IPAccount3 pool
        {
            vm.startPrank(u.bob);

            (, address ipPool, , , ) = royaltyPolicyLAP.getRoyaltyData(ipAcct[3]);

            // take snapshot
            vm.warp(block.timestamp + 7 days + 1);
            IpPool(ipPool).snapshot();

            address[] memory tokens = new address[](2);
            tokens[0] = address(mockToken);
            tokens[1] = address(LINK);

            IpPool(ipPool).claimRevenueByTokenBatch(1, tokens);

            vm.stopPrank();
        }

        // Owner of IPAccount1, Alice, takes snapshot on IPAccount2 pool and claims her revenue from both
        // IPAccount2 and IPAccount3 pools
        {
            vm.startPrank(u.alice);

            (, address ipPool2, , , ) = royaltyPolicyLAP.getRoyaltyData(ipAcct[2]);
            (, address ipPool3, , , ) = royaltyPolicyLAP.getRoyaltyData(ipAcct[3]);

            address[] memory tokens = new address[](2);
            tokens[0] = address(mockToken);
            tokens[1] = address(LINK);

            IpPool(ipPool3).claimRevenueByTokenBatch(1, tokens);

            // take snapshot
            vm.warp(block.timestamp + 7 days + 1);
            IpPool(ipPool2).snapshot();

            IpPool(ipPool2).claimRevenueByTokenBatch(1, tokens);
        }
    }
}
