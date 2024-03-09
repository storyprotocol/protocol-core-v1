// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// contract
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { IP } from "../../../../contracts/lib/IP.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { PILPolicy } from "../../../../contracts/modules/licensing/PILPolicyFrameworkManager.sol";
import { IRoyaltyPolicyLAP } from "../../../../contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";
import { MockTokenGatedHook } from "../../mocks/MockTokenGatedHook.sol";
import { MockERC721 } from "../../mocks/token/MockERC721.sol";

contract BigBang_Integration_SingleNftCollection is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;

    MockTokenGatedHook internal mockTokenGatedHook;

    MockERC721 internal mockGatedNft;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    mapping(string name => uint256 licenseId) internal licenseIds;

    bytes internal emptyRoyaltyPolicyLAPInitParams;

    uint32 internal constant derivCheapFlexibleRevShare = 10;

    uint256 internal constant mintingFee = 100 ether;

    function setUp() public override {
        super.setUp();

        mockTokenGatedHook = new MockTokenGatedHook();
        mockGatedNft = new MockERC721("MockGatedNft");

        // Add PIL PFM policies

        _setPILPolicyFrameworkManager();

        _addPILPolicyWihtMintPayment(
            "com_deriv_cheap_flexible", // ==> policyIds["pil_com_deriv_cheap_flexible"]
            true,
            address(royaltyPolicyLAP),
            mintingFee,
            address(mockToken),
            PILPolicy({
                attribution: false,
                commercialUse: true,
                commercialAttribution: true,
                commercializerChecker: address(mockTokenGatedHook),
                commercializerCheckerData: abi.encode(address(mockGatedNft)),
                commercialRevShare: derivCheapFlexibleRevShare,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: false,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            })
        );

        _addPILPolicy(
            "noncom_deriv_reciprocal_derivative", // ==> policyIds["pil_noncom_deriv_reciprocal_derivative"]
            false,
            address(0),
            PILPolicy({
                attribution: false,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            })
        );

        emptyRoyaltyPolicyLAPInitParams = abi.encode(
            IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](0),
                targetRoyaltyAmount: new uint32[](0),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            })
        );
    }

    function test_Integration_SingleNftCollection_DirectCallsByIPAccountOwners() public {
        /*//////////////////////////////////////////////////////////////
                                REGISTER IP ACCOUNTS
        ///////////////////////////////////////////////////////////////*/

        // ipAcct[tokenId] => ipAccount address
        // owner is the vm.pranker

        vm.startPrank(u.alice);
        mockNFT.mintId(u.alice, 1);
        mockNFT.mintId(u.alice, 100);
        ipAcct[1] = registerIpAccount(mockNFT, 1, u.alice);
        ipAcct[100] = registerIpAccount(mockNFT, 100, u.alice);

        vm.startPrank(u.bob);
        mockNFT.mintId(u.bob, 3);
        mockNFT.mintId(u.bob, 300);
        ipAcct[3] = registerIpAccount(mockNFT, 3, u.bob);
        ipAcct[300] = registerIpAccount(mockNFT, 300, u.bob);

        vm.startPrank(u.carl);
        mockNFT.mintId(u.carl, 5);
        ipAcct[5] = registerIpAccount(mockNFT, 5, u.carl);

        /*//////////////////////////////////////////////////////////////
                            ADD POLICIES TO IP ACCOUNTS
        ///////////////////////////////////////////////////////////////*/

        vm.startPrank(u.alice);
        licensingModule.addPolicyToIp(ipAcct[1], policyIds["pil_com_deriv_cheap_flexible"]);
        licensingModule.addPolicyToIp(ipAcct[100], policyIds["pil_noncom_deriv_reciprocal_derivative"]);

        vm.startPrank(u.bob);
        licensingModule.addPolicyToIp(ipAcct[3], policyIds["pil_com_deriv_cheap_flexible"]);
        licensingModule.addPolicyToIp(ipAcct[300], policyIds["pil_com_deriv_cheap_flexible"]);

        vm.startPrank(u.bob);
        // NOTE: the two calls below achieve the same functionality
        // licensingModule.addPolicyToIp(ipAcct[3], policyIds["pil_noncom_deriv_reciprocal_derivative"]);
        IIPAccount(payable(ipAcct[3])).execute(
            address(licensingModule),
            0,
            abi.encodeWithSignature(
                "addPolicyToIp(address,uint256)",
                ipAcct[3],
                policyIds["pil_noncom_deriv_reciprocal_derivative"]
            )
        );

        /*///////////////////////////////////////////////////////////////
                                MINT & USE LICENSES
        ///////////////////////////////////////////////////////////////*/

        // Carl mints 1 license for policy "com_deriv_all_true" on Alice's NFT 1 IPAccount
        // Carl creates NFT 6 IPAccount
        // Carl activates the license on his NFT 6 IPAccount, linking as child to Alice's NFT 1 IPAccount
        {
            vm.startPrank(u.carl);
            mockNFT.mintId(u.carl, 6);

            // Carl needs to hold an NFT from mockGatedNFT collection to mint license pil_com_deriv_cheap_flexible
            // (verified by the mockTokenGatedHook commercializer checker)
            mockGatedNft.mint(u.carl);

            mockToken.approve(address(royaltyPolicyLAP), mintingFee);

            uint256[] memory carl_license_from_root_alice = new uint256[](1);
            carl_license_from_root_alice[0] = licensingModule.mintLicense(
                policyIds["pil_com_deriv_cheap_flexible"],
                ipAcct[1],
                1,
                u.carl,
                emptyRoyaltyPolicyLAPInitParams
            );

            ipAcct[6] = registerIpAccount(mockNFT, 6, u.carl);

            IRoyaltyPolicyLAP.InitParams memory params = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](1),
                targetRoyaltyAmount: new uint32[](1),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            });
            params.targetAncestors[0] = ipAcct[1];
            params.targetRoyaltyAmount[0] = derivCheapFlexibleRevShare;

            linkIpToParents(carl_license_from_root_alice, ipAcct[6], u.carl, abi.encode(params));
        }

        // Carl mints 2 license for policy "pil_noncom_deriv_reciprocal_derivative" on Bob's NFT 3 IPAccount
        // Carl creates NFT 7 IPAccount
        // Carl activates one of the two licenses on his NFT 7 IPAccount, linking as child to Bob's NFT 3 IPAccount
        {
            vm.startPrank(u.carl);
            mockNFT.mintId(u.carl, 7); // NFT for Carl's IPAccount7

            // Carl is minting license on non-commercial policy, so no commercializer checker is involved.
            // Thus, no need to mint anything (although Carl already has mockGatedNft from above)

            uint256[] memory carl_license_from_root_bob = new uint256[](1);
            carl_license_from_root_bob[0] = licensingModule.mintLicense(
                policyIds["pil_noncom_deriv_reciprocal_derivative"],
                ipAcct[3],
                1,
                u.carl,
                emptyRoyaltyPolicyLAPInitParams
            );

            IRoyaltyPolicyLAP.InitParams memory royaltyContextRegister = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](1),
                targetRoyaltyAmount: new uint32[](1),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            });
            royaltyContextRegister.targetAncestors[0] = ipAcct[3];
            royaltyContextRegister.targetRoyaltyAmount[0] = 0;

            // TODO: events check
            ipAssetRegistry.register(
                carl_license_from_root_bob,
                abi.encode(royaltyContextRegister),
                block.chainid,
                address(mockNFT),
                7,
                address(ipResolver),
                true,
                abi.encode(
                    IP.MetadataV1({
                        name: "IP NAME",
                        hash: bytes32("hash"),
                        registrationDate: uint64(block.timestamp),
                        registrant: u.carl, // caller
                        uri: "external URL"
                    })
                )
            );
        }

        // Alice mints 2 license for policy "pil_com_deriv_cheap_flexible" on Bob's NFT 3 IPAccount
        // Alice creates NFT 2 IPAccount
        // Alice activates one of the two licenses on her NFT 2 IPAccount, linking as child to Bob's NFT 3 IPAccount
        // Alice creates derivative NFT 3 directly using the other license
        {
            vm.startPrank(u.alice);
            mockNFT.mintId(u.alice, 2);
            uint256 mintAmount = 2;

            mockToken.approve(address(royaltyPolicyLAP), mintAmount * mintingFee);

            // Alice needs to hold an NFT from mockGatedNFT collection to mint license on pil_com_deriv_cheap_flexible
            // (verified by the mockTokenGatedHook commercializer checker)
            mockGatedNft.mint(u.alice);

            uint256[] memory alice_license_from_root_bob = new uint256[](1);
            alice_license_from_root_bob[0] = licensingModule.mintLicense(
                policyIds["pil_com_deriv_cheap_flexible"],
                ipAcct[3],
                mintAmount,
                u.alice,
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
            params.targetAncestors[0] = ipAcct[3];
            params.targetRoyaltyAmount[0] = derivCheapFlexibleRevShare;

            ipAcct[2] = registerIpAccount(mockNFT, 2, u.alice);
            linkIpToParents(alice_license_from_root_bob, ipAcct[2], u.alice, abi.encode(params));

            uint256 tokenId = 99999999;
            mockNFT.mintId(u.alice, tokenId);

            ipAcct[tokenId] = registerDerivativeIps(
                alice_license_from_root_bob,
                address(mockNFT),
                tokenId,
                IP.MetadataV1({
                    name: "IP NAME",
                    hash: bytes32("hash"),
                    registrationDate: uint64(block.timestamp),
                    registrant: u.alice, // caller
                    uri: "external URL"
                }),
                u.alice, // caller
                abi.encode(params)
            );
        }

        // Carl mints licenses and linkts to multiple parents
        // Carl creates NFT 6 IPAccount
        // Carl activates the license on his NFT 6 IPAccount, linking as child to Alice's NFT 1 IPAccount
        {
            vm.startPrank(u.carl);

            uint256 license0_mintAmount = 1000;
            uint256 tokenId = 70000; // dummy number that shouldn't conflict with any other token IDs used in this test
            mockNFT.mintId(u.carl, tokenId);

            mockToken.mint(u.carl, mintingFee * license0_mintAmount);
            mockToken.approve(address(royaltyPolicyLAP), mintingFee * license0_mintAmount);

            IP.MetadataV1 memory metadata = IP.MetadataV1({
                name: "IP NAME",
                hash: bytes32("hash"),
                registrationDate: uint64(block.timestamp),
                registrant: u.carl, // caller
                uri: "external URL"
            });

            uint256[] memory carl_licenses = new uint256[](2);
            // Commercial license (Carl already has mockGatedNft from above, so he passes commercializer checker check)
            carl_licenses[0] = licensingModule.mintLicense(
                policyIds["pil_com_deriv_cheap_flexible"], // ipAcct[1] has this policy attached
                ipAcct[1],
                license0_mintAmount,
                u.carl,
                emptyRoyaltyPolicyLAPInitParams
            );

            // Non-commercial license
            carl_licenses[1] = licensingModule.mintLicense(
                policyIds["pil_noncom_deriv_reciprocal_derivative"], // ipAcct[3] has this policy attached
                ipAcct[3],
                1,
                u.carl,
                emptyRoyaltyPolicyLAPInitParams
            );

            // This should revert since license[0] is commercial but license[1] is non-commercial
            vm.expectRevert(Errors.LicensingModule__IncompatibleLicensorCommercialPolicy.selector);
            ipAssetRegistry.register(
                carl_licenses,
                emptyRoyaltyPolicyLAPInitParams,
                block.chainid,
                address(mockNFT),
                tokenId,
                address(ipResolver),
                true,
                abi.encode(metadata)
            );

            uint256 license1_mintAmount = 500;
            mockToken.mint(u.carl, mintingFee * license1_mintAmount);
            mockToken.approve(address(royaltyPolicyLAP), mintingFee * license1_mintAmount);

            // Modify license[1] to a Commercial license
            carl_licenses[1] = licensingModule.mintLicense(
                policyIds["pil_com_deriv_cheap_flexible"], // ipAcct[300] has this policy attached
                ipAcct[300],
                license1_mintAmount,
                u.carl,
                emptyRoyaltyPolicyLAPInitParams
            );

            // Linking 2 licenses, ID 1 and ID 4.
            // These licenses are from 2 different parents, ipAcct[1] and ipAcct[300], respectively.
            IRoyaltyPolicyLAP.InitParams memory params = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](2),
                targetRoyaltyAmount: new uint32[](2),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            });
            params.targetAncestors[0] = ipAcct[1];
            params.targetAncestors[1] = ipAcct[300];
            params.targetRoyaltyAmount[0] = derivCheapFlexibleRevShare;
            params.targetRoyaltyAmount[1] = derivCheapFlexibleRevShare;

            // This should succeed since both license[0] and license[1] are commercial
            registerDerivativeIps(
                carl_licenses, // ipAcct[1] and ipAcct[3] licenses
                address(mockNFT),
                tokenId,
                metadata,
                u.carl, // caller
                abi.encode(params)
            );
        }
    }
}
