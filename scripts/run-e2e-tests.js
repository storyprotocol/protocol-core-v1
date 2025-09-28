#!/usr/bin/env node

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

/**
 * Load test configuration
 */
function loadTestConfig() {
  const configPath = path.join(__dirname, '..', 'test', 'hardhat', 'e2e', 'test-config.json');
  
  if (!fs.existsSync(configPath)) {
    throw new Error(`Test config file not found at: ${configPath}`);
  }
  
  const configContent = fs.readFileSync(configPath, 'utf8');
  return JSON.parse(configContent);
}

/**
 * Main function to run tests with network-specific exclusions
 */
function runTests() {
  const args = process.argv.slice(2);
  const networkIndex = args.findIndex(arg => arg === '--network');
  
  if (networkIndex === -1 || networkIndex === args.length - 1) {
    console.error('❌ Error: --network parameter is required');
    console.log('Usage: node scripts/run-e2e-tests.js --network <network-name> [other-hardhat-options]');
    process.exit(1);
  }
  
  const network = args[networkIndex + 1];
  const config = loadTestConfig();
  const networkConfig = config.networkExclusions[network];
  
  console.log(`\n🚀 Running E2E tests for ${network.toUpperCase()} network\n`);
  
  // Print configuration summary
  if (networkConfig) {
    console.log(`📝 Network: ${network}`);
    console.log(`📋 Description: ${networkConfig.description}`);
    
    if (networkConfig.excludePatterns && networkConfig.excludePatterns.length > 0) {
      console.log(`⏭️  Skipping tests with patterns:`);
      networkConfig.excludePatterns.forEach(pattern => {
        console.log(`   - "${pattern}"`);
      });
    }
    
    if (networkConfig.excludeFiles && networkConfig.excludeFiles.length > 0) {
      console.log(`⏭️  Skipping files:`);
      networkConfig.excludeFiles.forEach(file => {
        console.log(`   - ${file}`);
      });
    }
    
    if (networkConfig.excludeDescribe && networkConfig.excludeDescribe.length > 0) {
        console.log(`⏭️  Skipping describe blocks:`);
        networkConfig.excludeDescribe.forEach(pattern => {
            console.log(`   - "${pattern}"`);
        });
    }

    if (
      (!networkConfig.excludePatterns || networkConfig.excludePatterns.length === 0) &&
      (!networkConfig.excludeFiles || networkConfig.excludeFiles.length === 0) &&
      (!networkConfig.excludeDescribe || networkConfig.excludeDescribe.length === 0)
    ) {
      console.log(`✅ All tests will be executed`);
    }
  } else {
    console.log(`✅ No exclusions configured for ${network} - all tests will be executed`);
  }
  
  console.log('\n' + '='.repeat(60) + '\n');
  
  // Build the hardhat test command
  let testCommand = `npx hardhat test`;
  
  // Add network parameter
  testCommand += ` --network ${network}`;
  
  // Process additional arguments
  const additionalArgs = args.filter((arg, index) => 
    arg !== '--network' && index !== networkIndex + 1
  );
  
  // Handle test exclusions using environment variables
  if (networkConfig) {
    if (networkConfig.excludePatterns && networkConfig.excludePatterns.length > 0) {
      process.env.EXCLUDED_TEST_PATTERNS = JSON.stringify(networkConfig.excludePatterns);
    }
    
    if (networkConfig.excludeDescribe && networkConfig.excludeDescribe.length > 0) {
      process.env.EXCLUDED_DESCRIBE_BLOCKS = JSON.stringify(networkConfig.excludeDescribe);
    }
    
    if (networkConfig.excludeFiles && networkConfig.excludeFiles.length > 0) {
      process.env.EXCLUDED_FILES = JSON.stringify(networkConfig.excludeFiles);
    }
  }
  
  // Add remaining arguments
  if (additionalArgs.length > 0) {
    testCommand += ' ' + additionalArgs.join(' ');
  }
  
  console.log(`🔧 Executing: ${testCommand}\n`);
  
  try {
    execSync(testCommand, { stdio: 'inherit', cwd: process.cwd(), env: { ...process.env } });
    console.log(`\n✅ Tests completed successfully for ${network} network`);
  } catch (error) {
    console.error(`\n❌ Tests failed for ${network} network`);
    process.exit(error.status || 1);
  }
}

// Run the script
if (require.main === module) {
  runTests();
}

module.exports = { runTests, loadTestConfig };
