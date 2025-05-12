import SafeApiKit from '@safe-global/api-kit'
import Safe from '@safe-global/protocol-kit'
import {
  MetaTransactionData,
  OperationType
} from '@safe-global/types-kit'

require("dotenv").config()

task("safe-propose", "Propose a Safe transaction")
  .addParam("chainid", "The chainId of the Safe")
  .setAction(async (taskArgs, hre) => {        
    const chainId = parseInt(taskArgs.chainid)
    if (chainId !== Number(process.env.STORY_CHAINID) && chainId !== Number(process.env.STORY_CHAINID_MAINNET)) {
        throw new Error('Invalid chainId')
    }

    const RPC_URL = chainId === Number(process.env.STORY_CHAINID_MAINNET) ? process.env.STORY_URL_MAINNET : process.env.STORY_URL
    const SAFE_ADDRESS = chainId === Number(process.env.STORY_CHAINID_MAINNET) ? process.env.SAFE_MULTISIG_MAINNET_ADDRESS : process.env.SAFE_MULTISIG_AENEID_ADDRESS
    const SAFE_PROPOSER_ADDRESS = chainId === Number(process.env.STORY_CHAINID_MAINNET) ? process.env.SAFE_PROPOSER_MAINNET_ADDRESS : process.env.SAFE_PROPOSER_AENEID_ADDRESS
    const SAFE_PROPOSER_PRIVATE_KEY = chainId === Number(process.env.STORY_CHAINID_MAINNET) ? process.env.SAFE_PROPOSER_MAINNET_PRIVATE_KEY : process.env.SAFE_PROPOSER_AENEID_PRIVATE_KEY
    const TX_SERVICE_URL = chainId === Number(process.env.STORY_CHAINID_MAINNET) ? 'https://transaction.safe.story.foundation/api' : 'https://transaction-testnet.safe.story.foundation/api'
    
    const apiKit = new SafeApiKit({
      chainId: BigInt(chainId),
      txServiceUrl: TX_SERVICE_URL
    })
    
    const protocolKitOwner1 = await Safe.init({
      provider: RPC_URL,
      signer: SAFE_PROPOSER_PRIVATE_KEY,
      safeAddress: SAFE_ADDRESS
    })

    // Create transaction
    const safeTransactionData: MetaTransactionData = {
      to: '0x0000000000000000000000000000000000000000',
      value: '1', // 1 wei
      data: '0x',
      operation: OperationType.Call
    }
    
    const safeTransaction = await protocolKitOwner1.createTransaction({
      transactions: [safeTransactionData]
    })
    
    const safeTxHash = await protocolKitOwner1.getTransactionHash(safeTransaction)
    const signature = await protocolKitOwner1.signHash(safeTxHash)
    
    // Propose transaction to the service
    await apiKit.proposeTransaction({
      safeAddress: SAFE_ADDRESS,
      safeTransactionData: safeTransaction.data,
      safeTxHash,
      senderAddress: SAFE_PROPOSER_ADDRESS,
      senderSignature: signature.data
    })

    console.log('Transaction successfully proposed')
})
