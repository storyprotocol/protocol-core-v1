import { JsonRpcProvider } from "ethers"
import fs from "fs"
import hre from "hardhat"
import { DeployResult, DeployOptions } from "hardhat-deploy/dist/types"
import path from "path"

import { verify } from "../utils/verify"

const libraries: { [key: string]: string } = {}
const deploys: { [key: string]: { address: string; args?: any[] } } = {}

const ERC6551_REGISTRY = "0x000000006551c19487814612e58FE06813775758"

async function deployMain() {
  // DeployFunction
  const { deployments, getNamedAccounts, network } = hre
  const { deploy: deployFn } = deployments
  const { deployer } = await getNamedAccounts()
  // const deployerSigner = await ethers.getSigner(deployer)
  const provider = new JsonRpcProvider((hre.network.config as { url: string }).url)

  const defaultDeployOpts: DeployOptions = {
    from: deployer,
    log: true,
    waitConfirmations: 1,
  }

  const deployLibrary = async (libraryKey: string): Promise<string> => {
    console.log("/*////////////////////////////////////////////////////////////*/")
    console.log(`Deploying ${libraryKey}...`)
    const deployRes: DeployResult = await deployFn(libraryKey, { ...defaultDeployOpts })
    libraries[libraryKey] = deployRes.address
    console.log(`Deployed ${libraryKey} to: `, deployRes.address)

    await hre.tenderly.persistArtifacts({
      name: libraryKey,
      address: deployRes.address,
    })

    return deployRes.address
  }

  const deployContract = async (contractKey: string, extraDeployOpts?: Partial<DeployOptions>): Promise<string> => {
    console.log("/*////////////////////////////////////////////////////////////*/")
    console.log(`Deploying ${contractKey}...`)
    const deployRes: DeployResult = await deployFn(contractKey, { ...defaultDeployOpts, ...extraDeployOpts })
    deploys[contractKey] = { address: deployRes.address, args: deployRes.args }
    console.log(`Deployed ${contractKey} to: `, deployRes.address)

    await hre.tenderly.persistArtifacts({
      name: contractKey,
      address: deployRes.address,
    })

    return deployRes.address
  }

  console.log(
    `/*////////////////////////////////////////////////////////////\n
		\n											Network: ${network.name}
		\n////////////////////////////////////////////////////////////*/`
  )

  await _saveStateBeforeDeploy(provider)
  await _deployLibraries(deployLibrary)
  await _deployContracts(deployContract)
  // await _verifyAll()
  await _postDeploy()
}

async function _saveStateBeforeDeploy(provider: JsonRpcProvider) {
  // Save this checkpoint to revert back to this state anytime after deployment
  const checkpoint = (await provider.send("evm_snapshot", [])) as string
  console.log("Checkpoint created:", checkpoint)

  const outPath = path.join(__dirname, "../../out")
  const checkpointPath = path.join(outPath, "checkpoint.json")
  fs.writeFileSync(checkpointPath, JSON.stringify({ checkpoint }, null, 2))
}

async function _deployLibraries(deployLibrary: any) {
  // do one by one to keep nonce in order
  await deployLibrary("AccessPermission")
  await deployLibrary("Errors")
  await deployLibrary("IP")
  await deployLibrary("Licensing")
  await deployLibrary("IPAccountChecker")
}

async function _deployContracts(deployContract: any) {
  let contractKey: string

  contractKey = "AccessController"
  const accessController = await deployContract(contractKey, {
    libraries: {
      AccessPermission: libraries.AccessPermission,
      Errors: libraries.Errors,
      IPAccountChecker: libraries.IPAccountChecker,
    },
  })

  contractKey = "IPAccountImpl"
  const implementation = await deployContract(contractKey)

  contractKey = "ModuleRegistry"
  const moduleRegistry = await deployContract(contractKey, {
    libraries: {
      Errors: libraries.Errors,
    },
  })

  contractKey = "LicenseRegistry"
  const licenseRegistry = await deployContract(contractKey, {
    args: ["https://example.com/{id}.json"],
    libraries: {
      Errors: libraries.Errors,
      Licensing: libraries.Licensing,
    },
  })

  contractKey = "IPAccountRegistry"
  const ipAccountRegistry = await deployContract(contractKey, {
    args: [ERC6551_REGISTRY, accessController, implementation],
  })

  contractKey = "IPRecordRegistry"
  const ipRecordRegistry = await deployContract(contractKey, {
    args: [moduleRegistry, ipAccountRegistry],
    libraries: {
      Errors: libraries.Errors,
    },
  })

  contractKey = "IPMetadataResolver"
  const ipMetadataResolver = await deployContract(contractKey, {
    args: [accessController, ipRecordRegistry, ipAccountRegistry, licenseRegistry],
    libraries: {
      Errors: libraries.Errors,
      IP: libraries.IP,
    },
  })

  contractKey = "RegistrationModule"
  await deployContract(contractKey, {
    args: [accessController, ipRecordRegistry, ipAccountRegistry, licenseRegistry, ipMetadataResolver],
    libraries: {
      Errors: libraries.Errors,
      IP: libraries.IP,
    },
  })

  contractKey = "TaggingModule"
  await deployContract(contractKey, {
    libraries: {
      Errors: libraries.Errors,
    },
  })

  contractKey = "RoyaltyModule"
  await deployContract(contractKey, {
    libraries: {
      Errors: libraries.Errors,
    },
  })

  contractKey = "DisputeModule"
  await deployContract(contractKey, {
    libraries: {
      Errors: libraries.Errors,
    },
  })
}

async function _postDeploy() {
  // write content of deploys and libraries to out file
  const outPath = path.join(__dirname, "../../out")
  const deploysPath = path.join(outPath, "deploys.json")
  const librariesPath = path.join(outPath, "libraries.json")
  const deploysContent = JSON.stringify(deploys, null, 2)
  const librariesContent = JSON.stringify(libraries, null, 2)
  fs.writeFileSync(deploysPath, deploysContent)
  fs.writeFileSync(librariesPath, librariesContent)

  // combine deploys and libraries to all
  const deployAddresses: { [key: string]: string } = {}
  Object.keys(deploys).forEach((ck) => {
    deployAddresses[ck] = deploys[ck].address
  })

  // console.log("deploys", deploys)
  // console.log("deployAddresses", deployAddresses)
  const allAddresses = { contracts: { ...deployAddresses }, libraries }
  const allPath = path.join(outPath, "all.json")
  const allContent = JSON.stringify(allAddresses, null, 2)
  fs.writeFileSync(allPath, allContent)
}

async function _verifyAll() {
  const proms = Promise.all(Object.keys(deploys).map((ck) => verify(deploys[ck].address, deploys[ck].args || [])))
  return proms
    .then((res) => {
      console.log("Verified all contracts!")
    })
    .catch((err) => {
      console.log("Error verifying contracts:", err)
    })
}

// export default deployMain
// deployMain.tags = ["all"]

deployMain().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
