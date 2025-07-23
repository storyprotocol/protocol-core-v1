#!/bin/bash

# Detailed ModuleRegistry Upgrade Verification Script
# This script distinguishes between a successful proxy upgrade and a successful state initialization.

set -e

echo "🔬 Running Detailed ModuleRegistry Upgrade Verification..."

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- CONFIGURATION ---
# The address of the new implementation contract you deployed.
NEW_IMPL_ADDRESS="0xd68c9503d261370f1b378f4a9abb4b25003d3762"
# The standard EIP-1967 storage slot for the implementation address.
IMPL_SLOT="0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

# Check environment variables
check_env() {
    echo -e "\n${BLUE}📋 Checking environment variables...${NC}"
    if [ -z "$RPC_URL" ]; then
        echo -e "${RED}Error: RPC_URL not set${NC}"
        exit 1
    fi
    if [ -z "$PROXY_ADDRESS" ]; then
        echo -e "${RED}Error: PROXY_ADDRESS not set${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Environment variables are set.${NC}"
}

# 1. Verify the proxy is pointing to the new implementation address.
# This is the most fundamental check of a successful upgrade.
verify_implementation_address() {
    echo -e "\n${BLUE}1. Verifying Proxy Pointer...${NC}"
    echo "   (Checking if the proxy is pointing to the correct new implementation)"
    
    # Read the raw value from the implementation storage slot
    local stored_data=$(cast storage $PROXY_ADDRESS $IMPL_SLOT --rpc-url $RPC_URL)
    
    # Extract the address (last 40 characters / 20 bytes)
    local current_impl_address="0x$(echo $stored_data | cut -c 27-66)"
    
    echo "   - Expected Implementation: $NEW_IMPL_ADDRESS"
    echo "   - Actual Implementation:   $current_impl_address"
    
    if [ "$(echo "$current_impl_address" | tr '[:upper:]' '[:lower:]')" = "$(echo "$NEW_IMPL_ADDRESS" | tr '[:upper:]' '[:lower:]')" ]; then
        echo -e "${GREEN}✅ SUCCESS: Proxy is correctly pointing to the V2 implementation.${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILURE: Proxy is pointing to the WRONG address.${NC}"
        return 1
    fi
}

# 2. Verify that new functions can be called through the proxy.
# This proves the proxy forwarding mechanism is working correctly.
verify_call_forwarding() {
    echo -e "\n${BLUE}2. Verifying Call Forwarding...${NC}"
    echo "   (Checking if new V2 functions like foo() are callable)"

    # 'cast call' on a function with no return value should return "0x" on success.
    local result=$(cast call $PROXY_ADDRESS "foo(string)" "Hello V2!" --rpc-url $RPC_URL 2>/dev/null || echo "Call failed")
    
    if [ "$result" = "0x" ]; then
        echo -e "${GREEN}✅ SUCCESS: Proxy successfully forwarded the call to the new implementation.${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILURE: Call to new function foo() failed or returned unexpected data.${NC}"
        echo "   - Result: $result"
        return 1
    fi
}

# 3. Verify the state of the new implementation.
# This checks if the new version was initialized correctly.
verify_contract_state() {
    echo -e "\n${BLUE}3. Verifying V2 State Initialization...${NC}"
    echo "   (Checking if getVersion() returns the correct value 'V2')"
    
    local version_hex=$(cast call $PROXY_ADDRESS "getVersion()" --rpc-url $RPC_URL 2>/dev/null || echo "Call failed")
    
    # The string "V2" is encoded as hex. We can just check for the expected hex value.
    # For simplicity, we can also decode it. Here we check the raw hex.
    # Expected: 0x...20 (offset) ... 02 (length) 5632 (V2) 00...
    
    if [[ "$version_hex" == *"5632"* ]]; then # "V2" in hex is 5632
        echo -e "${GREEN}✅ SUCCESS: V2 contract state is correctly initialized. getVersion() returned 'V2'.${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILURE: V2 contract state appears uninitialized.${NC}"
        echo "   - Expected getVersion() to return 'V2'."
        echo "   - Actual raw hex returned: $version_hex (This likely decodes to an empty string)"
        return 1
    fi
}

# Main function
main() {
    echo "======================================================"
    echo "      Detailed ModuleRegistry Upgrade Diagnosis"
    echo "======================================================"
    echo "Proxy Address: $PROXY_ADDRESS"
    echo "RPC URL:       $RPC_URL"
    
    check_env
    
    local proxy_ok=false
    local forwarding_ok=false
    local state_ok=false
    
    verify_implementation_address && proxy_ok=true
    verify_call_forwarding && forwarding_ok=true
    verify_contract_state && state_ok=true
    
    echo -e "\n\n"
    echo "======================================================"
    echo "                     Final Diagnosis"
    echo "======================================================"
    
    if [ "$proxy_ok" = true ]; then
        echo -e "${GREEN}✅ Proxy Upgrade: SUCCESSFUL.${NC} The proxy correctly points to the new V2 implementation."
    else
        echo -e "${RED}❌ Proxy Upgrade: FAILED.${NC} The proxy does NOT point to the new V2 implementation."
    fi
    
    if [ "$forwarding_ok" = true ]; then
        echo -e "${GREEN}✅ Call Forwarding: WORKING.${NC} The proxy is able to forward calls to the new functions."
    else
        echo -e "${RED}❌ Call Forwarding: FAILED.${NC} The proxy is NOT forwarding calls correctly."
    fi
    
    if [ "$state_ok" = true ]; then
        echo -e "${GREEN}✅ State Initialization: SUCCESSFUL.${NC} The new version's state is correctly initialized."
    else
        echo -e "${RED}❌ State Initialization: FAILED.${NC} The new version was NOT initialized correctly after the upgrade."
    fi
    
    echo "======================================================"
}

main 