// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IModule } from "contracts/interfaces/modules/base/IModule.sol";

import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

/// @title Module Base Test Contract
/// @notice Base contract for testing standard module functionality.
abstract contract ModuleBaseTest is BaseTest {
    /// @notice The module SUT.
    IModule public baseModule;

    /// @notice Initializes the base module for testing.
    function setUp() public virtual override(BaseTest) {
        super.setUp();

        baseModule = IModule(_deployModule());
    }

    /// @notice Tests that the default resolver constructor runs successfully.
    function test_Module_Name() public {
        assertEq(baseModule.name(), _expectedName());
    }

    /// @dev Deploys the module SUT.
    function _deployModule() internal virtual returns (address);

    /// @dev Gets the expected name for the module.
    function _expectedName() internal view virtual returns (string memory);
}
