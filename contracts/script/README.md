# 🚀 Deployment Scripts

This directory contains the deployment and utility scripts for the Token Launch Platform.

## 📋 Primary Scripts

### `DeployComplete.s.sol` 
**🎯 Main deployment script - Use this for production deployment**

Deploys the entire system in one transaction:
- TokenFactory (creates project tokens)
- Giveaway (manages fair distribution)  
- LaunchPlatform (orchestrates both)

**Usage:**
```bash
forge script script/DeployComplete.s.sol --rpc-url <RPC_URL> --broadcast --verify
```

**Environment Variables:**
```bash
PRIVATE_KEY=0x...                    # Required: Deployer private key
PLATFORM_FEE_RECIPIENT=0x...        # Optional: Fee recipient (defaults to deployer)
USDC_ADDRESS=0x...                   # Optional: USDC contract address
```

## 🛠️ Utility Scripts

### `MerkleTreeUtils.js`
**JavaScript utilities for merkle tree generation and verification**

- Generate merkle trees for gas-efficient token distribution
- Verify participant allocations independently
- Create claim proofs for users

**Usage:**
```javascript
const { GiveawayMerkleTree } = require('./MerkleTreeUtils.js');

// Generate distribution
const distribution = await GiveawayMerkleTree.generateDistributionOffChain(
  giveawayContract, 
  giveawayId
);

// Get claim data for participant
const claimData = GiveawayMerkleTree.getClaimData(
  distribution, 
  participantAddress
);
```

### `VerifyMyAllocation.js`
**Independent verification script for participants**

Allows users to verify their token allocation calculations independently.

**Usage:**
```javascript
const verification = await GiveawayMerkleTree.verifyParticipantAllocation(
  giveawayContract,
  giveawayId,
  participantAddress,
  claimedTokenAmount,
  claimedRefundAmount
);
```

### `SimulateLaunchMerkle.s.sol`
**Testing and simulation script**

Comprehensive end-to-end simulation of the launch workflow including:
- Project creation
- User participation
- Merkle tree generation
- Token claiming

**Usage:**
```bash
forge script script/SimulateLaunchMerkle.s.sol --rpc-url <RPC_URL> --broadcast
```

## 🌐 Network Configuration

### Testnet (Celo Alfajores)
```bash
RPC_URL=https://alfajores-forno.celo-testnet.org
USDC_ADDRESS=0x765DE816845861e75A25fCA122bb6898B8B1282a
```

### Mainnet (Celo)
```bash
RPC_URL=https://forno.celo.org
USDC_ADDRESS=0x765DE816845861e75A25fCA122bb6898B8B1282a
```

## 🏗️ Deployment Checklist

1. **Set environment variables**
   ```bash
   export PRIVATE_KEY=0x...
   export PLATFORM_FEE_RECIPIENT=0x...
   export USDC_ADDRESS=0x...
   ```

2. **Deploy contracts**
   ```bash
   forge script script/DeployComplete.s.sol --rpc-url $RPC_URL --broadcast --verify
   ```

3. **Save contract addresses** from deployment output

4. **Update frontend configuration** with deployed addresses

5. **Test the deployment** using simulation script

## 📝 Notes

- **DeployComplete.s.sol** is the only script you need for production deployment
- All other scripts are utilities for testing, verification, and merkle tree operations
- The platform uses a single-transaction approach for maximum simplicity
- Frontend should primarily use LaunchPlatform contract for all project launches 