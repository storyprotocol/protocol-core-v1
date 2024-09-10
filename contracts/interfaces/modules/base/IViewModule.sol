// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity 0.8.26;

import { IModule } from "./IModule.sol";

/// @notice View Module Interface
/// View modules typically are read-only modules that are responsible for displaying
/// IP-related data in various ways to meet different needs.For instance,
/// they can display simple/base/core metadata, book specific metadata, license details metadata,
/// or even IP graph data for the same IPAccount using different View Modules.
/// This module offers flexibility in selecting which data to display and how to present it.
/// @dev View Module can read data from IPAccount and from multiple namesapces to combine data for display.
interface IViewModule is IModule {
    /// @notice check whether the view module is supported for the given IP account
    function isSupported(address ipAccount) external returns (bool);
}
