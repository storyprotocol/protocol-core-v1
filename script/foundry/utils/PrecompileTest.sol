// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { PILTerms, IPILicenseTemplate } from "../../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { IIPAssetRegistry } from "../../../contracts/interfaces/registries/IIPAssetRegistry.sol";
import { ILicensingModule } from "../../../contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyModule } from "../../../contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IIpRoyaltyVault } from "../../../contracts/interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";
import { IIPAccount } from "../../../contracts/interfaces/IIPAccount.sol";
import { IVaultController } from "../../../contracts/interfaces/modules/royalty/policies/IVaultController.sol";
import { IGraphAwareRoyaltyPolicy } from "../../../contracts/interfaces/modules/royalty/policies/IGraphAwareRoyaltyPolicy.sol";

import { MockERC721 } from "../../../test/foundry/mocks/token/MockERC721.sol";
import { MockExternalRoyaltyPolicy1 } from "../../../test/foundry/mocks/policy/MockExternalRoyaltyPolicy1.sol";

contract PrecompileTest is Script {

    // protocol addresses
    address internal ROYALTY_POLICY_LAP = 0x4074CEC2B3427f983D14d0C5E962a06B7162Ab92;
    address internal ROYALTY_POLICY_LRP = 0x7F6a8f43EC6059eC80C172441CEe3423988a0be9;
    address internal SUSD = 0x91f6F05B08c16769d3c85867548615d270C42fC7;
    address internal PIL_TEMPLATE = 0x0752f61E59fD2D39193a74610F1bd9a6Ade2E3f9;
    address internal IP_ASSET_REGISTRY = 0x1a9d0d28a0422F26D31Be72Edc6f13ea4371E11B;
    address internal LICENSING_MODULE = 0xd81fd78f557b457b4350cB95D20b547bFEb4D857;
    address internal ROYALTY_MODULE = 0x3C27b2D7d30131D4b58C3584FD7c86e3358744de;

    // user
    address internal USER = 0xf398C12A45Bc409b6C652E25bb0a3e702492A4ab;

    // terms
    uint256 internal mintingFee = 1000e18;
    uint256 internal commDerivTermsIdLap10;
    uint256 internal commDerivTermsIdLap10_NoReciprocal;
    uint256 internal commDerivTermsIdLap1;
    uint256 internal commDerivTermsIdLrp10;
    uint256 internal commDerivTermsIdLrp10_NoReciprocal;
    uint256 internal commDerivTermsIdExt10;

    // others
    MockERC721 mockNft;
    MockExternalRoyaltyPolicy1 mockExternalRoyaltyPolicy;
    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    function run() public {
        vm.startBroadcast();

        ISUSD(SUSD).mint(USER, 1000000e18);
        ISUSD(SUSD).approve(address(ROYALTY_MODULE), type(uint256).max);

        mockNft = new MockERC721("MockNft");
        mockExternalRoyaltyPolicy = new MockExternalRoyaltyPolicy1();
    
        // mint nfts
        mockNft.mintId(USER, 100);
        mockNft.mintId(USER, 200);
        mockNft.mintId(USER, 300);
        mockNft.mintId(USER, 400);
        mockNft.mintId(USER, 500);
        mockNft.mintId(USER, 600);
        mockNft.mintId(USER, 700);
        mockNft.mintId(USER, 800);
        mockNft.mintId(USER, 900);
        mockNft.mintId(USER, 1000);
        mockNft.mintId(USER, 1100);
        mockNft.mintId(USER, 1200);
        mockNft.mintId(USER, 1300);
        mockNft.mintId(USER, 1400);

        // register Ip Accounts
        ipAcct[1] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 100);
        ipAcct[2] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 200);
        ipAcct[3] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 300);
        ipAcct[4] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 400);
        ipAcct[5] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 500);
        ipAcct[6] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 600);
        ipAcct[7] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 700);
        ipAcct[8] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 800);
        ipAcct[9] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 900);
        ipAcct[10] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 1000);
        ipAcct[11] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 1100);
        ipAcct[12] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 1200);
        ipAcct[13] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 1300);
        ipAcct[14] = IIPAssetRegistry(IP_ASSET_REGISTRY).register(block.chainid, address(mockNft), 1400);

        // label
        vm.label(ROYALTY_POLICY_LAP, "ROYALTY_POLICY_LAP");
        vm.label(ROYALTY_POLICY_LRP, "ROYALTY_POLICY_LRP");
        vm.label(SUSD, "SUSD");
        vm.label(PIL_TEMPLATE, "PIL_TEMPLATE");
        vm.label(IP_ASSET_REGISTRY, "IP_ASSET_REGISTRY");
        vm.label(LICENSING_MODULE, "LICENSING_MODULE");
        vm.label(ROYALTY_MODULE, "ROYALTY_MODULE");
        vm.label(ipAcct[1], "ipAcct1");
        vm.label(ipAcct[2], "ipAcct2");
        vm.label(ipAcct[3], "ipAcct3");
        vm.label(ipAcct[4], "ipAcct4");
        vm.label(ipAcct[5], "ipAcct5");
        vm.label(ipAcct[6], "ipAcct6");
        vm.label(ipAcct[7], "ipAcct7");
        vm.label(ipAcct[8], "ipAcct8");
        vm.label(ipAcct[9], "ipAcct9");
        vm.label(ipAcct[10], "ipAcct10");
        vm.label(ipAcct[11], "ipAcct11");
        vm.label(ipAcct[12], "ipAcct12");
        vm.label(ipAcct[13], "ipAcct13");
        vm.label(ipAcct[14], "ipAcct14");

        // register terms
        registerTerms();

        // setup tree 1-2-3-4-5
        //_setupTree1();

        // setup tree 6-7-8-9-10
        _setupTree2();

        // setup tree 11-12-13-14
        _setupTree3();
        
        vm.stopBroadcast();

        // logs
        console2.log("MockNft                  ", address(mockNft));
        console2.log("MockExternalRoyaltyPolicy", address(mockExternalRoyaltyPolicy));
        console2.log("ipAcct[1]", ipAcct[1]);
        console2.log("ipAcct[2]", ipAcct[2]);
        console2.log("ipAcct[3]", ipAcct[3]);
        console2.log("ipAcct[4]", ipAcct[4]);
        console2.log("ipAcct[5]", ipAcct[5]);
        console2.log("ipAcct[6]", ipAcct[6]);
        console2.log("ipAcct[7]", ipAcct[7]);
        console2.log("ipAcct[8]", ipAcct[8]);
        console2.log("ipAcct[9]", ipAcct[9]);
        console2.log("ipAcct[10]", ipAcct[10]);
        console2.log("ipAcct[11]", ipAcct[11]);
        console2.log("ipAcct[12]", ipAcct[12]);
        console2.log("ipAcct[13]", ipAcct[13]);
        console2.log("ipAcct[14]", ipAcct[14]);
    }

    function registerTerms() internal {
        commDerivTermsIdLap10 = IPILicenseTemplate(PIL_TEMPLATE).registerLicenseTerms(
            PILTerms({
                transferable: true,
                royaltyPolicy: ROYALTY_POLICY_LAP,
                defaultMintingFee: mintingFee,
                expiration: 0,
                commercialUse: true,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 10e6,
                commercialRevCeiling: 0,
                derivativesAllowed: true,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativeRevCeiling: 0,
                currency: SUSD,
                uri: ""
            })
        );

        commDerivTermsIdLap10_NoReciprocal = IPILicenseTemplate(PIL_TEMPLATE).registerLicenseTerms(
            PILTerms({
                transferable: true,
                royaltyPolicy: ROYALTY_POLICY_LAP,
                defaultMintingFee: mintingFee,
                expiration: 0,
                commercialUse: true,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 10e6,
                commercialRevCeiling: 0,
                derivativesAllowed: true,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativeRevCeiling: 0,
                currency: SUSD,
                uri: ""
            })
        );

        commDerivTermsIdLap1 = IPILicenseTemplate(PIL_TEMPLATE).registerLicenseTerms(
            PILTerms({
                transferable: true,
                royaltyPolicy: ROYALTY_POLICY_LAP,
                defaultMintingFee: mintingFee,
                expiration: 0,
                commercialUse: true,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 1e6,
                commercialRevCeiling: 0,
                derivativesAllowed: true,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativeRevCeiling: 0,
                currency: SUSD,
                uri: ""
            })
        );

        commDerivTermsIdLrp10 = IPILicenseTemplate(PIL_TEMPLATE).registerLicenseTerms(
            PILTerms({
                transferable: true,
                royaltyPolicy: ROYALTY_POLICY_LRP,
                defaultMintingFee: mintingFee,
                expiration: 0,
                commercialUse: true,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 10e6,
                commercialRevCeiling: 0,
                derivativesAllowed: true,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativeRevCeiling: 0,
                currency: SUSD,
                uri: ""
            })
        );

        commDerivTermsIdLrp10_NoReciprocal = IPILicenseTemplate(PIL_TEMPLATE).registerLicenseTerms(
            PILTerms({
                transferable: true,
                royaltyPolicy: ROYALTY_POLICY_LRP,
                defaultMintingFee: mintingFee,
                expiration: 0,
                commercialUse: true,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 10e6,
                commercialRevCeiling: 0,
                derivativesAllowed: true,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativeRevCeiling: 0,
                currency: SUSD,
                uri: ""
            })
        );

        // TODO: add external royalty policy after upgrade
        /* commDerivTermsIdExt10 = IPILicenseTemplate(PIL_TEMPLATE).registerLicenseTerms(
            PILTerms({
                transferable: true,
                royaltyPolicy: address(mockExternalRoyaltyPolicy),
                defaultMintingFee: mintingFee,
                expiration: 0,
                commercialUse: true,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 10e6,
                commercialRevCeiling: 0,
                derivativesAllowed: true,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativeRevCeiling: 0,
                currency: SUSD,
                uri: ""
            })
        ); */
    }

    /* function _setupTree1() internal {
        // attach terms to root
        ILicensingModule licensingModule = ILicensingModule(LICENSING_MODULE);
        licensingModule.attachLicenseTerms(ipAcct[1], PIL_TEMPLATE, commDerivTermsIdLap10);
        //licensingModule.attachLicenseTerms(ipAcct[2], PIL_TEMPLATE, commDerivTermsIdLap1);
        //licensingModule.attachLicenseTerms(ipAcct[3], PIL_TEMPLATE, commDerivTermsIdLap1);

        license_1_2[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: PIL_TEMPLATE,
            licenseTermsId: commDerivTermsIdLap10,
            amount: 1,
            receiver: ipAcct[2],
            royaltyContext: ""
        });
        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[2], license_1_2, "");

        license_2_3[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[2],
            licenseTemplate: PIL_TEMPLATE,
            licenseTermsId: commDerivTermsIdLap10,
            amount: 1,
            receiver: ipAcct[3],
            royaltyContext: ""
        });
        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[3], license_2_3, "");

        uint256[] memory licenses_2_3_4 = new uint256[](2);
        licenses_2_3_4[0] = license_2_4[0];
        licenses_2_3_4[1] = license_3_4[0];

        license_3_4[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[3],
            licenseTemplate: PIL_TEMPLATE,
            licenseTermsId: commDerivTermsIdLap1,
            amount: 1,
            receiver: ipAcct[4],
            royaltyContext: ""
        });

        license_2_4[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[2],
            licenseTemplate: PIL_TEMPLATE,
            licenseTermsId: commDerivTermsIdLap1,
            amount: 1,
            receiver: ipAcct[4],
            royaltyContext: ""
        });
        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[4], licenses_2_3_4, "");
    } */

    function _setupTree2() internal {
        uint256[] memory license_6_7 = new uint256[](1);
        uint256[] memory license_6_8 = new uint256[](1);
        uint256[] memory licenses_7_8_9 = new uint256[](2);
        uint256[] memory license_9_10 = new uint256[](1);

        // attach terms to root
        ILicensingModule licensingModule = ILicensingModule(LICENSING_MODULE);
        licensingModule.attachLicenseTerms(ipAcct[6], PIL_TEMPLATE, commDerivTermsIdLrp10);

        license_6_7[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[6],
            licenseTemplate: PIL_TEMPLATE,
            licenseTermsId: commDerivTermsIdLrp10,
            amount: 1,
            receiver: ipAcct[7],
            royaltyContext: ""
        });
        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[7], license_6_7, "");

        license_6_8[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[6],
            licenseTemplate: PIL_TEMPLATE,
            licenseTermsId: commDerivTermsIdLrp10,
            amount: 1,
            receiver: ipAcct[8],
            royaltyContext: ""
        });
        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[8], license_6_8, "");

        licenses_7_8_9[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[7],
            licenseTemplate: PIL_TEMPLATE,
            licenseTermsId: commDerivTermsIdLrp10,
            amount: 1,
            receiver: ipAcct[9],
            royaltyContext: ""
        });
        
        licenses_7_8_9[1] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[8],
            licenseTemplate: PIL_TEMPLATE,
            licenseTermsId: commDerivTermsIdLrp10,
            amount: 1,
            receiver: ipAcct[9],
            royaltyContext: ""
        });

        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[9], licenses_7_8_9, "");

        license_9_10[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[9],
            licenseTemplate: PIL_TEMPLATE,
            licenseTermsId: commDerivTermsIdLrp10,
            amount: 1,
            receiver: ipAcct[10],
            royaltyContext: ""
        });
        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[10], license_9_10, "");

        // A tip is made
        IRoyaltyModule royaltyModule = IRoyaltyModule(ROYALTY_MODULE);
        royaltyModule.payRoyaltyOnBehalf(ipAcct[10], address(0), SUSD, 1e18);

        // transfer to vault
        address vault8 = royaltyModule.ipRoyaltyVaults(ipAcct[8]);
        IGraphAwareRoyaltyPolicy(ROYALTY_POLICY_LRP).transferToVault(ipAcct[10], ipAcct[8], SUSD, 1e16);
        
        // claim revenue
        IIpRoyaltyVault(vault8).snapshot();

        uint256[] memory snapshotIds = new uint256[](1);
        snapshotIds[0] = 1;
        bytes memory callData = abi.encodeWithSelector(oldVault.claimRevenueBySnapshotBatch.selector, snapshotIds, SUSD);
        IIPAccount(payable(ipAcct[8])).execute(vault8, 0, callData);
    }

    function _setupTree3() internal {
        uint256[] memory license_11_12_14 = new uint256[](2);
        // uint256[] memory license_11_12_13_14 = new uint256[](3);

        // attach terms to roots
        ILicensingModule licensingModule = ILicensingModule(LICENSING_MODULE);
        licensingModule.attachLicenseTerms(ipAcct[11], PIL_TEMPLATE, commDerivTermsIdLap10);
        licensingModule.attachLicenseTerms(ipAcct[12], PIL_TEMPLATE, commDerivTermsIdLrp10);
        // licensingModule.attachLicenseTerms(ipAcct[13], PIL_TEMPLATE, commDerivTermsIdExt10);

        license_11_12_14[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[11],
            licenseTemplate: PIL_TEMPLATE,
            licenseTermsId: commDerivTermsIdLap10_NoReciprocal,
            amount: 1,
            receiver: ipAcct[14],
            royaltyContext: ""
        });

        license_11_12_14[1] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[12],
            licenseTemplate: PIL_TEMPLATE,
            licenseTermsId: commDerivTermsIdLrp10_NoReciprocal,
            amount: 1,
            receiver: ipAcct[14],
            royaltyContext: ""
        });

        // TODO license_11_12_13_14 after upgrade
        
        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[14], license_11_12_14, "");

        // A tip is made
        IRoyaltyModule royaltyModule = IRoyaltyModule(ROYALTY_MODULE);
        royaltyModule.payRoyaltyOnBehalf(ipAcct[14], address(0), SUSD, 1e18);

        // claim revenue
        // TODO claim revenue via IP14 after upgrade
    }
}

interface ISUSD is IERC20 {
    function mint(address to, uint256 amount) external;
}

interface oldVault {
    function claimRevenueBySnapshotBatch(uint256[] calldata snapshotIds, address currency) external;
}