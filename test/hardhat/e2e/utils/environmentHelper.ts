// Simple environment helper for handling different test environments
import { network } from "hardhat";

export interface TestSkipRule {
  file?: string; // File path pattern to match (e.g., "deployVault.test.ts", "group.royalty.test.ts")
  describe?: string; // Test suite description pattern to match
  it?: string; // Test case description pattern to match
  reason?: string; // Reason for skipping
}

export interface TestExpectedFailureRule {
  file?: string; // File path pattern to match
  describe?: string; // Test suite description pattern to match
  it?: string; // Test case description pattern to match
  operation?: string; // Operation pattern to match (e.g., "raiseDispute", "registerLicenseTemplate")
  errorType: keyof TestEnvironment['expectedErrors']; // Type of expected error
  reason?: string; // Reason for expected failure
}

export interface TestEnvironment {
  name: string;
  chainId: number;
  isAdminEnvironment: boolean;
  expectedErrors: {
    adminOperations: string; // Expected error code for admin operations (access control)
    licenseTemplateOperations: string; // Expected error code for license template operations
  };
  skipRules: TestSkipRule[]; // Rules for skipping specific tests
  expectedFailureRules: TestExpectedFailureRule[]; // Rules for expecting specific failures
}

// Define environment configurations
export const ENVIRONMENTS: Record<number, TestEnvironment> = {
  1512: { 
    name: 'internal-devnet', 
    chainId: 1512, 
    isAdminEnvironment: true,
    expectedErrors: {
      adminOperations: '', // No errors expected in admin environment
      licenseTemplateOperations: ''
    },
    skipRules: [], // No tests to skip in admin environment
    expectedFailureRules: [] // No expected failures in admin environment
  },
  1315: { 
    name: 'aeneid', 
    chainId: 1315, 
    isAdminEnvironment: false,
    expectedErrors: {
      adminOperations: '0x068ca9d8', // AccessControlUnauthorizedAccount
      licenseTemplateOperations: '0x068ca9d8' // AccessControlUnauthorizedAccount for license template operations
    },
    skipRules: [
      // Skip entire deployVault test file
      {
        file: "deployVault.test.ts",
        reason: "deployVault method not available in aeneid environment"
      },
      // Skip entire dispute test file
      {
        file: "dispute.test.ts",
        reason: "dispute operations not supported due to OOV3 setup issues in aeneid environment"
      },
      // Skip specific test in royalty.test.ts
      {
        file: "royalty.test.ts",
        it: "Should handle complete royalty flow after vault deployment - validates end-to-end payment and revenue distribution",
        reason: "requires deployVault functionality"
      },
      {
        file: "group.royalty.test.ts",
        it: "Should automatically deploy vaults during reward claim",
        reason: "specifically tests automatic vault deployment"
      }
    ],
    expectedFailureRules: [
      // License template operations expected to fail
      {
        file: "licenseTemplate.test.ts",
        operation: "registerLicenseTemplate",
        errorType: "licenseTemplateOperations",
        reason: "License template registration requires admin privileges"
      },
      // Admin operations expected to fail
      {
        operation: "whitelistRoyaltyToken",
        errorType: "adminOperations",
        reason: "Admin operations require admin privileges"
      },
      {
        operation: "setOOV3",
        errorType: "adminOperations", 
        reason: "Admin operations require admin privileges"
      },
      {
        operation: "setArbitrationRelayer",
        errorType: "adminOperations",
        reason: "Admin operations require admin privileges"
      },
      {
        operation: "setMaxBond",
        errorType: "adminOperations",
        reason: "Admin operations require admin privileges"
      }
    ]
  }
};

/**
 * Get current test environment
 */
export function getCurrentEnvironment(): TestEnvironment {
  const chainId = network.config.chainId || 1315;
  return ENVIRONMENTS[chainId] || { 
    name: 'unknown', 
    chainId, 
    isAdminEnvironment: false,
    expectedErrors: {
      adminOperations: '0x068ca9d8', // Default to access control error
      disputeOperations: '0x068ca9d8',
      licenseTemplateOperations: '0x068ca9d8'
    },
    skipRules: [], // No specific skip rules for unknown environments
    expectedFailureRules: [] // No expected failure rules for unknown environments
  };
}

/**
 * Check if current environment has admin privileges
 */
export function isAdminEnvironment(): boolean {
  return getCurrentEnvironment().isAdminEnvironment;
}

/**
 * Execute admin operation with environment-aware error handling
 * @param operation - Function that performs the admin operation
 * @param operationName - Name of the operation for logging
 */
export async function executeAdminOperation(
  operation: () => Promise<any>,
  operationName: string
): Promise<boolean> {
  const env = getCurrentEnvironment();
  
  try {
    await operation();
    console.log(`✅ ${operationName} succeeded in ${env.name} environment`);
    return true;
  } catch (error: any) {
    if (env.isAdminEnvironment) {
      // In admin environments, failures are unexpected
      console.error(`❌ ${operationName} failed unexpectedly in admin environment ${env.name}`);
      console.error("🔴 Error:", error.message);
      throw error;
    } else {
      // In non-admin environments, failures are expected
      console.log(`⚠️  ${operationName} failed as expected in non-admin environment ${env.name}`);
      console.log("📜 Error code:", error.data || "No error data");
      return false;
    }
  }
}

/**
 * Execute operation with environment-aware expectations
 * @param operation - Function that performs the operation
 * @param operationName - Name of the operation for logging
 * @param errorType - Type of error to expect ('adminOperations', 'disputeOperations', or 'licenseTemplateOperations')
 */
export async function executeWithEnvironmentExpectation(
  operation: () => Promise<any>,
  operationName: string,
  errorType: keyof TestEnvironment['expectedErrors'] = 'adminOperations'
): Promise<any> {
  const env = getCurrentEnvironment();
  
  if (env.isAdminEnvironment) {
    // In admin environments, operation should succeed
    try {
      const result = await operation();
      console.log(`✅ ${operationName} succeeded in admin environment ${env.name}`);
      return result;
    } catch (error: any) {
      console.error(`❌ ${operationName} failed unexpectedly in admin environment ${env.name}`);
      console.error("🔴 Error:", error.message);
      throw error;
    }
  } else {
    // In non-admin environments, operation should fail with expected error
    const expectedError = env.expectedErrors[errorType];
    console.log(`🧪 Testing ${operationName} failure in non-admin environment ${env.name}`);
    console.log(`📋 Expected error code: ${expectedError}`);
    
    try {
      await operation();
      throw new Error(`${operationName} succeeded but was expected to fail in ${env.name} environment`);
    } catch (error: any) {
      if (expectedError && error.data) {
        // Check for exact match first
        if (error.data.includes(expectedError)) {
          console.log(`✅ ${operationName} failed as expected with correct error code: ${expectedError}`);
          return null;
        }
        
        // For dispute operations, also check for specific error messages
        if (errorType === 'disputeOperations') {
          const errorData = error.data.toLowerCase();
          const errorMessage = error.message?.toLowerCase() || '';
          
          // Check for various dispute-related errors that are expected in non-admin environments
          if (errorData.includes('426f6e6420616d6f756e7420746f6f206c6f77') || // "Bond amount too low" in hex
              errorMessage.includes('bond amount too low') ||
              errorData.includes('08c379a0') || // Standard string error prefix
              expectedError === 'bond_amount_too_low') {
            console.log(`✅ ${operationName} failed as expected with dispute-related error: "Bond amount too low"`);
            return null;
          }
        }
        
        // For license template operations, check for access control errors
        if (errorType === 'licenseTemplateOperations') {
          // License template operations typically fail with access control errors in non-admin environments
          if (error.data && error.data.includes(expectedError)) {
            console.log(`✅ ${operationName} failed as expected with access control error: ${expectedError}`);
            return null;
          }
        }
        
        console.error(`❌ ${operationName} failed with unexpected error code`);
        console.error(`🔴 Expected: ${expectedError}, Got: ${error.data}`);
        console.error(`📜 Error message: ${error.message}`);
        throw new Error(`${operationName} failed with wrong error code. Expected: ${expectedError}, Got: ${error.data}`);
      } else {
        console.log(`✅ ${operationName} failed as expected in non-admin environment`);
        console.log(`📜 Error: ${error.message}`);
        return null;
      }
    }
  }
}

/**
 * Skip test if not supported in current environment
 */
export function skipIfNotAdmin(testContext: any, reason?: string) {
  const env = getCurrentEnvironment();
  if (!env.isAdminEnvironment) {
    const skipReason = reason || `Skipping test - requires admin privileges (current: ${env.name})`;
    console.log(`⏭️  ${skipReason}`);
    testContext.skip();
  }
}


/**
 * Check if current operation should expect failure based on expected failure rules
 */
export function shouldExpectOperationFailure(
  fileName?: string,
  describeTitle?: string,
  itTitle?: string,
  operationName?: string
): { shouldExpectFailure: boolean; errorType?: keyof TestEnvironment['expectedErrors']; reason?: string } {
  const env = getCurrentEnvironment();
  
  // In admin environments, operations should succeed
  if (env.isAdminEnvironment) {
    return { shouldExpectFailure: false };
  }
  
  for (const rule of env.expectedFailureRules) {
    let matches = true;
    
    // Check file pattern
    if (rule.file && fileName) {
      if (!fileName.includes(rule.file)) {
        matches = false;
      }
    }
    
    // Check describe pattern
    if (rule.describe && describeTitle) {
      if (!describeTitle.includes(rule.describe)) {
        matches = false;
      }
    }
    
    // Check it pattern
    if (rule.it && itTitle) {
      if (!itTitle.includes(rule.it)) {
        matches = false;
      }
    }
    
    // Check operation pattern
    if (rule.operation && operationName) {
      if (!operationName.includes(rule.operation)) {
        matches = false;
      }
    }
    
    // If this rule matches, expect failure
    if (matches && (rule.file || rule.describe || rule.it || rule.operation)) {
      return {
        shouldExpectFailure: true,
        errorType: rule.errorType,
        reason: rule.reason || `Operation expected to fail in ${env.name} environment`
      };
    }
  }
  
  return { shouldExpectFailure: false };
}

/**
 * Check if current test should be skipped based on skip rules
 */
export function shouldSkipCurrentTest(
  fileName?: string,
  describeTitle?: string, 
  itTitle?: string
): { shouldSkip: boolean; reason?: string; level?: 'file' | 'describe' | 'it' } {
  const env = getCurrentEnvironment();
  
  for (const rule of env.skipRules) {
    let matches = true;
    let matchLevel: 'file' | 'describe' | 'it' = 'it';
    
    // Check file pattern first
    if (rule.file && fileName) {
      if (!fileName.includes(rule.file)) {
        matches = false;
      }
    }
    
    // If file matches, check more specific patterns
    if (matches && rule.file && fileName && fileName.includes(rule.file)) {
      // If only file is specified, it's a file-level skip
      if (!rule.describe && !rule.it) {
        matchLevel = 'file';
      }
      // If describe is specified, check describe pattern
      else if (rule.describe && describeTitle) {
        if (!describeTitle.includes(rule.describe)) {
          matches = false;
        } else {
          matchLevel = 'describe';
        }
      }
      // If it is specified, check it pattern (only apply to 'it' calls)
      else if (rule.it && itTitle) {
        if (!itTitle.includes(rule.it)) {
          matches = false;
        } else {
          matchLevel = 'it';
        }
      }
      // If describe or it is specified but we're not in that context, don't match
      else if ((rule.describe && !describeTitle) || (rule.it && !itTitle)) {
        matches = false;
      }
    }
    
    // If this rule matches, skip the test
    if (matches && (rule.file || rule.describe || rule.it)) {
      return {
        shouldSkip: true,
        reason: rule.reason || `Test skipped in ${env.name} environment`,
        level: matchLevel
      };
    }
  }
  
  return { shouldSkip: false };
}

/**
 * Log current environment info
 */
export function logEnvironmentInfo() {
  const env = getCurrentEnvironment();
  console.log(`================= Environment Info =================`);
  console.log(`Environment: ${env.name}`);
  console.log(`Chain ID: ${env.chainId}`);
  console.log(`Admin Environment: ${env.isAdminEnvironment}`);
  console.log(`==================================================`);
}
