import hre from "hardhat";

export const terms = {
  transferable: true,
  royaltyPolicy: hre.ethers.ZeroAddress,
  defaultMintingFee: 0,
  expiration: 0,
  commercialUse: false,
  commercialAttribution: false,
  commercializerChecker: hre.ethers.ZeroAddress,
  commercializerCheckerData: hre.ethers.ZeroAddress,
  commercialRevShare: 0,
  commercialRevCeiling: 0,
  derivativesAllowed: true,
  derivativesAttribution: false,
  derivativesApproval: false,
  derivativesReciprocal: false,
  derivativeRevCeiling: 0,
  currency: hre.ethers.ZeroAddress,
  uri: "",
};