import hre from "hardhat"
import { MockERC721 } from "../constants";


export async function mintNFT(walletAddress?: string): Promise<number> {
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

  const nftContract = await hre.ethers.getContractAt(contractAbi, MockERC721);

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
