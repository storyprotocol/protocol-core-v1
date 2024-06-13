// SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.23;

// import { ProtocolAdmin } from "contracts/lib/ProtocolAdmin.sol";
// import { RoyaltyPolicyLAP } from "contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";

// import { BaseTest } from "../utils/BaseTest.t.sol";

// import { LicenseToken } from "contracts/LicenseToken.sol";
// import { LicenseTokenV1_0_0 } from "contracts/old/v1.0.0/contracts/LicenseToken.sol";
// import { TestProxyHelper } from "test/foundry/utils/TestProxyHelper.sol";

// import { DeployerV1_1_0 } from "script/foundry/upgrades/testnet/v1-1-0_deployer.sol";

// contract Upgradesv1_1_0Test is BaseTest {
//     uint32 execDelay = 600;

//     string contractKey;
//     address impl;

//     DeployerV1_1_0 implDeployer;

//     function setUp() public override {
//         super.setUp();
//         vm.prank(u.admin);
//         protocolAccessManager.grantRole(ProtocolAdmin.UPGRADER_ROLE, u.bob, upgraderExecDelay);
//         implDeployer = new DeployerV1_1_0();
//     }

//     function test_LicenseToken() public {
//         contractKey = "LicenseToken";
//         impl = address(new LicenseTokenV1_0_0());
//         address licenseToken = TestProxyHelper.deployUUPSProxy(
//             create3Deployer,
//             _getSalt(type(LicenseTokenV1_0_0).name),
//             impl,
//             abi.encodeCall(
//                 LicenseTokenV1_0_0.initialize,
//                 (
//                     address(protocolAccessManager),
//                     "https://github.com/storyprotocol/protocol-core/blob/main/assets/license-image.gif"
//                 )
//             )
//         );
//         vm.prank(u.admin);
//         LicenseTokenV1_0_0(licenseToken).setLicensingModule(address(licensingModule));
//         vm.prank(u.admin);
//         LicenseTokenV1_0_0(licenseToken).setDisputeModule(address(disputeModule));

//         DeployerV1_1_0.ProxiesToUpgrade memory proxies = DeployerV1_1_0.ProxiesToUpgrade(
//             licenseToken,
//             address(licensingModule),
//             address(licenseRegistry),
//             address(pilTemplate),
//             address(accessController),
//             address(royaltyModule),
//             address(royaltyPolicyLAP),
//             address(ipAssetRegistry)
//         );

//         DeployerV1_1_0.Dependencies memory dependencies = DeployerV1_1_0.Dependencies(
//             address(disputeModule),
//             address(moduleRegistry)
//         );

//         implDeployer.deploy(create3Deployer, 0, address(erc6551Registry), proxies, dependencies);
//     }
// }
