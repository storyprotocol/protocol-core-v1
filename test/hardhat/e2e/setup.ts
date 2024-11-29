import hre from "hardhat";

before(async function () {
  console.log(`================= Load Contract =================`);
  const ipAssetRegistryAddress = "0x28E59E91C0467e89fd0f0438D47Ca839cDfEc095";
  this.ipAssetRegistry = await hre.ethers.getContractAt("IPAssetRegistry", ipAssetRegistryAddress);

  const licenseRegistryAddress = "0xBda3992c49E98392e75E78d82B934F3598bA495f";
  this.licenseRegistry = await hre.ethers.getContractAt("LicenseRegistry", licenseRegistryAddress);

  const licenseTokenAddress = "0xB138aEd64814F2845554f9DBB116491a077eEB2D";
  this.licenseToken = await hre.ethers.getContractAt("LicenseToken", licenseTokenAddress);

  const licensingModule = "0x5a7D9Fa17DE09350F481A53B470D798c1c1aabae";
  this.licensingModule = await hre.ethers.getContractAt("LicensingModule", licensingModule);

  const groupNftAddress = "0x5d7C6e71290f034bED4C241eD78642204ad1178A";
  this.groupNft = await hre.ethers.getContractAt("GroupNFT", groupNftAddress);

  const groupingModuleAddress = "0xa731948cfE05135ad77d48C71f75066333Da78Bf";
  this.groupingModule = await hre.ethers.getContractAt("GroupingModule", groupingModuleAddress);
});