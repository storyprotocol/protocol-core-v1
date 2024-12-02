import hre from "hardhat";
import { GroupingModule, IPAssetRegistry, LicenseRegistry, LicenseToken, LicensingModule } from "./constants";

before(async function () {
  console.log(`================= Load Contract =================`);
  this.ipAssetRegistry = await hre.ethers.getContractAt("IPAssetRegistry", IPAssetRegistry);
  this.licenseRegistry = await hre.ethers.getContractAt("LicenseRegistry", LicenseRegistry);
  this.licenseToken = await hre.ethers.getContractAt("LicenseToken", LicenseToken);
  this.licensingModule = await hre.ethers.getContractAt("LicensingModule", LicensingModule);
  this.groupingModule = await hre.ethers.getContractAt("GroupingModule", GroupingModule);
  
  console.log(`================= Load Users =================`);
  [this.owner, this.user1] = await hre.ethers.getSigners();
});