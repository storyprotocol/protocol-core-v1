// mockERC20 - mint, approveSpender, Allowance

import hre from "hardhat"
import { MockERC20 } from "../constants";
import { ethers } from "ethers";

// mockERC20 - approveSpender
export async function approveSpender(spender: string, amount: bigint, singer: ethers.Wallet):Promise<string> {
  const contractAbi = [
      {
          type: "function",
          inputs: [
              { name: "spender", internalType: "address", type: "address" },
              { name: "amount", internalType: "uint256", type: "uint256" },
          ],
          name: "approve",
          outputs: [{ name: "", internalType: "bool", type: "bool" }],
          stateMutability: "nonpayable",
      }
  ];
  
  const contract = new hre.ethers.Contract(MockERC20, contractAbi, singer);

  // approveSpender
  try {
      const tx = await contract.approve(
          spender,
          amount
      );
      await tx.wait();
      console.log("hash", tx.hash);
      console.log("approveSpender done");
      return tx.hash;
  } catch (error) {
      console.error("Error approveSpender:", error);
      throw error;
  };
};

// mockERC20 - mint
export async function mintAmount(toAddress: string, amount: bigint, singer: ethers.Wallet):Promise<string> {
  const contractAbi = [
      {
          type: "function",
          inputs: [
              { name: "to", internalType: "address", type: "address" },
              { name: "amount", internalType: "uint256", type: "uint256" },
          ],
          name: "mint",
          outputs: [{ name: "", internalType: "bool", type: "bool" }],
          stateMutability: "nonpayable",
      }
  ];
  
  const contract = new hre.ethers.Contract(MockERC20, contractAbi, singer);

  // mintAmount
  try {
      const tx = await contract.mint(
          toAddress,
          amount
      );
      await tx.wait();
      console.log("hash", tx.hash);
      return tx.hash;
  } catch (error) {
      console.error("Error mintAmount:", error);
      throw error;
  };
};

// mockERC20 - Allowance
export async function getAllowance(owner: string, spender: string, singer: ethers.Wallet):Promise<bigint> {
  const contractAbi = [
      {
          type: "function",
          inputs: [
              { name: "owner", internalType: "address", type: "address" },
              { name: "spender", internalType: "address", type: "address" },
          ],
          name: "allowance",
          outputs: [{ name: "", internalType: "uint256", type: "uint256" }],
          stateMutability: "view",
        }
  ];
  
  const contract = new hre.ethers.Contract(MockERC20, contractAbi, singer);

  // getAllowance
  try {
      const tx = await contract.allowance(owner, spender);
      console.log("Allowance", tx);
      return tx;
  } catch (error) {
      console.error("Error getAllowance:", error);
      throw error;
  };
};

export async function checkAndApproveSpender(owner: any, spender: any, amount: bigint) {
    console.log(`owner.address: ${owner.address}`);
    console.log(`spender.address: ${spender}`);
    const currentAllowance = await getAllowance(owner.address, spender, owner);
    if (currentAllowance < amount) {
        // await mintAmount(owner.address, amount, owner);
        await deposit(( amount - currentAllowance), owner);
        await approveSpender(spender, amount, owner);
    }
  };

export async function getErc20Balance(address: string): Promise<bigint> {
  console.log("============ Get Erc20 Balance ============");
  const contractAbi = [
    // Read-Only Functions
    "function balanceOf(address owner) view returns (uint256)",
    "function decimals() view returns (uint8)",
    "function symbol() view returns (string)",

    // Authenticated Functions
    "function transfer(address to, uint amount) returns (bool)",

    // Events
    "event Transfer(address indexed from, address indexed to, uint amount)",
  ];
  const contract = await hre.ethers.getContractAt(contractAbi, MockERC20);
  const balance = await contract.balanceOf(address);
  console.log(address, balance);
  return balance;
};

// mockERC20 - deposit
export async function deposit(amount: bigint, singer: ethers.Wallet) {
    const contractAbi = [
        {
            type: "function",
            inputs: [],
            name: "deposit",
            outputs: [],
            stateMutability: "payable",
        }
    ];
    
    const contract = new hre.ethers.Contract(MockERC20, contractAbi, singer);
  
    // mintAmount
    try {
        const tx = await contract.deposit(
            { value: amount }
        );
        await tx.wait();
        console.log("hash", tx.hash);
        return tx.hash;
    } catch (error) {
        console.error("Error mintAmount:", error);
        throw error;
    };
  };
