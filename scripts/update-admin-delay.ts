import hre from "hardhat";
const { ethers } = hre as any;
import fs from "fs";
import path from "path";

/**
 * Admin Delay Update Script
 * 
 * This script automates the process of updating the admin delay for PROTOCOL_ADMIN_ROLE
 * in the AccessManager contract. It follows the proper schedule-execute pattern required
 * by OpenZeppelin's AccessManager.
 * 
 * Process Steps:
 * 1. Check current delay and verify multisig has PROTOCOL_ADMIN_ROLE
 * 2. Build grantRole transaction data with new delay
 * 3. Check if can execute immediately (delay=0) or need to schedule
 * 4a. If delay=0: Execute directly using grantRole()
 * 4b. If delay>0: Schedule transaction, wait delay, then execute using AccessManager.execute()
 * 5. Verify the delay was successfully updated
 * 
 * Requirements:
 * - config.json with accessManagerAddress, multisigAddress, multisigPrivateKey, newDelaySeconds
 * - Multisig must have PROTOCOL_ADMIN_ROLE
 * - Sufficient ETH for gas fees
 */

// Load configuration
function loadConfig() {
    const configPath = path.join(__dirname, "config.json");
    const configData = fs.readFileSync(configPath, "utf8");
    return JSON.parse(configData);
}

// ProtocolAdmin role constants
const ProtocolAdmin = {
    PROTOCOL_ADMIN_ROLE: BigInt(0),
    UPGRADER_ROLE: BigInt(1),
    PAUSE_ADMIN_ROLE: BigInt(2),
    GUARDIAN_ROLE: BigInt(3)
};

async function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
    const config = loadConfig();
    
    console.log("Starting admin delay update process...");
    console.log(`Configuration:`);
    console.log(`  - AccessManager: ${config.accessManagerAddress}`);
    console.log(`  - Multisig: ${config.multisigAddress}`);
    console.log(`  - New delay: ${config.newDelaySeconds} seconds`);
    
    // Get provider and multisig wallet
    const provider = ethers.provider;
    const multisigWallet = new ethers.Wallet(config.multisigPrivateKey, provider);
    
    // Get AccessManager contract instance
    const accessManager = await ethers.getContractAt("IAccessManager", config.accessManagerAddress);
    
    // Step 1: Check current delay
    console.log("\nStep 1: Checking current delay...");
    const [isMember, currentDelay] = await accessManager.hasRole(
        ProtocolAdmin.PROTOCOL_ADMIN_ROLE,
        config.multisigAddress
    );
    
    console.log(`Current PROTOCOL_ADMIN_ROLE status:`);
    console.log(`  - Is member: ${isMember}`);
    console.log(`  - Current delay: ${currentDelay} seconds`);
    
    if (!isMember) {
        console.error("Error: Multisig is not a member of PROTOCOL_ADMIN_ROLE");
        process.exit(1);
    }
    
    if (currentDelay === BigInt(config.newDelaySeconds)) {
        console.log("Delay is already at target value, no update needed");
        return;
    }
    
    // Step 2: Build grantRole transaction data
    console.log("\nStep 2: Building grantRole transaction data...");
    const grantRoleCalldata = accessManager.interface.encodeFunctionData(
        "grantRole",
        [ProtocolAdmin.PROTOCOL_ADMIN_ROLE, config.multisigAddress, config.newDelaySeconds]
    );
    
    console.log(`Grant role calldata: ${grantRoleCalldata}`);
    
    // Step 3: Check if we can execute directly (when delay is 0) or need to schedule
    console.log("\nStep 3: Checking execution permissions...");
    
    const [canExecute, execDelay] = await accessManager.canCall(
        multisigWallet.address,
        config.accessManagerAddress,
        "0x25c471a0" // grantRole function selector
    );
    
    console.log(`Execute permission check:`);
    console.log(`  - Can execute: ${canExecute}`);
    console.log(`  - Execute delay: ${execDelay} seconds`);
    
    let executeTx: any;
    let scheduleTx: any;
    
    if (canExecute && execDelay === 0n) {
        // Can execute immediately, no need to schedule
        console.log("Can execute immediately, skipping schedule step...");
        
        try {
            // Execute directly using grantRole
            executeTx = await accessManager.connect(multisigWallet).grantRole(
                ProtocolAdmin.PROTOCOL_ADMIN_ROLE,
                config.multisigAddress,
                config.newDelaySeconds
            );
            console.log(`Execute transaction sent: ${executeTx.hash}`);
            
            console.log("Waiting for execute transaction confirmation...");
            const executeReceipt = await executeTx.wait();
            console.log(`Execute transaction confirmed! Block: ${executeReceipt.blockNumber}`);
            console.log(`  - Gas used: ${executeReceipt.gasUsed.toString()}`);
            console.log(`  - Status: ${executeReceipt.status === 1 ? 'Success' : 'Failed'}`);
            
        } catch (error: any) {
            console.error("Direct execution failed:", error.message);
            
            if (error.data) {
                console.log("Error data:", error.data);
            }
            if (error.reason) {
                console.log("Error reason:", error.reason);
            }
            throw error;
        }
        
    } else {
        // Need to schedule first
        console.log("\nStep 4: Need to schedule transaction first...");
        
        const [canSchedule, scheduleDelay] = await accessManager.canCall(
            multisigWallet.address,
            config.accessManagerAddress,
            "0x4f51c6aa" // schedule(address,bytes,uint32) function selector
        );
        
        console.log(`Schedule permission check:`);
        console.log(`  - Can schedule: ${canSchedule}`);
        console.log(`  - Schedule delay: ${scheduleDelay} seconds`);
        
        // if (!canSchedule) {
        //     console.log(`Need to wait ${scheduleDelay} seconds before scheduling transaction...`);
            
        //     // Countdown wait for schedule delay
        //     for (let i = scheduleDelay; i > 0; i--) {
        //         process.stdout.write(`\rWaiting for schedule delay: ${i} seconds`);
        //         await sleep(1000);
        //     }
        //     console.log("\n");
        // }
        
        // Schedule transaction
        console.log("Scheduling transaction...");
        
        const scheduleCalldata = accessManager.interface.encodeFunctionData(
            "schedule",
            [config.accessManagerAddress, grantRoleCalldata, 0]
        );
        
        // Use default gas estimate
        let gasEstimate = BigInt(150000);
        console.log(`Using default gas: ${gasEstimate.toString()}`);
        
        const scheduleTransaction = {
            to: config.accessManagerAddress,
            data: scheduleCalldata,
            value: 0,
            gasLimit: gasEstimate * BigInt(120) / BigInt(100)
        };
        
        const scheduleTx = await multisigWallet.sendTransaction(scheduleTransaction);
        console.log(`Schedule transaction sent: ${scheduleTx.hash}`);
        
        console.log("Waiting for schedule transaction confirmation...");
        const scheduleReceipt = await scheduleTx.wait();
        console.log(`Schedule transaction confirmed! Block: ${scheduleReceipt.blockNumber}`);
        
        // Wait for delay time
        console.log("\nStep 5: Waiting for delay time...");
        console.log(`Need to wait ${currentDelay} seconds before executing...`);
        
        // Countdown
        for (let i = currentDelay; i > 0; i--) {
            process.stdout.write(`\rWaiting for delay: ${i} seconds`);
            await sleep(1000);
        }
        console.log("\n");
        
        // Wait extra 5 seconds to ensure sufficient time
        console.log("Waiting extra 5 seconds to ensure sufficient time...");
        for (let i = 5; i > 0; i--) {
            process.stdout.write(`\rExtra wait: ${i} seconds`);
            await sleep(1000);
        }
        console.log("\n");
        
        // Execute scheduled transaction
        console.log("Step 6: Executing scheduled transaction...");
        
        try {
            // Use AccessManager.execute function to properly consume the scheduled operation
            executeTx = await accessManager.connect(multisigWallet).execute(
                config.accessManagerAddress,
                grantRoleCalldata
            );
            console.log(`Execute transaction sent: ${executeTx.hash}`);
            
            console.log("Waiting for execute transaction confirmation...");
            const executeReceipt = await executeTx.wait();
            console.log(`Execute transaction confirmed! Block: ${executeReceipt.blockNumber}`);
            console.log(`  - Gas used: ${executeReceipt.gasUsed.toString()}`);
            console.log(`  - Status: ${executeReceipt.status === 1 ? 'Success' : 'Failed'}`);
            
        } catch (error: any) {
            console.error("Execute failed:", error.message);
            
            if (error.data) {
                console.log("Error data:", error.data);
            }
            if (error.reason) {
                console.log("Error reason:", error.reason);
            }
            throw error;
        }
    }
    
    // Step 7: Verify result
    console.log("\nStep 7: Verifying update result...");

    // Wait extra 5 seconds to ensure sufficient time
    console.log("Waiting extra 10 seconds to ensure sufficient time...");
    for (let i = 10; i > 0; i--) {
        process.stdout.write(`\rExtra wait: ${i} seconds`);
        await sleep(1000);
    }
    console.log("\n");
            
    const [updatedIsMember, updatedDelay] = await accessManager.hasRole(
        ProtocolAdmin.PROTOCOL_ADMIN_ROLE,
        config.multisigAddress
    );
    
    console.log(`Updated status:`);
    console.log(`  - Is member: ${updatedIsMember}`);
    console.log(`  - Delay: ${updatedDelay} seconds`);
    
    if (updatedDelay === BigInt(config.newDelaySeconds)) {
        console.log("Delay update successful! 🎉");
        console.log("Now immediate should return true, no delay needed!");
        console.log("\nSummary:");
        if (typeof scheduleTx !== 'undefined') {
            console.log(`  - Schedule transaction: ${scheduleTx.hash}`);
        }
        console.log(`  - Execute transaction: ${executeTx.hash}`);
        console.log(`  - Delay updated from ${currentDelay} seconds to ${updatedDelay} seconds`);
    } else {
        console.error("Delay update failed, actual value does not match expected 💥");
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
