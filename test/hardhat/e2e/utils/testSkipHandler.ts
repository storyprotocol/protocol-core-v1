// Global test skip handler based on environment configuration
import { shouldSkipCurrentTest } from "./environmentHelper";

// Store original describe and it functions
const originalDescribe = global.describe;
const originalIt = global.it;

// Track skipped tests to avoid duplicate messages
const skippedTests = new Set<string>();
const skippedFiles = new Set<string>();

// Flag to prevent infinite recursion
let isProcessingSkip = false;

// Get current file name from stack trace
function getCurrentFileName(): string {
  const stack = new Error().stack;
  if (!stack) return '';
  
  const lines = stack.split('\n');
  // Skip the first few lines which are from this function and the enhanced functions
  for (let i = 3; i < lines.length; i++) {
    const line = lines[i];
    if (line.includes('.test.ts') && 
        !line.includes('testSkipHandler') && 
        !line.includes('environmentHelper') &&
        !line.includes('node_modules')) {
      const match = line.match(/([^/\\]+\.test\.ts)/);
      if (match) {
        return match[1];
      }
    }
  }
  return '';
}

// Enhanced describe function with auto-skip capability
function enhancedDescribe(title: string, fn: () => void) {
  const fileName = getCurrentFileName();
  const skipResult = shouldSkipCurrentTest(fileName, title);
  
  if (skipResult.shouldSkip) {
    // If it's a file-level skip, mark the entire file as skipped
    if (skipResult.level === 'file' && !skippedFiles.has(fileName)) {
      skippedFiles.add(fileName);
      console.log(`⏭️  Skipping entire file ${fileName} - ${skipResult.reason}`);
    } else if (skipResult.level === 'describe') {
      const skipKey = `describe:${fileName}:${title}`;
      if (!skippedTests.has(skipKey)) {
        skippedTests.add(skipKey);
        console.log(`⏭️  Skipping test suite "${title}" in ${fileName} - ${skipResult.reason}`);
      }
    }
    return originalDescribe.skip(title, fn);
  }
  
  return originalDescribe(title, fn);
}

// Enhanced it function with auto-skip capability  
function enhancedIt(title: string, fn?: () => void | Promise<void>) {
  // Prevent infinite recursion
  if (isProcessingSkip) {
    return originalIt.apply(this, arguments as any);
  }
  
  isProcessingSkip = true;
  
  try {
    const fileName = getCurrentFileName();
    
    // If the entire file is already marked as skipped, silently skip without logging
    if (skippedFiles.has(fileName)) {
      return originalIt.skip(title, fn);
    }
    
    const skipResult = shouldSkipCurrentTest(fileName, undefined, title);
    
    if (skipResult.shouldSkip) {
      const skipKey = `it:${fileName}:${title}`;
      if (!skippedTests.has(skipKey)) {
        skippedTests.add(skipKey);
        console.log(`⏭️  Skipping test "${title}" in ${fileName} - ${skipResult.reason}`);
      }
      return originalIt.skip(title, fn);
    }
    
    return originalIt(title, fn);
  } finally {
    isProcessingSkip = false;
  }
}

// Copy all properties from original functions
Object.setPrototypeOf(enhancedDescribe, originalDescribe);
Object.setPrototypeOf(enhancedIt, originalIt);

// Copy static methods
enhancedDescribe.skip = originalDescribe.skip;
enhancedDescribe.only = originalDescribe.only;
enhancedIt.skip = originalIt.skip;
enhancedIt.only = originalIt.only;

// Replace global functions
global.describe = enhancedDescribe as any;
global.it = enhancedIt as any;

export {}; // Make this a module
