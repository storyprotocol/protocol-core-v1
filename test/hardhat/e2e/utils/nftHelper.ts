import { ethers } from "ethers"
import hre from "hardhat"


export async function mintNFT(walletAddress?: string): Promise<number> {
  const erc721ContractAddress: string = "0x7411143ef90b7744fc8233f01cce0b2c379651b3";
  let tokenId: any
  const contractAbi = [
    {
      inputs: [{ internalType: "address", name: "to", type: "address" }],
      name: "mint",
      outputs: [{ internalType: "uint256", name: "tokenId", type: "uint256" }],
      stateMutability: "nonpayable",
      type: "function",
    },
  ]

  const nftContract = await hre.ethers.getContractAt(contractAbi, erc721ContractAddress);

  const [owner] = await hre.ethers.getSigners();
  const address = walletAddress || owner.address

  const tx = await nftContract.mint(address)
  const receipt = await tx.wait()

  const logs = receipt.logs

  if (logs[0].topics[3]) {
    tokenId = parseInt(logs[0].topics[3], 16)
    console.log(`Minted NFT tokenId: ${tokenId}`)
  }

  return tokenId
}
