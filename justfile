build:
     cd contracts && forge build

test:
    cd contracts && forge test  -vvv

script:
   cd contracts && forge script script/DeployComplete.s.sol:DeployComplete --rpc-url celo_alfajores -vvvv

deploy:
    cd contracts && forge script script/DeployComplete.s.sol:DeployComplete --rpc-url celo_alfajores --broadcast --verify -vvvv

simulate:
    cd contracts && forge script script/SimulateLaunchMerkle.s.sol:SimulateLaunchMerkle -vvv

simulate_verbose:
    cd contracts && forge script script/SimulateLaunchMerkle.s.sol:SimulateLaunchMerkle -vvvv

deploy_local:
    cd contracts && forge script script/DeployComplete.s.sol:DeployComplete --rpc-url http://localhost:8545 --broadcast --verify -vvvv

deploy_testnet:
    cd contracts && forge script script/DeployComplete.s.sol:DeployComplete --rpc-url celo_alfajores --broadcast --verify -vvvv

deploy_mainnet:
    cd contracts && forge script script/DeployComplete.s.sol:DeployComplete --rpc-url celo --broadcast --verify -vvvv