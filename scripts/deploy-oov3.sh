#!/bin/bash

# OOV3 Deployment Script
# This script deploys UMA's Optimistic Oracle V3 to the specified network
#
# Summary:
# This script automates the deployment of UMA's Optimistic Oracle V3 (OOV3) contracts
# to your specified network. It follows the official UMA quickstart process and
# generates deployment results for easy integration with your tests.
#
# Process Steps:
# 1. Check environment variables (RPC URL, private key, MockERC20 address)
# 2. Clone UMA OOV3 quickstart repository
# 3. Install dependencies using Foundry
# 4. Create configuration file with your settings
# 5. Deploy OOV3 contracts using forge script
# 6. Parse deployment results and save contract addresses
# 7. Clean up temporary files
#
# Requirements:
# - STORY_URL or RPC_URL environment variable
# - STORY_PRIVATEKEY environment variable
# - MockERC20 contract deployed (optional, defaults to 0x688abA77b2daA886c0aF029961Dc5fd219cEc3f6)
# - Sufficient ETH for gas fees
# - git and forge installed

set -e

echo "🚀 Starting OOV3 deployment..."

# Check required environment variables
if [ -z "$STORY_URL" ] && [ -z "$RPC_URL" ]; then
    echo "❌ Error: RPC URL not found. Please set STORY_URL or RPC_URL environment variable"
    exit 1
fi

if [ -z "$STORY_PRIVATEKEY" ]; then
    echo "❌ Error: Private key not found. Please set STORY_PRIVATEKEY environment variable"
    exit 1
fi

# Set default values
RPC_URL=${STORY_URL:-$RPC_URL}
MOCK_ERC20_ADDRESS=${MOCK_ERC20_ADDRESS:-"0x688abA77b2daA886c0aF029961Dc5fd219cEc3f6"}
DEFAULT_LIVENESS=${DEFAULT_LIVENESS:-600}
MINIMUM_BOND=${MINIMUM_BOND:-0}

echo "📡 RPC URL: $RPC_URL"
echo "💰 MockERC20 address: $MOCK_ERC20_ADDRESS"
echo "⏱️  Default liveness: $DEFAULT_LIVENESS seconds"
echo "💎 Minimum bond: $MINIMUM_BOND"

# Create temporary directory
TEMP_DIR="./temp-oov3-deploy"
if [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
fi
mkdir -p "$TEMP_DIR"

# Enter temporary directory
cd "$TEMP_DIR"

echo "📥 Cloning UMA OOV3 quickstart..."
git clone https://github.com/UMAprotocol/dev-quickstart-oov3.git .

echo "📦 Installing dependencies..."
forge install

echo "📝 Creating .env file..."
cat > .env << EOF
DEFAULT_CURRENCY=$MOCK_ERC20_ADDRESS
DEFAULT_LIVENESS=$DEFAULT_LIVENESS
MINIMUM_BOND=$MINIMUM_BOND
RPC_URL=$RPC_URL
STORY_PRIVATEKEY=$STORY_PRIVATEKEY
EOF

echo "🚀 Deploying OOV3 contracts..."
forge script script/OracleSandbox.s.sol \
    --fork-url "$RPC_URL" \
    --broadcast \
    --private-key "$STORY_PRIVATEKEY" \
    --priority-gas-price 1 \
    --legacy \
    --optimize

echo "✅ OOV3 deployment completed!"

# Parse deployment results
if [ -d "broadcast/OracleSandbox.s.sol" ]; then
    CHAIN_ID=$(ls broadcast/OracleSandbox.s.sol | head -1)
    DEPLOYMENT_FILE="broadcast/OracleSandbox.s.sol/$CHAIN_ID/run-latest.json"
    
    if [ -f "$DEPLOYMENT_FILE" ]; then
        echo ""
        echo "📊 Deployment Summary:"
        echo "====================="
        
        # Extract contract addresses
        echo "Extracting contract addresses..."
        
        # Create result files
        RESULT_FILE="../deployment-results/oov3-deployment.json"
        ENV_FILE="../.env.oov3"
        
        # Parse JSON and extract addresses
        echo "{" > "$RESULT_FILE"
        echo "# OOV3 Deployment Results" > "$ENV_FILE"
        
        # Use jq to parse JSON (if available)
        if command -v jq &> /dev/null; then
            echo "Using jq to parse deployment results..."
            jq -r '.transactions[] | select(.contractName and .contractAddress) | "\(.contractName): \(.contractAddress)"' "$DEPLOYMENT_FILE" | while read line; do
                if [ ! -z "$line" ]; then
                    contract_name=$(echo "$line" | cut -d: -f1 | tr -d ' ')
                    contract_address=$(echo "$line" | cut -d: -f2 | tr -d ' ')
                    echo "  \"$contract_name\": \"$contract_address\"," >> "$RESULT_FILE"
                    echo "$(echo $contract_name | tr '[:lower:]' '[:upper:]')=$contract_address" >> "$ENV_FILE"
                    echo "$contract_name: $contract_address"
                fi
            done
        else
            echo "⚠️  jq not available, showing raw deployment file location:"
            echo "📁 Deployment file: $DEPLOYMENT_FILE"
            echo "Please check the file manually for contract addresses"
        fi
        
        # Complete JSON file
        echo "}" >> "$RESULT_FILE"
        
        echo ""
        echo "💾 Deployment results saved to: $RESULT_FILE"
        echo "📝 Environment variables saved to: $ENV_FILE"
    fi
fi

# Return to original directory and cleanup
cd ..
rm -rf "$TEMP_DIR"
echo "🧹 Cleaned up temporary files"

echo ""
echo "🎉 OOV3 deployment completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Check the deployment results in deployment-results/oov3-deployment.json"
echo "2. Update your test configuration with the new OOV3 addresses"
echo "3. Run your dispute tests again"
