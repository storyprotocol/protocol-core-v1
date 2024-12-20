// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ICreate3Deployer {
    /// @notice Deploys a contract using CREATE3
    /// @param salt          The deployer-specific salt for determining the deployed contract's address
    /// @param creationCode  The creation code of the contract to deploy
    /// @return deployed     The address of the deployed contract
    function deployDeterministic(bytes memory creationCode, bytes32 salt) external payable returns (address deployed);

    ///  @notice Predicts the address of a deployed contract
    ///  @param salt      The deployer-specific salt for determining the deployed contract's address
    ///  @return deployed The address of the contract that will be deployed
    function predictDeterministicAddress(bytes32 salt) external view returns (address deployed);
}
