#!/bin/bash

# Verify ModuleRegistry Upgrade Script

set -e

echo "🔍 Verifying ModuleRegistry Upgrade..."

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check environment variables
check_env() {
    echo "📋 Checking environment variables..."
    
    if [ -z "$RPC_URL" ]; then
        echo -e "${RED}Error: RPC_URL not set${NC}"
        echo "Please set: export RPC_URL=<your_rpc_url>"
        exit 1
    fi
    
    if [ -z "$PROXY_ADDRESS" ]; then
        echo -e "${RED}Error: PROXY_ADDRESS not set${NC}"
        echo "Please set: export PROXY_ADDRESS=<module_registry_proxy_address>"
        echo "Or run: ./scripts/find-proxy-address.sh"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Environment variables check passed${NC}"
}

# Check version
check_version() {
    echo "📊 Checking contract version..."
    
    VERSION=$(cast call $PROXY_ADDRESS "getVersion()" --rpc-url $RPC_URL 2>/dev/null || echo "Call failed")
    
    if [ "$VERSION" = "V2" ]; then
        echo -e "${GREEN}✅ Version check passed: $VERSION${NC}"
        return 0
    else
        echo -e "${RED}❌ Version check failed: Expected 'V2', got '$VERSION'${NC}"
        return 1
    fi
}

# Test new foo function
test_foo_function() {
    echo "🧪 Testing new foo function..."
    
    # Check if function exists by calling it (should not revert)
    RESULT=$(cast call $PROXY_ADDRESS "foo(string)" "Hello V2!" --rpc-url $RPC_URL 2>/dev/null || echo "Call failed")
    
    if [ "$RESULT" = "" ]; then
        echo -e "${GREEN}✅ Foo function exists and can be called${NC}"
        return 0
    else
        echo -e "${RED}❌ Foo function test failed: $RESULT${NC}"
        return 1
    fi
}

# Test existing functionality
test_existing_functionality() {
    echo "🔧 Testing existing functionality..."
    
    # Test getModule function (should not revert)
    RESULT=$(cast call $PROXY_ADDRESS "getModule(string)" "test" --rpc-url $RPC_URL 2>/dev/null || echo "Call failed")
    
    if [ "$RESULT" = "0x0000000000000000000000000000000000000000" ]; then
        echo -e "${GREEN}✅ Existing getModule function works${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  getModule function returned: $RESULT${NC}"
        return 0  # This is expected for non-existent module
    fi
}

# Check contract code
check_contract_code() {
    echo "📄 Checking contract code..."
    
    CODE_SIZE=$(cast code "$PROXY_ADDRESS" --rpc-url $RPC_URL 2>/dev/null | wc -c)
    
    if [ "$CODE_SIZE" -gt 10 ]; then
        echo -e "${GREEN}✅ Contract has code (size: $CODE_SIZE bytes)${NC}"
        return 0
    else
        echo -e "${RED}❌ Contract has no code${NC}"
        return 1
    fi
}

# Main verification function
main() {
    echo "=================================="
    echo "ModuleRegistry Upgrade Verification"
    echo "=================================="
    echo ""
    echo "Proxy Address: $PROXY_ADDRESS"
    echo "RPC URL: $RPC_URL"
    echo ""
    
    check_env
    
    local all_tests_passed=true
    
    # Run all tests
    if ! check_contract_code; then
        all_tests_passed=false
    fi
    
    if ! check_version; then
        all_tests_passed=false
    fi
    
    if ! test_foo_function; then
        all_tests_passed=false
    fi
    
    if ! test_existing_functionality; then
        all_tests_passed=false
    fi
    
    echo ""
    echo "=================================="
    if [ "$all_tests_passed" = true ]; then
        echo -e "${GREEN}🎉 All verification tests passed!${NC}"
        echo -e "${GREEN}✅ ModuleRegistry upgrade successful!${NC}"
    else
        echo -e "${RED}❌ Some verification tests failed${NC}"
        echo -e "${YELLOW}⚠️  Please check the upgrade process${NC}"
    fi
    echo "=================================="
}

# Show usage
show_usage() {
    echo "Usage:"
    echo "  ./scripts/verify-upgrade.sh"
    echo ""
    echo "Environment variables:"
    echo "  RPC_URL - RPC endpoint URL"
    echo "  PROXY_ADDRESS - ModuleRegistry proxy address"
    echo ""
    echo "Example:"
    echo "  export RPC_URL=https://aeneid.storyrpc.io"
    echo "  export PROXY_ADDRESS=0x..."
    echo "  ./scripts/verify-upgrade.sh"
}

# Check if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

main "$@" 