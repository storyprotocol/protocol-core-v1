// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { ERC6551AccountLib } from "erc6551/lib/ERC6551AccountLib.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { IIPAccountRegistry } from "contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IIPAssetRegistry } from "contracts/interfaces/registries/IIPAssetRegistry.sol";
import { ILicensingModule } from "contracts/interfaces/modules/licensing/ILicensingModule.sol";

// test
import { MockERC721 } from "test/foundry/mocks/token/MockERC721.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

contract BaseIntegration is BaseTest {
    using Strings for *;
    function setUp() public virtual override(BaseTest) {
        super.setUp();

        dealMockAssets();

        vm.prank(u.admin);
        royaltyPolicyLAP.setSnapshotInterval(7 days);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function registerIpAccount(address nft, uint256 tokenId, address caller) internal returns (address) {
        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            nft,
            tokenId
        );

        vm.label(expectedAddr, string(abi.encodePacked("IPAccount", Strings.toString(tokenId))));

        // expect all events below when calling `ipAssetRegistry.register`

        vm.expectEmit();
        emit IERC6551Registry.ERC6551AccountCreated({
            account: expectedAddr,
            implementation: address(ipAccountImpl),
            salt: ipAccountRegistry.IP_ACCOUNT_SALT(),
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId
        });

        vm.expectEmit();
        emit IIPAccountRegistry.IPAccountRegistered({
            account: expectedAddr,
            implementation: address(ipAccountImpl),
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId
        });

        vm.expectEmit();
        emit IIPAssetRegistry.IPRegistered({
            ipId: expectedAddr,
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId,
            name: string.concat(block.chainid.toString(), ": Ape #", tokenId.toString()),
            uri: string.concat("https://storyprotocol.xyz/erc721/", tokenId.toString()),
            registrationDate: block.timestamp
        });

        // policyId = 0 means no policy attached directly on creation
        vm.startPrank(caller);
        return ipAssetRegistry.register(nft, tokenId);
    }

    function registerIpAccount(MockERC721 nft, uint256 tokenId, address caller) internal returns (address) {
        return registerIpAccount(address(nft), tokenId, caller);
    }

    function registerDerivativeIps(
        uint256[] memory licenseIds,
        address nft,
        uint256 tokenId,
        address caller,
        bytes memory royaltyContext
    ) internal returns (address) {
        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            nft,
            tokenId
        );

        vm.label(expectedAddr, string(abi.encodePacked("IPAccount", Strings.toString(tokenId))));

        uint256[] memory policyIds = new uint256[](licenseIds.length);
        address[] memory parentIpIds = new address[](licenseIds.length);
        for (uint256 i = 0; i < licenseIds.length; i++) {
            policyIds[i] = licenseRegistry.policyIdForLicense(licenseIds[i]);
            parentIpIds[i] = licenseRegistry.licensorIpId(licenseIds[i]);
        }

        vm.expectEmit();
        emit IERC6551Registry.ERC6551AccountCreated({
            account: expectedAddr,
            implementation: address(ipAccountImpl),
            salt: ipAccountRegistry.IP_ACCOUNT_SALT(),
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId
        });

        vm.expectEmit();
        emit IIPAccountRegistry.IPAccountRegistered({
            account: expectedAddr,
            implementation: address(ipAccountImpl),
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId
        });

        vm.expectEmit();
        emit IIPAssetRegistry.IPRegistered({
            ipId: expectedAddr,
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId,
            name: string.concat(block.chainid.toString(), ": Ape #", tokenId.toString()),
            uri: string.concat("https://storyprotocol.xyz/erc721/", tokenId.toString()),
            registrationDate: block.timestamp
        });

        address ipId = ipAssetRegistry.register(nft, tokenId);

        _expectPolicyAddedToIpId(caller, expectedAddr, licenseIds, policyIds);

        vm.expectEmit();
        emit ILicensingModule.IpIdLinkedToParents({ caller: caller, ipId: expectedAddr, parentIpIds: parentIpIds });

        if (licenseIds.length == 1) {
            vm.expectEmit();
            emit IERC1155.TransferSingle({
                operator: address(licensingModule),
                from: caller,
                to: address(0), // burn addr
                id: licenseIds[0],
                value: 1
            });
        } else {
            uint256[] memory values = new uint256[](licenseIds.length);
            for (uint256 i = 0; i < licenseIds.length; ++i) {
                values[i] = 1;
            }

            vm.expectEmit();
            emit IERC1155.TransferBatch({
                operator: address(licensingModule),
                from: caller,
                to: address(0), // burn addr
                ids: licenseIds,
                values: values
            });
        }

        vm.startPrank(caller);
        licensingModule.linkIpToParents(licenseIds, ipId, royaltyContext);
        return expectedAddr;
    }

    function registerDerivativeIp(
        uint256 licenseId,
        address nft,
        uint256 tokenId,
        address caller,
        bytes memory royaltyContext
    ) internal returns (address) {
        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;
        return registerDerivativeIps(licenseIds, nft, tokenId, caller, royaltyContext);
    }

    function linkIpToParents(
        uint256[] memory licenseIds,
        address ipId,
        address caller,
        bytes memory royaltyContext
    ) internal {
        uint256[] memory policyIds = new uint256[](licenseIds.length);
        address[] memory parentIpIds = new address[](licenseIds.length);
        uint256[] memory prevLicenseAmounts = new uint256[](licenseIds.length);
        uint256[] memory values = new uint256[](licenseIds.length);

        for (uint256 i = 0; i < licenseIds.length; i++) {
            policyIds[i] = licenseRegistry.policyIdForLicense(licenseIds[i]);
            parentIpIds[i] = licenseRegistry.licensorIpId(licenseIds[i]);
            prevLicenseAmounts[i] = licenseRegistry.balanceOf(caller, licenseIds[i]);
            values[i] = 1;
            vm.expectEmit();
            emit ILicensingModule.PolicyAddedToIpId({
                caller: caller,
                ipId: ipId,
                policyId: policyIds[i],
                index: i,
                isInherited: true
            });
        }

        vm.expectEmit();
        emit ILicensingModule.IpIdLinkedToParents({ caller: caller, ipId: ipId, parentIpIds: parentIpIds });

        if (licenseIds.length == 1) {
            vm.expectEmit();
            emit IERC1155.TransferSingle({
                operator: address(licensingModule),
                from: caller,
                to: address(0), // burn addr
                id: licenseIds[0],
                value: 1
            });
        } else {
            vm.expectEmit();
            emit IERC1155.TransferBatch({
                operator: caller,
                from: caller,
                to: address(0), // burn addr
                ids: licenseIds,
                values: values
            });
        }

        vm.startPrank(caller);
        licensingModule.linkIpToParents(licenseIds, ipId, royaltyContext);

        for (uint256 i = 0; i < licenseIds.length; i++) {
            assertEq(
                licenseRegistry.balanceOf(caller, licenseIds[i]),
                prevLicenseAmounts[i] - 1,
                "license not burnt on linking"
            );
            assertTrue(licensingModule.isParent(parentIpIds[i], ipId), "parent IP account is not parent");
            (uint256 index, bool isInherited, ) = licensingModule.policyStatus(parentIpIds[i], policyIds[i]);
            assertEq(
                keccak256(abi.encode(licensingModule.policyForIpAtIndex(isInherited, parentIpIds[i], index))),
                keccak256(abi.encode(licensingModule.policyForIpAtIndex(true, ipId, i))),
                "policy not the same in parent to child"
            );
        }
    }

    function linkIpToParent(uint256 licenseId, address ipId, address caller, bytes memory royaltyContext) internal {
        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;
        linkIpToParents(licenseIds, ipId, caller, royaltyContext);
    }

    function _expectPolicyAddedToIpId(
        address caller,
        address ipId,
        uint256[] memory licenseIds,
        uint256[] memory policyIds
    ) internal {
        uint256 policyIdIndexTracker = 0; // start from 0 since this is a new IP (derivative)
        for (uint256 i = 0; i < licenseIds.length; i++) {
            bool isNewlyAddedPolicy = true;
            for (uint256 j = 0; j < licenseIds.length; j++) {
                if (j == i) continue;
                if (policyIds[j] == policyIds[i]) {
                    isNewlyAddedPolicy = false;
                    break;
                }
            }

            if (isNewlyAddedPolicy) {
                vm.expectEmit();
                emit ILicensingModule.PolicyAddedToIpId({
                    caller: caller,
                    ipId: ipId,
                    policyId: policyIds[i],
                    index: policyIdIndexTracker,
                    isInherited: true
                });
                policyIdIndexTracker++;
            }
        }
    }
}
