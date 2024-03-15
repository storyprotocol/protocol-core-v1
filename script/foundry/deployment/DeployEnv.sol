// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @notice Struct to hold deployment environment variables in deployment scripts
/// @param deployer The address of the deployer
/// @param multisig The address of the multisig wallet
/// @param roleGrantDelay The delay in seconds for a protocol role grant to take effect
/// @param roleExecDelay The delay in seconds for a protocol role execution to take effect
struct DeployEnv {
    address deployer;
    address multisig;
    uint32 roleGrantDelay;
    uint32 roleExecDelay;
}