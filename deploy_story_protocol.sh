#!/bin/bash

set -e
set -o pipefail
set -x


export DEVNET_VERSION="internal-devnet"
export BUILD_VERSION="main"
export TO_VERIFY="true"
export SEED="6"

DEVNET_VERSION="internal-devnet"


CHAINID="1512"
RPCURL="https://rpc.devnet.storyrpc.io"
EXPLORE_URL="https://devnet.storyscan.xyz/api"

export CHAINID RPCURL EXPLORE_URL


export STORY_DEPLOYER_ADDRESS="0x9B120E44D742912dBf635F39239616871E73e10c"
export MULTI_SIG_ADDRESS="0x7D01c62110fb498e6450A7857DD172dDd41EAbD3"
export STORY_GUARDIAN_ADDRESS="0x64E2238b30A2EF3D07e620A1Ef2998cDee63d434"
export CONTRACT_TEST_WALLET1="0xB1918E7d6CB67d027F6aBc66DC3273D6ECAD6dE5"
export CONTRACT_TEST_WALLET2="0x7f268c7a168f0Fc3cb3A79fDAd8a232C73B53B9E"
export CREATE3_DEPLOYER_ADDRESS="0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf"
export MOCK_ERC20_ADDRESS="0x688abA77b2daA886c0aF029961Dc5fd219cEc3f6"


if ! command -v forge &> /dev/null; then
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
fi


if ! command -v pnpm &> /dev/null; then
  npm install -g pnpm
fi


# if [ ! -d "protocol-core-v1" ]; then
#   git clone --branch "$BUILD_VERSION" https://github.com/storyprotocol/protocol-core-v1.git protocol-core-v1
# fi
# cd protocol-core-v1

# STORY_DEPLOYER_ADDRESS's private key
export PROTOCOL_DEPLOYER_PRIVATE_KEY=""

cat <<EOF > .env
STORY_PRIVATEKEY=$PROTOCOL_DEPLOYER_PRIVATE_KEY
JSON_RPC_PROVIDER_URL=$RPCURL
STORY_MULTISIG_ADDRESS=$MULTI_SIG_ADDRESS
STORY_RELAYER_ADDRESS=$MULTI_SIG_ADDRESS
STORY_GUARDIAN_ADDRESS=$STORY_GUARDIAN_ADDRESS
EOF


pnpm install
forge clean
forge compile --skip test


if [ "$CHAINID" != "1513" ]; then
  cp deploy-out/deployment-1513.json deploy-out/deployment-${CHAINID}.json
  cp deploy-out/deployment-1513.json deploy-out/deployment-v1.2-${CHAINID}.json
  cp deploy-out/deployment-1513.json deploy-out/deployment-v1.3-${CHAINID}.json
  sed -i.bak "s|block.chainid == 1513|block.chainid == $CHAINID|" "./script/foundry/utils/BroadcastManager.s.sol"
fi

if [ "$TO_VERIFY" = "true" ]; then
  forge script script/foundry/deployment/Main.s.sol:Main "$CREATE3_DEPLOYER_ADDRESS" $SEED \
    --sig "run(address,uint256)" \
    --fork-url $RPCURL -vvvv \
    --broadcast --sender "$STORY_DEPLOYER_ADDRESS" \
    --priority-gas-price 1 --legacy \
    --verify --verifier=blockscout --verifier-url="$EXPLORE_URL"
else
  forge script script/foundry/deployment/Main.s.sol:Main "$CREATE3_DEPLOYER_ADDRESS" $SEED \
    --sig "run(address,uint256)" \
    --fork-url $RPCURL -vvvv \
    --broadcast --sender "$STORY_DEPLOYER_ADDRESS" \
    --priority-gas-price 1 --legacy
fi


echo "Deployment Result:"
cat ./deploy-out/deployment-v1.3-${CHAINID}.json


mkdir -p deployment-results
cp ./broadcast/Main.s.sol/${CHAINID}/run-latest.json deployment-results/
cp ./deploy-out/deployment-v1.3-${CHAINID}.json deployment-results/

echo "🎉 deploy completed!"