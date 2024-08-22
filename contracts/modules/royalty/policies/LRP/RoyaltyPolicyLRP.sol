// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IRoyaltyModule } from "../../../../interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicyLRP } from "../../../../interfaces/modules/royalty/policies/LRP/IRoyaltyPolicyLRP.sol";
import { Errors } from "../../../../lib/Errors.sol";
import { ProtocolPausableUpgradeable } from "../../../../pause/ProtocolPausableUpgradeable.sol";

/// @title Liquid Relative Percentage Royalty Policy
/// @notice Defines the logic for splitting royalties for a given ipId using a liquid relative percentage mechanism
contract RoyaltyPolicyLRP is
    IRoyaltyPolicyLRP,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    ProtocolPausableUpgradeable
{
    using SafeERC20 for IERC20;

    /// @notice Returns the RoyaltyModule address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRoyaltyModule public immutable ROYALTY_MODULE;

    /// @dev Restricts the calls to the royalty module
    modifier onlyRoyaltyModule() {
        if (msg.sender != address(ROYALTY_MODULE)) revert Errors.RoyaltyPolicyLRP__NotRoyaltyModule();
        _;
    }

    /// @notice Constructor
    /// @param royaltyModule The RoyaltyModule address
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address royaltyModule) {
        if (royaltyModule == address(0)) revert Errors.RoyaltyPolicyLRP__ZeroRoyaltyModule();

        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.RoyaltyPolicyLRP__ZeroAccessManager();
        __ProtocolPausable_init(accessManager);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Executes royalty related logic on minting a license
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param licensePercent The license percentage of the license being minted
    function onLicenseMinting(
        address ipId,
        uint32 licensePercent,
        bytes calldata
    ) external onlyRoyaltyModule nonReentrant {}

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licensesPercent The license percentage of the licenses being minted
    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        address[] memory licenseRoyaltyPolicies,
        uint32[] calldata licensesPercent,
        bytes calldata
    ) external onlyRoyaltyModule nonReentrant {
        IRoyaltyModule royaltyModule = IRoyaltyModule(ROYALTY_MODULE);

        address ipRoyaltyVault = royaltyModule.ipRoyaltyVaults(ipId);

        // this for loop is limited to the maximum number of parents
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            if (licenseRoyaltyPolicies[i] == address(this)) {
                address parentRoyaltyVault = royaltyModule.ipRoyaltyVaults(parentIpIds[i]);
                IERC20(ipRoyaltyVault).safeTransfer(parentRoyaltyVault, licensesPercent[i]);
            }
        }
    }

    /// @notice Returns the amount of royalty tokens required to link a child to a given IP asset
    /// @param ipId The ipId of the IP asset
    /// @param licensePercent The percentage of the license
    /// @return The amount of royalty tokens required to link a child to a given IP asset
    function rtsRequiredToLink(address ipId, uint32 licensePercent) external view returns (uint32) {
        return licensePercent;
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
