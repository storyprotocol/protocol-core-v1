// Purpose: Helper function to mint a new NFT and return the tokenId

import hre from "hardhat"
import { MockERC721 } from "../constants";
import { ethers } from "ethers";


export async function mintNFT(singer?: ethers.Wallet): Promise<number> {
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

  const caller = singer || (await hre.ethers.getSigners())[0]
  const nftContract = await hre.ethers.getContractAt(contractAbi, MockERC721, caller);
  const tx = await nftContract.mint(caller.address)
  const receipt = await tx.wait()

  const logs = receipt.logs

  if (logs[0].topics[3]) {
    tokenId = parseInt(logs[0].topics[3], 16)
    console.log(`Minted NFT tokenId: ${tokenId}`)
  }

  return tokenId
}
