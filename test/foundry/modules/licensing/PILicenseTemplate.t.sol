// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { PILFlavors } from "../../../../contracts/lib/PILFlavors.sol";
import { ILicensingModule } from "../../../../contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { MockTokenGatedHook } from "../../mocks/MockTokenGatedHook.sol";
import { MockLicenseTemplate } from "../../mocks/module/MockLicenseTemplate.sol";
import { PILTerms } from "../../../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";

// test
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract PILicenseTemplateTest is BaseTest {
    using Strings for *;

    MockERC721 internal mockNft = new MockERC721("MockERC721");
    MockERC721 internal gatedNftFoo = new MockERC721{ salt: bytes32(uint256(1)) }("GatedNftFoo");
    MockERC721 internal gatedNftBar = new MockERC721{ salt: bytes32(uint256(2)) }("GatedNftBar");

    address public ipId1;
    address public ipId2;
    address public ipId3;
    address public ipId5;
    address public ipOwner1 = address(0x111);
    address public ipOwner2 = address(0x222);
    address public ipOwner3 = address(0x333);
    address public ipOwner5 = address(0x444);
    uint256 public tokenId1 = 1;
    uint256 public tokenId2 = 2;
    uint256 public tokenId3 = 3;
    uint256 public tokenId5 = 5;

    address public licenseHolder = address(0x101);


    function setUp() public override {
        super.setUp();
        // Create IPAccounts
        mockNft.mintId(ipOwner1, tokenId1);
        mockNft.mintId(ipOwner2, tokenId2);
        mockNft.mintId(ipOwner3, tokenId3);
        mockNft.mintId(ipOwner5, tokenId5);

        ipId1 = ipAssetRegistry.register(address(mockNft), tokenId1);
        ipId2 = ipAssetRegistry.register(address(mockNft), tokenId2);
        ipId3 = ipAssetRegistry.register(address(mockNft), tokenId3);
        ipId5 = ipAssetRegistry.register(address(mockNft), tokenId5);

        vm.label(ipId1, "IPAccount1");
        vm.label(ipId2, "IPAccount2");
        vm.label(ipId3, "IPAccount3");
        vm.label(ipId5, "IPAccount5");
    }
    // this contract is for testing for each PILicenseTemplate's functions
    // register license terms with PILTerms struct
    function test_PILicenseTemplate_registerLicenseTerms() public {

    }
    // get license terms struct by ID
    // get license terms ID by PILTerms struct
    // test license terms exists
    // test verifyMintLicenseToken
    // test verifyRegisterDerivative
    // test verifyCompatibleLicenses
    // test verifyRegisterDerivativeForAllParents
    // test getRoyaltyPolicy
    // test isLicenseTransferable
    // test getEarlierExpireTime
    // test getExpireTime
    // test getLicenseTermsId
    // test getLicenseTerms
    // test totalRegisteredLicenseTerms
    // test toJson


    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
