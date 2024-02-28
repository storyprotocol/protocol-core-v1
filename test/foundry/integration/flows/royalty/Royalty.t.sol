// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract
import { IRoyaltyModule } from "contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicyLAP } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";

// test
import { BaseIntegration } from "test/foundry/integration/BaseIntegration.t.sol";

contract Flows_Integration_Disputes is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for *;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    bytes internal emptyRoyaltyPolicyLAPInitParams =
        abi.encode(
            IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](0),
                targetRoyaltyAmount: new uint32[](0),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            })
        );

    address internal royaltyPolicyAddr; // must be assigned AFTER super.setUp()
    address internal mintingFeeToken; // must be assigned AFTER super.setUp()
    uint32 internal defaultCommRevShare = 100;
    uint256 internal mintingFee = 7 ether;

    function setUp() public override {
        super.setUp();

        // Register PIL Framework
        _deployLFM_PIL();

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
                emptyRoyaltyPolicyLAPInitParams
            );

            IRoyaltyPolicyLAP.InitParams memory params = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](1),
                targetRoyaltyAmount: new uint32[](1),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            });
            params.targetAncestors[0] = ipAcct[1];
            params.targetRoyaltyAmount[0] = defaultCommRevShare;

            registrationModule.registerDerivativeIp(
                licenseIds,
                address(mockNFT),
                2,
                "IPAccount2",
                bytes32("some of the best description"),
                "https://example.com/best-derivative-ip",
                abi.encode(params)
            );

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
                emptyRoyaltyPolicyLAPInitParams
            );

            IRoyaltyPolicyLAP.InitParams memory params1 = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](1),
                targetRoyaltyAmount: new uint32[](1),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            });
            params1.targetAncestors[0] = ipAcct[1];
            params1.targetRoyaltyAmount[0] = defaultCommRevShare;

            vm.expectEmit(address(royaltyModule));
            emit IRoyaltyModule.LicenseMintingFeePaid(ipAcct[2], u.carl, address(erc20), mintAmount * mintingFee);
            licenseIds[1] = licensingModule.mintLicense(
                _getPilPolicyId("commercial-remix"),
                ipAcct[2], // parent, is child IP of ipAcct[1]
                1,
                u.carl,
                abi.encode(params1)
            );

            IRoyaltyPolicyLAP.InitParams memory params2 = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](2),
                targetRoyaltyAmount: new uint32[](2),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](1),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](1)
            });
            params2.targetAncestors[0] = ipAcct[1]; // grandparent
            params2.targetAncestors[1] = ipAcct[2]; // parent
            params2.targetRoyaltyAmount[0] = defaultCommRevShare * 2; // owed to grandparent (twice - royalty stack!)
            params2.targetRoyaltyAmount[1] = defaultCommRevShare; // owed to parent
            params2.parentAncestors2[0] = ipAcct[1];
            params2.parentAncestorsRoyalties2[0] = defaultCommRevShare;

            registrationModule.registerDerivativeIp(
                licenseIds,
                address(mockNFT),
                3,
                "IPAccount3",
                bytes32("some of the best description"),
                "https://example.com/best-derivative-ip",
                abi.encode(params2)
            );

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

        // Distribute the accrued revenue from the 0xSplitWallet associated with IPAccount3 to 0xSplits Main,
        // which will get distributed to IPAccount3 AND its claimer based on revenue sharing terms specified in the
        // royalty policy. Anyone can call this function. (Below, Dan calls as an example.)
        {
            vm.startPrank(u.dan);

            (, , address ipAcct3_ancestorVault, , ) = royaltyPolicyLAP.royaltyData(ipAcct[3]);

            address[] memory accounts = new address[](2);
            // If you face InvalidSplit__AccountsOutOfOrder, shuffle the order of accounts (swap index 0 and 1)
            accounts[1] = ipAcct[3];
            accounts[0] = ipAcct3_ancestorVault;

            royaltyPolicyLAP.distributeIpPoolFunds(ipAcct[3], address(mockToken), accounts, address(u.dan));

            vm.stopPrank();
        }

        // IPAccount2 claims its rNFTs and tokens, only done once since it's a direct chain
        {
            ERC20[] memory tokens = new ERC20[](1);
            tokens[0] = mockToken;

            (, , address ancestorVault_ipAcct3, , ) = royaltyPolicyLAP.royaltyData(ipAcct[3]);

            // First, release the money from the IPAccount3's 0xSplitWallet (that just received money) to the main
            // 0xSplitMain that acts as a ledger for revenue distribution.
            // vm.expectEmit(LIQUID_SPLIT_MAIN);
            // TODO: check Withdrawal(699999999999999998) (Royalty stack is 300, or 30% [absolute] sent to ancestors)
            royaltyPolicyLAP.claimFromIpPool({ account: ipAcct[3], tokens: tokens });
            royaltyPolicyLAP.claimFromIpPool({ account: ancestorVault_ipAcct3, tokens: tokens });

            // Bob (owner of IPAccount2) calls the claim her portion of rNFTs and tokens. He can only call
            // `claimFromAncestorsVault` once. Afterwards, she will automatically receive money on revenue distribution.

            address[] memory ancestors = new address[](2);
            uint32[] memory ancestorsRoyalties = new uint32[](2);
            ancestors[0] = ipAcct[1]; // grandparent
            ancestors[1] = ipAcct[2]; // parent (claimer)
            ancestorsRoyalties[0] = defaultCommRevShare * 2;
            ancestorsRoyalties[1] = defaultCommRevShare;

            // IPAccount2 wants to claim from IPAccount3
            royaltyPolicyLAP.claimFromAncestorsVault({
                ipId: ipAcct[3],
                claimerIpId: ipAcct[2],
                ancestors: ancestors,
                ancestorsRoyalties: ancestorsRoyalties,
                tokens: tokens
            });
        }

        // IPAccount1, which is both the grandparent and parent of IPAccount3, claims its rNFTs and tokens.
        {
            ERC20[] memory tokens = new ERC20[](1);
            tokens[0] = mockToken;

            (, address splitClone_ipAcct1, , , ) = royaltyPolicyLAP.royaltyData(ipAcct[1]);
            (, , address ancestorVault_ipAcct3, , ) = royaltyPolicyLAP.royaltyData(ipAcct[3]);

            uint256 balanceBefore_SplitClone_ipAcct1 = mockToken.balanceOf(ipAcct[1]);
            uint256 balanceBefore_AncestorVault_ipAcct3 = mockToken.balanceOf(ancestorVault_ipAcct3);

            address[] memory ancestors = new address[](2);
            uint32[] memory ancestorsRoyalties = new uint32[](2);
            ancestors[0] = ipAcct[1]; // grandparent (claimer)
            ancestors[1] = ipAcct[2]; // parent
            ancestorsRoyalties[0] = defaultCommRevShare * 2;
            ancestorsRoyalties[1] = defaultCommRevShare;

            // IPAccount1 wants to claim from IPAccount3 (gets RNFTs and tokens)
            royaltyPolicyLAP.claimFromAncestorsVault({
                ipId: ipAcct[3],
                claimerIpId: ipAcct[1],
                ancestors: ancestors,
                ancestorsRoyalties: ancestorsRoyalties,
                tokens: tokens
            });

            uint256 balanceAfter_SplitClone_ipAcct1 = mockToken.balanceOf(ipAcct[1]);
            uint256 balanceAfter_AncestorVault_ipAcct3 = mockToken.balanceOf(ancestorVault_ipAcct3);

            // IPAccount1's split clone should receive 30% of the total payment to IPAccount3
            assertApproxEqAbs(
                balanceAfter_SplitClone_ipAcct1 - balanceBefore_SplitClone_ipAcct1,
                // should be 200 * 2 * 1 ether / 1000
                (defaultCommRevShare * 2 * totalPaymentToIpAcct3) / 1000,
                100
            );
            // All money in ancestor vault of IPAccount3 must be sent to IPAccount1's split clone
            assertEq(
                balanceAfter_SplitClone_ipAcct1 - balanceBefore_SplitClone_ipAcct1,
                balanceBefore_AncestorVault_ipAcct3
            );
            assertEq(balanceAfter_AncestorVault_ipAcct3, 0);
        }
    }
}
