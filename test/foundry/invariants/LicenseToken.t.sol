/* solhint-disable no-console */
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { BaseTest } from "../utils/BaseTest.t.sol";

import { ILicenseToken } from "contracts/interfaces/ILicenseToken.sol";

contract LicenseTokenHarness {
    ILicenseToken public licenseToken;
    constructor(address _licenseToken) {
        licenseToken = ILicenseToken(_licenseToken);
    }
    function mintLicenseTokens(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount, // mint amount
        address minter,
        address receiver
    ) external {
        licenseToken.mintLicenseTokens(licensorIpId, licenseTemplate, licenseTermsId, amount, minter, receiver);
    }

    function burnLicenseTokens(address holder, uint256[] calldata tokenIds) external {
        licenseToken.burnLicenseTokens(holder, tokenIds);
    }

    function approve(address to, uint256 tokenId) external {
        licenseToken.approve(to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        licenseToken.setApprovalForAll(operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        licenseToken.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        licenseToken.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        licenseToken.safeTransferFrom(from, to, tokenId, data);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract LicenseTokenBaseInvariants is BaseTest {
    LicenseTokenHarness public harness;

    function setUp() public virtual override {
        super.setUp();
        harness = new LicenseTokenHarness(address(licenseToken));
        targetContract(address(harness));
    }

    function prankLicenseModule() internal {
        vm.startPrank(address(licensingModule));
    }

    function mintTestLicense(address _pilTemplate, uint256 _commTermsId) internal {
        mockNFT.mintId(address(harness), 300);
        vm.prank(address(harness));
        address _ipAccount = ipAssetRegistry.register(block.chainid, address(mockNFT), 300);
        assertTrue(ipAssetRegistry.isRegistered(_ipAccount), "IPAccount not registered");
        vm.prank(address(licensingModule));
        licenseToken.mintLicenseTokens({
            licensorIpId: _ipAccount,
            licenseTemplate: _pilTemplate,
            licenseTermsId: _commTermsId,
            amount: 1,
            minter: address(harness),
            receiver: address(harness)
        });
    }

    function invariant_notInitializable() public {
        vm.expectRevert();
        licenseToken.initialize(address(1), "");
    }
}

contract LicenseTokenPermissionlessNoTokenInvariants is LicenseTokenBaseInvariants {
    function setUp() public override {
        super.setUp();
    }

    function invariant_impossibleToMint() public {
        assertEq(licenseToken.totalMintedTokens(), 0);
    }

    function invariant_balanceOfZero() public {
        assertEq(licenseToken.balanceOf(address(this)), 0);
    }
}

contract LicenseTokenPermissionlessOneTokenTransferableInvariants is LicenseTokenBaseInvariants {
    /* solhint-disable */
    string public constant TOKEN_URI =
        "data:application/json;base64,eyJuYW1lIjogIlN0b3J5IFByb3RvY29sIExpY2Vuc2UgIzAiLCJkZXNjcmlwdGlvbiI6ICJMaWNlbnNlIGFncmVlbWVudCBzdGF0aW5nIHRoZSB0ZXJtcyBvZiBhIFN0b3J5IFByb3RvY29sIElQQXNzZXQiLCJleHRlcm5hbF91cmwiOiAiaHR0cHM6Ly9wcm90b2NvbC5zdG9yeXByb3RvY29sLnh5ei9pcGEvMHhhMzhjNzQ5N2E1NTNhNjY5OWNmYWJiMGZhMWNlODc1ZDE3ZmU0N2Y2IiwiaW1hZ2UiOiAiaHR0cHM6Ly9naXRodWIuY29tL3N0b3J5cHJvdG9jb2wvcHJvdG9jb2wtY29yZS9ibG9iL21haW4vYXNzZXRzL2xpY2Vuc2UtaW1hZ2UuZ2lmIiwiYXR0cmlidXRlcyI6IFt7InRyYWl0X3R5cGUiOiAiRXhwaXJhdGlvbiIsICJ2YWx1ZSI6ICJuZXZlciJ9LHsidHJhaXRfdHlwZSI6ICJDdXJyZW5jeSIsICJ2YWx1ZSI6ICIweDcyMzg0OTkyMjIyYmUwMTVkZTAxNDZhNmQ3ZTVkYTBlMTlkMmJhNDkifSx7InRyYWl0X3R5cGUiOiAiVVJJIiwgInZhbHVlIjogIiJ9LHsidHJhaXRfdHlwZSI6ICJDb21tZXJjaWFsIFVzZSIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogIkNvbW1lcmNpYWwgQXR0cmlidXRpb24iLCAidmFsdWUiOiAidHJ1ZSJ9LHsidHJhaXRfdHlwZSI6ICJDb21tZXJjaWFsIFJldmVudWUgU2hhcmUiLCAibWF4X3ZhbHVlIjogMTAwMCwgInZhbHVlIjogMH0seyJ0cmFpdF90eXBlIjogIkNvbW1lcmNpYWwgUmV2ZW51ZSBDZWxsaW5nIiwgInZhbHVlIjogMH0seyJ0cmFpdF90eXBlIjogIkNvbW1lcmNpYWxpemVyIENoZWNrIiwgInZhbHVlIjogIjB4MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMCJ9LHsidHJhaXRfdHlwZSI6ICJEZXJpdmF0aXZlcyBBbGxvd2VkIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiRGVyaXZhdGl2ZXMgQXR0cmlidXRpb24iLCAidmFsdWUiOiAidHJ1ZSJ9LHsidHJhaXRfdHlwZSI6ICJEZXJpdmF0aXZlcyBSZXZlbnVlIENlbGxpbmciLCAidmFsdWUiOiAwfSx7InRyYWl0X3R5cGUiOiAiRGVyaXZhdGl2ZXMgQXBwcm92YWwiLCAidmFsdWUiOiAiZmFsc2UifSx7InRyYWl0X3R5cGUiOiAiRGVyaXZhdGl2ZXMgUmVjaXByb2NhbCIsICJ2YWx1ZSI6ICJmYWxzZSJ9LHsidHJhaXRfdHlwZSI6ICJMaWNlbnNvciIsICJ2YWx1ZSI6ICIweGEzOGM3NDk3YTU1M2E2Njk5Y2ZhYmIwZmExY2U4NzVkMTdmZTQ3ZjYifSx7InRyYWl0X3R5cGUiOiAiTGljZW5zZSBUZW1wbGF0ZSIsICJ2YWx1ZSI6ICIweDYxY2NmNzVmY2Q0NjEzMzNhOTU0ZmJkYWQyZDg1NDA2MzgzOTU3NjkifSx7InRyYWl0X3R5cGUiOiAiTGljZW5zZSBUZXJtcyBJRCIsICJ2YWx1ZSI6ICIxIn0seyJ0cmFpdF90eXBlIjogIlRyYW5zZmVyYWJsZSIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogIlJldm9rZWQiLCAidmFsdWUiOiAiZmFsc2UifV19";
    /* solhint-enable */

    function setUp() public override {
        super.setUp();
        uint256 commTermsId = registerSelectedPILicenseTerms_Commercial(
            "PIL_commercial_use",
            true,
            true,
            true,
            1,
            1 ether
        );
        mintTestLicense(address(pilTemplate), commTermsId);
    }

    function invariant_impossibleToMintOrBurn() public {
        assertEq(licenseToken.totalMintedTokens(), 1);
    }
}

contract LicenseTokenPermissionlessOneTokenNotTransferableInvariants is LicenseTokenBaseInvariants {
    function setUp() public override {
        super.setUp();
        uint256 commTermsId = registerSelectedPILicenseTerms_Commercial(
            "PIL_commercial_use",
            false,
            true,
            true,
            1,
            1 ether
        );
        mintTestLicense(address(pilTemplate), commTermsId);
    }

    function invariant_impossibleToMintOrBurn() public {
        assertEq(licenseToken.totalMintedTokens(), 1);
    }

    function invariant_notTransferable() public {
        assertEq(licenseToken.balanceOf(address(harness)), 1);
    }
}
