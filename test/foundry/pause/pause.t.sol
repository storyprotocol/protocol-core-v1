// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ProtocolPausableUpgradeable } from "../../../contracts/pause/ProtocolPausableUpgradeable.sol";

import { Pause } from "../../../script/foundry/pause/pause.s.sol";

import { BaseTest } from "../utils/BaseTest.t.sol";

contract PauseTest is BaseTest {
    address constant ACCESS_CONTROLLER = 0xcCF37d0a503Ee1D4C11208672e622ed3DFB2275a;
    address constant DISPUTE_MODULE = 0x9b7A9c70AFF961C799110954fc06F3093aeb94C5;
    address constant ARBITRATION_POLICY_UMA = 0xfFD98c3877B8789124f02C7E8239A4b0Ef11E936;
    address constant EVEN_SPLIT_GROUP_POOL = 0xf96f2c30b41Cb6e0290de43C8528ae83d4f33F89;
    address constant GROUPING_MODULE = 0x69D3a7aa9edb72Bc226E745A7cCdd50D947b69Ac;
    address constant LICENSING_MODULE = 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f;
    address constant ROYALTY_MODULE = 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086;
    address constant ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    address constant ROYALTY_POLICY_LRP = 0x9156e603C949481883B1d3355c6f1132D191fC41;
    address constant IP_ASSET_REGISTRY = 0x77319B4031e6eF1250907aa00018B8B1c67a244b;

    function setUp() public override {
        address safeGovernanceMultisig = 0xF07cA4b61022F0399C1511E7E668A57567f2138B;

        uint256 forkId = vm.createFork("https://mainnet.storyrpc.io/");
        vm.selectFork(forkId);

        vm.startPrank(safeGovernanceMultisig);

        Pause pauseScript = new Pause();

        address[] memory contractsToPause = pauseScript.getPausableContracts();
        for (uint256 i = 0; i < contractsToPause.length; i++) {
            ProtocolPausableUpgradeable(contractsToPause[i]).pause();
        }

        vm.stopPrank();
    }

    function test_AllContractsPaused() public {
        assertTrue(ProtocolPausableUpgradeable(ACCESS_CONTROLLER).paused());
        assertTrue(ProtocolPausableUpgradeable(DISPUTE_MODULE).paused());
        assertTrue(ProtocolPausableUpgradeable(ARBITRATION_POLICY_UMA).paused());
        assertTrue(ProtocolPausableUpgradeable(EVEN_SPLIT_GROUP_POOL).paused());
        assertTrue(ProtocolPausableUpgradeable(GROUPING_MODULE).paused());
        assertTrue(ProtocolPausableUpgradeable(LICENSING_MODULE).paused());
        assertTrue(ProtocolPausableUpgradeable(ROYALTY_MODULE).paused());
        assertTrue(ProtocolPausableUpgradeable(ROYALTY_POLICY_LAP).paused());
        assertTrue(ProtocolPausableUpgradeable(ROYALTY_POLICY_LRP).paused());
        assertTrue(ProtocolPausableUpgradeable(IP_ASSET_REGISTRY).paused());
    }
}
