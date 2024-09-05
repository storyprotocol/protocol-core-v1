// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { ERC6551AccountLib } from "erc6551/lib/ERC6551AccountLib.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { IIPAccountRegistry } from "contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IIPAssetRegistry } from "contracts/interfaces/registries/IIPAssetRegistry.sol";

// test
import { MockERC721 } from "test/foundry/mocks/token/MockERC721.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

contract BaseIntegration is BaseTest {
    using Strings for *;
    function setUp() public virtual override(BaseTest) {
        super.setUp();

        dealMockAssets();

        vm.prank(u.admin);
        royaltyModule.setSnapshotInterval(7 days);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function registerIpAccount(address nft, uint256 tokenId, address owner) internal returns (address) {
        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            nft,
            tokenId
        );

        vm.label(expectedAddr, string(abi.encodePacked("IPAccount", Strings.toString(tokenId))));

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

        vm.startPrank(owner);
        return ipAssetRegistry.register(block.chainid, nft, tokenId);
    }

    function registerIpAccount(MockERC721 nft, uint256 tokenId, address caller) internal returns (address) {
        return registerIpAccount(address(nft), tokenId, caller);
    }

    function registerDerivativeWithLicenseTokens(
        address ipId,
        uint256[] memory licenseTokenIds,
        bytes memory royaltyContext,
        address caller
    ) internal {
        vm.startPrank(caller);
        // TODO: events check
        licensingModule.registerDerivativeWithLicenseTokens(ipId, licenseTokenIds, royaltyContext);
        vm.stopPrank();
    }
}
