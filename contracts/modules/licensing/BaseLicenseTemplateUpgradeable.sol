// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// contracts
import { ILicenseTemplate } from "../../interfaces/modules/licensing/ILicenseTemplate.sol";

abstract contract BaseLicenseTemplateUpgradeable is ILicenseTemplate, ERC165, Initializable {
    /// @dev Storage structure for the BaseLicenseTemplateUpgradeable
    /// @custom:storage-location erc7201:story-protocol.BaseLicenseTemplateUpgradeable
    struct BaseLicenseTemplateUpgradeableStorage {
        string name;
        string metadataURI;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.BaseLicenseTemplateUpgradeable")) - 1)) &
    // ~bytes32(uint256(0xff));
    bytes32 private constant BaseLicenseTemplateUpgradeableStorageLocation =
        0x96c2f019b095cfe7c4d1f26aa9d2741961fe73294777688374a3299707c2fb00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param _name The name of the license template
    /// @param _metadataURI The URL to the off chain metadata
    function __BaseLicenseTemplate_init(string memory _name, string memory _metadataURI) internal onlyInitializing {
        _getBaseLicenseTemplateUpgradeableStorage().name = _name;
        _getBaseLicenseTemplateUpgradeableStorage().metadataURI = _metadataURI;
    }

    /// @notice Returns the name of the license template
    function name() public view override returns (string memory) {
        return _getBaseLicenseTemplateUpgradeableStorage().name;
    }

    /// @notice Returns the URL to the off chain metadata
    function getMetadataURI() public view override returns (string memory) {
        return _getBaseLicenseTemplateUpgradeableStorage().metadataURI;
    }

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(ILicenseTemplate).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Returns the storage struct of BaseLicenseTemplateUpgradeable.
    function _getBaseLicenseTemplateUpgradeableStorage()
        private
        pure
        returns (BaseLicenseTemplateUpgradeableStorage storage $)
    {
        assembly {
            $.slot := BaseLicenseTemplateUpgradeableStorageLocation
        }
    }
}
