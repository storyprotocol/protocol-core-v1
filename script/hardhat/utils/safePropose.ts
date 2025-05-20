import SafeApiKit from '@safe-global/api-kit'
import Safe from '@safe-global/protocol-kit'
import {
  MetaTransactionData,
  OperationType
} from '@safe-global/types-kit'

require("dotenv").config()

task("safe-propose", "Propose a Safe transaction")
  .addParam("chainid", "The chainId of the Safe")
  .addParam("operation", "The operation type: schedule, execute or cancel")
  .addParam("previousversion", "The previous version")
  .addParam("newversion", "The next version")
  .addParam("safeproposeraddress", "The address of the Safe multisig proposer")
  .addParam("safeproposerprivatekey", "The private key of the Safe multisig proposer")
  .addParam("safemultisigaddressmainnet", "The address of the Safe in mainnet")
  .addParam("safemultisigaddressaeneid", "The address of the Safe in aeneid")
  .setAction(async (taskArgs, hre) => {        
    const chainId = parseInt(taskArgs.chainid)
    const MAINNET_CHAIN_ID = 1514
    const TESTNET_CHAIN_ID = 1315
    if (chainId !== MAINNET_CHAIN_ID && chainId !== TESTNET_CHAIN_ID) throw new Error('Invalid chainId')

    const SAFE_PROPOSER_ADDRESS = taskArgs.safeproposeraddress
    const SAFE_PROPOSER_PRIVATE_KEY = taskArgs.safeproposerprivatekey
    const RPC_URL = chainId === MAINNET_CHAIN_ID ? 'https://mainnet.storyrpc.io' : 'https://aeneid.storyrpc.io'
    const SAFE_ADDRESS = chainId === MAINNET_CHAIN_ID ? taskArgs.safemultisigaddressmainnet : taskArgs.safemultisigaddressaeneid
    const TX_SERVICE_URL = chainId === MAINNET_CHAIN_ID ? 'https://transaction.safe.story.foundation/api' : 'https://transaction-testnet.safe.story.foundation/api'
    
    const apiKit = new SafeApiKit({
      chainId: BigInt(chainId),
      txServiceUrl: TX_SERVICE_URL
    })
    
    const protocolKitOwner1 = await Safe.init({
      provider: RPC_URL,
      signer: SAFE_PROPOSER_PRIVATE_KEY,
      safeAddress: SAFE_ADDRESS
    })

    // Import the txs file
    const safeTransactionData: MetaTransactionData[] = require(`../../../deploy-out/${taskArgs.operation}-v${taskArgs.previousversion}-to-v${taskArgs.newversion}-${chainId}.json`)
    
    const safeTransaction = await protocolKitOwner1.createTransaction({
      transactions: safeTransactionData
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
