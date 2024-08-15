// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { IIPAccount } from "../interfaces/IIPAccount.sol";
import { IGroupNFT } from "../interfaces/IGroupNFT.sol";
import { IGroupIPAssetRegistry } from "../interfaces/registries/IGroupIPAssetRegistry.sol";
import { IGroupingModule } from "../interfaces/modules/grouping/IGroupingModule.sol";
import { IIPAssetRegistry } from "../interfaces/registries/IIPAssetRegistry.sol";
import { ProtocolPausableUpgradeable } from "../pause/ProtocolPausableUpgradeable.sol";
import { IPAccountRegistry } from "../registries/IPAccountRegistry.sol";
import { Errors } from "../lib/Errors.sol";
import { IPAccountStorageOps } from "../lib/IPAccountStorageOps.sol";

/// @title IP Asset Registry
/// @notice This contract acts as the source of truth for all IP registered in
///         Story Protocol. An IP is identified by its contract address, token
///         id, and coin type, meaning any NFT may be conceptualized as an IP.
///         Once an IP is registered into the protocol, a corresponding IP
///         asset is generated, which references an IP resolver for metadata
///         attribution and an IP account for protocol authorization.
///         IMPORTANT: The IP account address, besides being used for protocol
///                    auth, is also the canonical IP identifier for the IP NFT.
abstract contract GroupIPAssetRegistry is IGroupIPAssetRegistry, ProtocolPausableUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupNFT public immutable GROUP_NFT;
    IGroupingModule public immutable GROUPING_MODULE;

    /// @dev Storage structure for the Group IPAsset Registry
    /// @custom:storage-location erc7201:story-protocol.GroupIPAssetRegistry
    struct GroupIPAssetRegistryStorage {
        mapping(address groupIpId => EnumerableSet.AddressSet memberIpIds) groups;
        mapping(address ipId => address groupPolicy) groupPolicies;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.GroupIPAssetRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant GroupIPAssetRegistryStorageLocation =
        0xa87c61809af5a42943abd137c7acff8426aab6f7a1f5c967a03d1d718ba5cf00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address groupNFT, address groupingModule) {
        // TODO: check zero address
        GROUP_NFT = IGroupNFT(groupNFT);
        GROUPING_MODULE = IGroupingModule(groupingModule);
        _disableInitializers();
    }

    /// @notice Registers a Group IPA
    /// @param groupPolicy The address of the group policy
    /// @return groupId The address of the newly registered Group IPA.
    function registerGroup(address groupPolicy) external whenNotPaused returns (address groupId) {
        uint256 groupNftId = GROUP_NFT.mintGroupNft(msg.sender, msg.sender);
        groupId = _register({ chainid: block.chainid, tokenContract: address(GROUP_NFT), tokenId: groupNftId });

        IIPAccount(payable(groupId)).setBool("GROUP_IPA", true);
        // TODO: check policy is whitelisted
        _getGroupIPAssetRegistryStorage().groupPolicies[groupId] = groupPolicy;

        emit IPGroupRegistered(groupId, block.chainid, address(GROUP_NFT), groupNftId, groupPolicy);
    }

    function addGroupMember(address groupId, address[] calldata ipIds) external whenNotPaused {
        require(isGroupRegistered(groupId), "IPAssetRegistry: Group IPA not registered");
        require(msg.sender == groupId, "IPAssetRegistry: Caller not Group IPA owner");
        EnumerableSet.AddressSet storage allMemberIpIds = _getGroupIPAssetRegistryStorage().groups[groupId];
        for (uint256 i = 0; i < ipIds.length; i++) {
            address ipId = ipIds[i];
            require(isRegistered(ipId), "IPAssetRegistry: IP not registered");
            allMemberIpIds.add(ipId);
        }
    }

    /// @notice Checks whether a group IPA was registered based on its ID.
    /// @param groupId The address of the Group IPA.
    /// @return isRegistered Whether the Group IPA was registered into the protocol.
    function isGroupRegistered(address groupId) external view returns (bool) {
        if (!_isRegistered(groupId)) return false;
        return IIPAccount(payable(groupId)).getBool("GROUP_IPA");
    }

    /// @notice Retrieves the group policy for a Group IPA
    /// @param groupId The address of the Group IPA.
    /// @return groupPolicy The address of the group policy.
    function getGroupPolicy(address groupId) external view returns (address) {
        return _getGroupIPAssetRegistryStorage().groupPolicies[groupId];
    }

    /// @notice Retrieves the group members for a Group IPA
    /// @param groupId The address of the Group IPA.
    /// @param startIndex The start index of the group members to retrieve
    /// @param size The size of the group members to retrieve
    /// @return results The addresses of the group members
    function getGroupMembers(
        address groupId,
        uint256 startIndex,
        uint256 size
    ) external view returns (address[] memory results) {
        EnumerableSet.AddressSet storage allMemberIpIds = _getGroupIPAssetRegistryStorage().groups[groupId];
        uint256 totalSize = allMemberIpIds.length();
        if (startIndex >= totalSize) return results;

        uint256 resultsSize = (startIndex + size) > totalSize ? size - ((startIndex + size) - totalSize) : size;
        for (uint256 i = 0; i < resultsSize; i++) {
            results[i] = allMemberIpIds.at(startIndex + i);
        }
        return results;
    }

    /// @notice Checks whether an IP is a member of a Group IPA
    /// @param groupId The address of the Group IPA.
    /// @param ipId The address of the IP.
    /// @return isMember Whether the IP is a member of the Group IPA.
    function containsIp(address groupId, address ipId) external view returns (bool) {
        return _getGroupIPAssetRegistryStorage().groups[groupId].contains(ipId);
    }
    /// @notice Retrieves the total number of members in a Group IPA
    /// @param groupId The address of the Group IPA.
    /// @return totalMembers The total number of members in the Group IPA.
    function totalMembers(address groupId) external view returns (uint256) {
        return _getGroupIPAssetRegistryStorage().groups[groupId].length();
    }

    /// @notice Gets the canonical IP identifier associated with an IP NFT.
    /// @dev This is equivalent to the address of its bound IP account.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @return ipId The IP's canonical address identifier.
    function ipId(uint256 chainId, address tokenContract, uint256 tokenId) public view returns (address) {
        return super.ipAccount(chainId, tokenContract, tokenId);
    }

    /// @notice Checks whether an IP was registered based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return isRegistered Whether the IP was registered into the protocol.
    function isRegistered(address id) external view returns (bool) {
        return _isRegistered(id);
    }

    /// @notice Gets the total number of IP assets registered in the protocol.
    function totalSupply() external view returns (uint256) {
        return _getIPAssetRegistryStorage().totalSupply;
    }

    function _register(uint256 chainid, address tokenContract, uint256 tokenId) internal virtual returns (address id) {
        id = _registerIpAccount(chainid, tokenContract, tokenId);
        IIPAccount ipAccount = IIPAccount(payable(id));

        if (bytes(ipAccount.getString("NAME")).length != 0) {
            revert Errors.IPAssetRegistry__AlreadyRegistered();
        }

        (string memory name, string memory uri) = _getNameAndUri(chainid, tokenContract, tokenId);
        uint256 registrationDate = block.timestamp;
        ipAccount.setString("NAME", name);
        ipAccount.setString("URI", uri);
        ipAccount.setUint256("REGISTRATION_DATE", registrationDate);
        if (isGroup) ipAccount.setBool("GROUP_IPA", true);

        _getIPAssetRegistryStorage().totalSupply++;

        emit IPRegistered(id, chainid, tokenContract, tokenId, name, uri, registrationDate);
    }

    /// @dev Retrieves the name and URI of from IP NFT.
    function _getNameAndUri(
        uint256 chainid,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (string memory name, string memory uri) {
        if (chainid != block.chainid) {
            name = string.concat(chainid.toString(), ": ", tokenContract.toHexString(), " #", tokenId.toString());
            uri = "";
            return (name, uri);
        }
        // Handle NFT on the same chain
        if (!tokenContract.supportsInterface(type(IERC721).interfaceId)) {
            revert Errors.IPAssetRegistry__UnsupportedIERC721(tokenContract);
        }

        if (IERC721(tokenContract).ownerOf(tokenId) == address(0)) {
            revert Errors.IPAssetRegistry__InvalidToken(tokenContract, tokenId);
        }

        if (!tokenContract.supportsInterface(type(IERC721Metadata).interfaceId)) {
            revert Errors.IPAssetRegistry__UnsupportedIERC721Metadata(tokenContract);
        }

        name = string.concat(
            block.chainid.toString(),
            ": ",
            IERC721Metadata(tokenContract).name(),
            " #",
            tokenId.toString()
        );
        uri = IERC721Metadata(tokenContract).tokenURI(tokenId);
    }

    function _isRegistered(address id) internal view returns (bool) {
        if (id == address(0)) return false;
        if (id.code.length == 0) return false;
        if (!ERC165Checker.supportsInterface(id, type(IIPAccount).interfaceId)) return false;
        (uint chainId, address tokenContract, uint tokenId) = IIPAccount(payable(id)).token();
        if (id != ipAccount(chainId, tokenContract, tokenId)) return false;
        return bytes(IIPAccount(payable(id)).getString("NAME")).length != 0;
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @dev Returns the storage struct of IPAssetRegistry.
    function _getIPAssetRegistryStorage() private pure returns (IPAssetRegistryStorage storage $) {
        assembly {
            $.slot := IPAssetRegistryStorageLocation
        }
    }

    /// @dev Returns the storage struct of GroupIPAssetRegistry.
    function _getGroupIPAssetRegistryStorage() private pure returns (GroupIPAssetRegistryStorage storage $) {
        assembly {
            $.slot := GroupIPAssetRegistryStorageLocation
        }
    }
}
