import hre from "hardhat";

export async function getIpAssetRegistry() {
  const contractAddress = "0x28E59E91C0467e89fd0f0438D47Ca839cDfEc095";
  const ipAssetRegistry = await hre.ethers.getContractAt("IPAssetRegistry", contractAddress);
  return ipAssetRegistry;
};