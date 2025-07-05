# Merkle Tree Distribution System

This document explains the gas-efficient merkle tree distribution system for token giveaways.

## Overview

The merkle tree distribution system provides **highly gas-efficient token claiming** using cryptographic proofs instead of on-chain computation. This scales to millions of participants while maintaining minimal gas costs (~30-50k gas per claim vs ~100k+ for traditional methods).

## Key Benefits

- ⚡ **Ultra Gas Efficient**: ~30-50k gas per claim
- 📈 **Massive Scalability**: Supports millions of participants
- 🔒 **Cryptographically Secure**: Uses Merkle proofs for verification
- 💾 **Minimal Storage**: Only stores a single 32-byte merkle root
- 🚀 **Professional Standard**: Used by all major DeFi protocols

## How It Works

### Giveaway Flow
```
Create Giveaway → Participate → Finalize → setMerkleRoot() → merkleClaim()
```

**No traditional claiming available** - All token distribution uses merkle proofs for maximum efficiency.

## Implementation Guide

### Step 1: Create & Finalize Giveaway (Same as Before)

```solidity
// 1. Create giveaway
uint256 giveawayId = giveaway.createGiveaway(
    tokenAddress,
    startTime,
    endTime,
    maxAllocation,
    totalTokensForSale
);

// 2. Users participate (same as before)
giveaway.deposit(giveawayId, amount);

// 3. Finalize after end time
giveaway.finalizeGiveaway(giveawayId);
```

### Step 2: Generate Merkle Tree (Off-chain)

Use the provided JavaScript utility:

```javascript
const { GiveawayMerkleTree } = require('./script/MerkleTreeUtils.js');

// Get participant data from contract
const participants = [
    {
        address: '0x1234...',
        tokenAmount: ethers.utils.parseEther('1000'), // 1000 tokens
        refundAmount: ethers.utils.parseUnits('50', 6) // 50 USDC refund
    },
    // ... more participants
];

// Generate merkle tree
const merkleTree = new GiveawayMerkleTree(participants);
const merkleRoot = merkleTree.getRoot();

// Get proofs for each participant
const proofs = participants.map((_, index) => merkleTree.getProof(index));
```

### Step 3: Set Merkle Root (On-chain)

```solidity
// Project owner sets the merkle root
giveaway.setMerkleRoot(giveawayId, merkleRoot);
```

### Step 4: Users Claim Tokens

#### Option A: Individual Claim
```solidity
giveaway.merkleClaim(
    giveawayId,
    claimIndex,        // Participant's index in merkle tree
    participant,       // Participant address
    tokenAmount,       // Tokens to claim
    refundAmount,      // USDC refund (if any)
    merkleProof        // Cryptographic proof
);
```

#### Option B: Batch Claim (Most Efficient)
```solidity
giveaway.batchMerkleClaim(
    giveawayId,
    claimIndices,      // Array of indices
    participants,      // Array of addresses
    tokenAmounts,      // Array of token amounts
    refundAmounts,     // Array of refund amounts
    merkleProofs       // Array of proofs
);
```

## Complete Example

### JavaScript/TypeScript Frontend

```javascript
import { ethers } from 'ethers';
import { GiveawayMerkleTree } from './MerkleTreeUtils.js';

async function setupMerkleDistribution(giveawayId) {
    // 1. Get participants from contract
    const participantAddresses = await giveaway.getGiveawayParticipants(giveawayId);
    
    // 2. Calculate allocations for each participant
    const participants = await Promise.all(
        participantAddresses.map(async (address, index) => {
            const tokenAmount = await giveaway.calculateTokenAllocation(giveawayId, address);
            const refundAmount = await giveaway.calculateRefund(giveawayId, address);
            
            return {
                address,
                tokenAmount,
                refundAmount
            };
        })
    );
    
    // 3. Generate merkle tree
    const merkleTree = new GiveawayMerkleTree(participants);
    const merkleRoot = merkleTree.getRoot();
    
    // 4. Set merkle root (project owner only)
    await giveaway.setMerkleRoot(giveawayId, merkleRoot);
    
    // 5. Return distribution data for frontend
    return {
        merkleRoot,
        participants: participants.map((participant, index) => ({
            ...participant,
            index,
            proof: merkleTree.getProof(index)
        }))
    };
}

async function claimTokens(giveawayId, participantData) {
    await giveaway.merkleClaim(
        giveawayId,
        participantData.index,
        participantData.address,
        participantData.tokenAmount,
        participantData.refundAmount,
        participantData.proof
    );
}
```

### Solidity Integration

```solidity
// Get merkle info (merkle is always used for claiming)
(bytes32 merkleRoot, bool merkleEnabled) = giveaway.getMerkleInfo(giveawayId);

// Claim using merkle proof (only claiming method available)
giveaway.merkleClaim(giveawayId, index, user, tokenAmount, refundAmount, proof);
```

## Gas Comparison

| Method | Gas Cost | Scalability | Notes |
|--------|----------|-------------|-------|
| `merkleClaim()` | ~30-50k | Unlimited | Cryptographic proof |
| `batchMerkleClaim()` | ~25-40k per claim | Unlimited | Most efficient |

**Previous on-chain methods (~100-150k gas) have been removed for maximum efficiency.**

## Security Considerations

1. **Merkle Root Integrity**: Ensure off-chain calculation is correct
2. **Proof Generation**: Use trusted scripts for proof generation
3. **Index Uniqueness**: Each participant must have a unique index
4. **Double Claiming**: Contract prevents double claiming automatically

## Testing

Run the comprehensive test suite:

```bash
forge test --match-contract GiveawayTest --match-test testMerkle -vvv
```

## Deployment Checklist

- [ ] Deploy updated contract with merkle support
- [ ] Test merkle tree generation scripts
- [ ] Verify proof generation and verification
- [ ] Update frontend to support both claim methods
- [ ] Test with small giveaway first

## Implementation Status

**✅ Merkle-Only Distribution**: All giveaways now use merkle tree distribution exclusively for maximum gas efficiency and scalability.

No traditional claiming methods are available - this ensures all users benefit from the most efficient distribution system used by major DeFi protocols.

## API Reference

### Contract Functions

#### `setMerkleRoot(uint256 giveawayId, bytes32 merkleRoot)`
- Sets merkle root for gas-efficient distribution
- Only callable by project owner after finalization

#### `merkleClaim(uint256 giveawayId, uint256 claimIndex, address participant, uint256 tokenAmount, uint256 refundAmount, bytes32[] merkleProof)`
- Claims tokens using merkle proof
- Primary token claiming method (30-50k gas)

#### `batchMerkleClaim(...)`
- Claims tokens for multiple participants in one transaction
- Most gas-efficient option for bulk operations

#### `isMerkleClaimed(uint256 giveawayId, uint256 claimIndex)`
- Checks if a specific claim has been made

#### `getMerkleInfo(uint256 giveawayId)`
- Returns merkle root and enabled status

### Events

#### `MerkleRootSet(uint256 indexed giveawayId, bytes32 merkleRoot)`
- Emitted when merkle root is set

#### `MerkleTokensClaimed(uint256 indexed giveawayId, uint256 indexed claimIndex, address indexed participant, uint256 tokenAmount, uint256 refundAmount)`
- Emitted when tokens are claimed via merkle proof

## Support

For technical support or questions about the merkle distribution system, please refer to the test cases in `Giveaway.t.sol` or check the utility functions in `MerkleTreeUtils.js`. 