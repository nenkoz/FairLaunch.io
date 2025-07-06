// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Giveaway} from "../src/Giveaway.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Simple mintable ERC20 for testing
contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract GiveawayTest is Test {
    Giveaway public giveaway;
    TestToken public usdc;
    TestToken public projectToken;

    address public owner = address(0x1);
    address public platformFeeRecipient = address(0x2);
    address public projectOwner = address(0x3);
    address public participant1 = address(0x4);
    address public participant2 = address(0x5);

    // Self.xyz test data
    uint256 public constant NULLIFIER_1 = 12345;
    uint256 public constant USER_ID_1 = 67890;
    uint256 public constant NULLIFIER_2 = 54321;
    uint256 public constant USER_ID_2 = 98765;

    uint256 public constant INITIAL_BALANCE = 1000000e6; // 1M USDC
    uint256 public constant GIVEAWAY_TOKENS = 100000e18; // 100K project tokens
    uint256 public constant MAX_ALLOCATION = 10000e6; // 10K USDC
    uint256 public constant DEPOSIT_AMOUNT = 1000e6; // 1K USDC

    // ============ Merkle Tree Helper Functions ============

    /**
     * @notice Create proper merkle tree compatible with OpenZeppelin's MerkleProof
     * @param leaves Array of leaf hashes
     * @return root The merkle root
     */
    function createMerkleTree(
        bytes32[] memory leaves
    ) internal pure returns (bytes32 root) {
        require(leaves.length > 0, "Empty leaves array");

        if (leaves.length == 1) {
            return leaves[0];
        }

        // Sort leaves to ensure deterministic tree
        _sortBytes32Array(leaves);

        uint256 n = leaves.length;
        bytes32[] memory currentLevel = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            currentLevel[i] = leaves[i];
        }

        while (currentLevel.length > 1) {
            bytes32[] memory nextLevel = new bytes32[](
                (currentLevel.length + 1) / 2
            );

            for (uint256 i = 0; i < currentLevel.length; i += 2) {
                bytes32 left = currentLevel[i];
                bytes32 right = i + 1 < currentLevel.length
                    ? currentLevel[i + 1]
                    : bytes32(0);

                nextLevel[i / 2] = _hashPair(left, right);
            }

            currentLevel = nextLevel;
        }

        return currentLevel[0];
    }

    /**
     * @notice Generate merkle proof for a leaf
     * @param leaves Array of all leaf hashes
     * @param targetLeaf The leaf to generate proof for
     * @return proof Array of sibling hashes for the merkle proof
     */
    function generateMerkleProof(
        bytes32[] memory leaves,
        bytes32 targetLeaf
    ) internal pure returns (bytes32[] memory proof) {
        require(leaves.length > 0, "Empty leaves array");

        // Find the index of the target leaf
        uint256 targetIndex = type(uint256).max;
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == targetLeaf) {
                targetIndex = i;
                break;
            }
        }
        require(targetIndex != type(uint256).max, "Target leaf not found");

        if (leaves.length == 1) {
            return new bytes32[](0); // No proof needed for single leaf
        }

        // Sort leaves and find new index
        _sortBytes32Array(leaves);
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == targetLeaf) {
                targetIndex = i;
                break;
            }
        }

        bytes32[] memory proofArray = new bytes32[](32); // Max possible depth
        uint256 proofLength = 0;

        bytes32[] memory currentLevel = new bytes32[](leaves.length);
        for (uint256 i = 0; i < leaves.length; i++) {
            currentLevel[i] = leaves[i];
        }

        uint256 currentIndex = targetIndex;

        while (currentLevel.length > 1) {
            // Get sibling
            uint256 siblingIndex = currentIndex % 2 == 0
                ? currentIndex + 1
                : currentIndex - 1;

            if (siblingIndex < currentLevel.length) {
                proofArray[proofLength] = currentLevel[siblingIndex];
                proofLength++;
            }

            // Move to next level
            bytes32[] memory nextLevel = new bytes32[](
                (currentLevel.length + 1) / 2
            );

            for (uint256 i = 0; i < currentLevel.length; i += 2) {
                bytes32 left = currentLevel[i];
                bytes32 right = i + 1 < currentLevel.length
                    ? currentLevel[i + 1]
                    : bytes32(0);

                nextLevel[i / 2] = _hashPair(left, right);
            }

            currentLevel = nextLevel;
            currentIndex = currentIndex / 2;
        }

        // Create properly sized proof array
        proof = new bytes32[](proofLength);
        for (uint256 i = 0; i < proofLength; i++) {
            proof[i] = proofArray[i];
        }
    }

    /**
     * @notice Hash a pair of bytes32 values in the same way as OpenZeppelin
     */
    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    /**
     * @notice Efficient hash function similar to OpenZeppelin's implementation
     */
    function _efficientHash(
        bytes32 a,
        bytes32 b
    ) internal pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Sort bytes32 array in place
     */
    function _sortBytes32Array(bytes32[] memory arr) internal pure {
        for (uint256 i = 0; i < arr.length; i++) {
            for (uint256 j = i + 1; j < arr.length; j++) {
                if (arr[i] > arr[j]) {
                    bytes32 temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                }
            }
        }
    }

    // ============ Test Setup ============

    function setUp() public {
        // Deploy test tokens using OpenZeppelin ERC20
        usdc = new TestToken("USDC", "USDC");
        projectToken = new TestToken("Project Token", "PT");
        
        vm.prank(owner);
        giveaway = new Giveaway(address(usdc), platformFeeRecipient);

        // Setup balances - give participants USDC and projectOwner enough project tokens
        usdc.mint(participant1, INITIAL_BALANCE);
        usdc.mint(participant2, INITIAL_BALANCE);
        projectToken.mint(projectOwner, GIVEAWAY_TOKENS * 10); // Give enough for multiple giveaways

        // Setup approvals
        vm.prank(participant1);
        usdc.approve(address(giveaway), type(uint256).max);

        vm.prank(participant2);
        usdc.approve(address(giveaway), type(uint256).max);

        vm.prank(projectOwner);
        projectToken.approve(address(giveaway), type(uint256).max);
    }

    // TODO: These tests need to be updated for the new Self.xyz integration
    // The registerPassportVerification function no longer exists
    /*
    function testRegisterPassportVerification() public {
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        assertTrue(giveaway.walletVerified(participant1));

        Giveaway.PassportVerification memory verification = giveaway
            .getVerification(participant1);
        assertEq(verification.nullifier, NULLIFIER_1);
        assertEq(verification.userIdentifier, USER_ID_1);
        assertEq(verification.wallet, participant1);
    }

    function testCannotRegisterTwice() public {
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        vm.prank(participant1);
        vm.expectRevert(Giveaway.WalletAlreadyVerified.selector);
        giveaway.registerPassportVerification(NULLIFIER_2, USER_ID_2);
    }

    function testCannotReuseSameNullifier() public {
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        vm.prank(participant2);
        vm.expectRevert(Giveaway.NullifierAlreadyUsed.selector);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_2);
    }

    function testCannotReuseSameUserIdentifier() public {
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        vm.prank(participant2);
        vm.expectRevert(Giveaway.UserIdentifierAlreadyRegistered.selector);
        giveaway.registerPassportVerification(NULLIFIER_2, USER_ID_1);
    }
    */

    function testCreateGiveaway() public {
        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        Giveaway.GiveawayData memory giveawayData = giveaway.getGiveaway(
            giveawayId
        );
        assertEq(giveawayData.projectOwner, projectOwner);
        assertEq(giveawayData.tokenAddress, address(projectToken));
        assertEq(giveawayData.maxAllocation, MAX_ALLOCATION);
        assertEq(giveawayData.totalTokensForSale, GIVEAWAY_TOKENS);
    }

    function testCreateVerifiedGiveaway() public {
        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        // Verification is always required now
    }

    function testDepositWithoutVerification() public {
        // Create giveaway (verification always required)
        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        // Move to start time
        vm.warp(startTime);

        // Try to deposit without verification (should fail)
        vm.prank(participant1);
        vm.expectRevert(Giveaway.VerificationRequired.selector);
        giveaway.deposit(giveawayId, DEPOSIT_AMOUNT);
    }

    // TODO: This test needs to be updated for the new Self.xyz integration
    /*
    function testDepositWithVerification() public {
        // Register participant first
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        // Create giveaway (verification always required)
        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        // Move to start time
        vm.warp(startTime);

        // Deposit with verification
        vm.prank(participant1);
        giveaway.deposit(giveawayId, DEPOSIT_AMOUNT);

        Giveaway.Participant memory participant = giveaway.getParticipant(
            giveawayId,
            participant1
        );
        assertEq(participant.depositAmount, DEPOSIT_AMOUNT);
        assertEq(participant.userIdentifier, USER_ID_1);
        assertTrue(participant.verified);
    }
    */

    function testCannotDepositWithoutVerificationInVerifiedGiveaway() public {
        // Create giveaway (verification always required)
        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        // Move to start time
        vm.warp(startTime);

        // Try to deposit without verification
        vm.prank(participant1);
        vm.expectRevert(Giveaway.VerificationRequired.selector);
        giveaway.deposit(giveawayId, DEPOSIT_AMOUNT);
    }

    // TODO: This test needs to be updated for the new Self.xyz integration
    /*
    function testFairAllocationUnderAllocatedScenario() public {
        // Register participants first
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        vm.prank(participant2);
        giveaway.registerPassportVerification(NULLIFIER_2, USER_ID_2);

        // Create giveaway: 10K USDC max, but only 5K will be deposited
        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION, // 10K USDC max
            GIVEAWAY_TOKENS, // 100K tokens
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        vm.warp(startTime);

        // Two participants deposit less than max allocation
        vm.prank(participant1);
        giveaway.deposit(giveawayId, 3000e6); // 3K USDC

        vm.prank(participant2);
        giveaway.deposit(giveawayId, 2000e6); // 2K USDC

        // Total: 5K USDC (less than 10K max)

        vm.warp(endTime + 1);
        vm.prank(projectOwner);
        giveaway.finalizeGiveaway(giveawayId);

        // In under-allocated scenario, everyone pays same price per token
        // Token price: 5K USDC / 100K tokens = 0.05 USDC per token
        // Participant1: 3K USDC / 0.05 = 60K tokens
        // Participant2: 2K USDC / 0.05 = 40K tokens

        uint256 allocation1 = calculateTokenAllocationOffChain(
            giveawayId,
            participant1
        );
        uint256 allocation2 = calculateTokenAllocationOffChain(
            giveawayId,
            participant2
        );

        // Should be proportional: 3K/5K and 2K/5K of tokens available for participants (70% of total)
        uint256 tokensForParticipants = (GIVEAWAY_TOKENS * 7000) / 10000; // 70% of total tokens
        assertEq(allocation1, (3000e6 * tokensForParticipants) / 5000e6); // 42K tokens
        assertEq(allocation2, (2000e6 * tokensForParticipants) / 5000e6); // 28K tokens

        // No refunds in under-allocated scenario
        assertEq(calculateRefundOffChain(giveawayId, participant1), 0);
        assertEq(calculateRefundOffChain(giveawayId, participant2), 0);

        // Verify token price (based on tokens available for participants)
        uint256 tokenPrice = giveaway.getTokenPrice(giveawayId);
        assertEq(tokenPrice, (5000e6 * 1e18) / tokensForParticipants); // USDC units per token for participants
    }
    */

    // TODO: This test needs to be updated for the new Self.xyz integration
    /*
    function testFairAllocationOverAllocatedScenario() public {
        // Register 4 participants for a comprehensive test
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        vm.prank(participant2);
        giveaway.registerPassportVerification(NULLIFIER_2, USER_ID_2);

        address participant3 = address(0x6);
        address participant4 = address(0x7);

        vm.prank(participant3);
        giveaway.registerPassportVerification(11111, 22222);

        vm.prank(participant4);
        giveaway.registerPassportVerification(33333, 44444);

        // Give additional participants USDC and approvals
        usdc.mint(participant3, INITIAL_BALANCE);
        usdc.mint(participant4, INITIAL_BALANCE);

        vm.prank(participant3);
        usdc.approve(address(giveaway), type(uint256).max);

        vm.prank(participant4);
        usdc.approve(address(giveaway), type(uint256).max);

        // Create giveaway: 1000 USDC max allocation, 1000 tokens
        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;
        uint256 maxAlloc = 1000e6; // 1000 USDC
        uint256 totalTokens = 1000e18; // 1000 tokens

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            maxAlloc,
            totalTokens,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        vm.warp(startTime);

        // Deposits: A=100, B=200, C=300, D=600 (total=1200 > 1000 max)
        // Average = 1000/4 = 250 USDC per person
        vm.prank(participant1);
        giveaway.deposit(giveawayId, 100e6); // Below average

        vm.prank(participant2);
        giveaway.deposit(giveawayId, 200e6); // Below average

        vm.prank(participant3);
        giveaway.deposit(giveawayId, 300e6); // Above average

        vm.prank(participant4);
        giveaway.deposit(giveawayId, 600e6); // Above average

        vm.warp(endTime + 1);
        vm.prank(projectOwner);
        giveaway.finalizeGiveaway(giveawayId);

        // Verify the algorithm with 70% of tokens available for participants:
        // Total tokens for participants: 700 tokens (70% of 1000)
        // Token price: 1000 USDC / 700 tokens ≈ 1.43 USDC per token
        // Average allocation: 1000/4 = 250 USDC per person

        // Step 1: Initial allocation based on 700 tokens for participants
        // A (100 < 250): gets 100 * (700/1000) = 70 tokens
        // B (200 < 250): gets 200 * (700/1000) = 140 tokens
        // C (300 >= 250): gets 250 * (700/1000) = 175 tokens initially
        // D (600 >= 250): gets 250 * (700/1000) = 175 tokens initially

        // Step 2: Calculate leftover for remaining 140 tokens
        // A's leftover: 175 - 70 = 105 token-worth
        // B's leftover: 175 - 140 = 35 token-worth
        // Total leftover: 140 tokens

        // Step 3: Distribute leftover among above-average contributors
        // C's excess: 300 - 250 = 50 USDC
        // D's excess: 600 - 250 = 350 USDC
        // Total excess: 400 USDC
        // C gets additional: (50/400) * 140 = 17.5 tokens
        // D gets additional: (350/400) * 140 = 122.5 tokens

        uint256 allocation1 = calculateTokenAllocationOffChain(
            giveawayId,
            participant1
        );
        uint256 allocation2 = calculateTokenAllocationOffChain(
            giveawayId,
            participant2
        );
        uint256 allocation3 = calculateTokenAllocationOffChain(
            giveawayId,
            participant3
        );
        uint256 allocation4 = calculateTokenAllocationOffChain(
            giveawayId,
            participant4
        );

        // Expected final allocations (based on 700 tokens for participants):
        assertEq(allocation1, 70e18); // A: 70 tokens (100 * 700/1000)
        assertEq(allocation2, 140e18); // B: 140 tokens (200 * 700/1000)
        assertEq(allocation3, 192500000000000000000); // C: ~192.5 tokens
        assertEq(allocation4, 297500000000000000000); // D: ~297.5 tokens

        // Check refunds
        uint256 refund1 = calculateRefundOffChain(giveawayId, participant1);
        uint256 refund2 = calculateRefundOffChain(giveawayId, participant2);
        uint256 refund3 = calculateRefundOffChain(giveawayId, participant3);
        uint256 refund4 = calculateRefundOffChain(giveawayId, participant4);

        // Expected refunds (should remain proportional):
        assertEq(refund1, 0); // A: 100 - 100 = 0 USDC refund
        assertEq(refund2, 0); // B: 200 - 200 = 0 USDC refund
        assertEq(refund3, 25e6); // C: 300 - 275 = 25 USDC refund
        assertEq(refund4, 175e6); // D: 600 - 425 = 175 USDC refund

        // Verify total tokens distributed equals tokens available for participants
        uint256 expectedParticipantTokens = (totalTokens * 7000) / 10000; // 70% of total
        assertEq(
            allocation1 + allocation2 + allocation3 + allocation4,
            expectedParticipantTokens
        );

        // Verify token price is based on participant tokens (700 tokens for 1000 USDC)
        uint256 tokenPrice = giveaway.getTokenPrice(giveawayId);
        assertEq(tokenPrice, (1000e6 * 1e18) / expectedParticipantTokens); // ~1.43 USDC per token

        // Verify average allocation
        uint256 avgAllocation = giveaway.getAverageAllocation(giveawayId);
        assertEq(avgAllocation, 250e6); // 250 USDC per person
    }
    */

    function testCancelGiveaway() public {
        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        // Cancel before start
        uint256 balanceBefore = projectToken.balanceOf(projectOwner);
        vm.prank(projectOwner);
        giveaway.cancelGiveaway(giveawayId);

        // Tokens should be returned
        uint256 balanceAfter = projectToken.balanceOf(projectOwner);
        assertEq(balanceAfter, balanceBefore + GIVEAWAY_TOKENS);

        // Check cancelled status
        Giveaway.GiveawayData memory giveawayData = giveaway.getGiveaway(
            giveawayId
        );
        assertTrue(giveawayData.cancelled);
    }

    // ============ Merkle Tree Tests ============

    // TODO: This test needs to be updated for the new Self.xyz integration
    /*
    function testSetMerkleRoot() public {
        // Register participants and create giveaway
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        // Participate and finalize
        vm.warp(startTime);
        vm.prank(participant1);
        giveaway.deposit(giveawayId, 5000e6);

        vm.warp(endTime + 1);
        vm.prank(projectOwner);
        giveaway.finalizeGiveaway(giveawayId);

        // Set merkle root
        bytes32 merkleRoot = keccak256("test_merkle_root");
        vm.prank(projectOwner);
        giveaway.setMerkleRoot(giveawayId, merkleRoot);

        // Verify merkle root is set
        (bytes32 root, bool enabled) = giveaway.getMerkleInfo(giveawayId);
        assertEq(root, merkleRoot);
        assertTrue(enabled);
    }
    */

    // TODO: This test needs to be updated for the new Self.xyz integration
    /*
    function testCannotSetMerkleRootTwice() public {
        // Setup giveaway
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        vm.warp(startTime);
        vm.prank(participant1);
        giveaway.deposit(giveawayId, 5000e6);

        vm.warp(endTime + 1);
        vm.prank(projectOwner);
        giveaway.finalizeGiveaway(giveawayId);

        // Set merkle root first time
        bytes32 merkleRoot = keccak256("test_merkle_root");
        vm.prank(projectOwner);
        giveaway.setMerkleRoot(giveawayId, merkleRoot);

        // Try to set again - should fail
        vm.prank(projectOwner);
        vm.expectRevert(Giveaway.MerkleAlreadySet.selector);
        giveaway.setMerkleRoot(giveawayId, keccak256("another_root"));
    }
    */

    // TODO: This test needs to be updated for the new Self.xyz integration
    /*
    function testMerkleClaim() public {
        // Setup giveaway with participants
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        vm.prank(participant2);
        giveaway.registerPassportVerification(NULLIFIER_2, USER_ID_2);

        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        vm.warp(startTime);
        vm.prank(participant1);
        giveaway.deposit(giveawayId, 6000e6);

        vm.prank(participant2);
        giveaway.deposit(giveawayId, 4000e6);

        vm.warp(endTime + 1);
        vm.prank(projectOwner);
        giveaway.finalizeGiveaway(giveawayId);

        // Use off-chain calculation functions for accurate allocations
        uint256 tokenAmount1 = calculateTokenAllocationOffChain(
            giveawayId,
            participant1
        );
        uint256 tokenAmount2 = calculateTokenAllocationOffChain(
            giveawayId,
            participant2
        );
        uint256 refundAmount1 = calculateRefundOffChain(
            giveawayId,
            participant1
        );
        uint256 refundAmount2 = calculateRefundOffChain(
            giveawayId,
            participant2
        );

        // Create proper merkle tree with OpenZeppelin compatibility
        bytes32 leaf1 = keccak256(
            abi.encodePacked(
                uint256(0),
                participant1,
                tokenAmount1,
                refundAmount1
            )
        );
        bytes32 leaf2 = keccak256(
            abi.encodePacked(
                uint256(1),
                participant2,
                tokenAmount2,
                refundAmount2
            )
        );

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = leaf1;
        leaves[1] = leaf2;

        bytes32 merkleRoot = createMerkleTree(leaves);
        bytes32[] memory proof1 = generateMerkleProof(leaves, leaf1);

        // Set merkle root
        vm.prank(projectOwner);
        giveaway.setMerkleRoot(giveawayId, merkleRoot);

        // Claim via merkle proof
        uint256 balanceBefore = projectToken.balanceOf(participant1);
        vm.prank(participant1);
        giveaway.merkleClaim(
            giveawayId,
            0,
            participant1,
            tokenAmount1,
            refundAmount1,
            proof1
        );

        uint256 balanceAfter = projectToken.balanceOf(participant1);
        assertEq(balanceAfter - balanceBefore, tokenAmount1);

        // Check claim status
        assertTrue(giveaway.isMerkleClaimed(giveawayId, 0));
        assertFalse(giveaway.isMerkleClaimed(giveawayId, 1));
    }
    */

    // TODO: This test needs to be updated for the new Self.xyz integration
    /*
    function testCannotClaimMerkleTwice() public {
        // Setup similar to testMerkleClaim
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        vm.warp(startTime);
        vm.prank(participant1);
        giveaway.deposit(giveawayId, 5000e6);

        vm.warp(endTime + 1);
        vm.prank(projectOwner);
        giveaway.finalizeGiveaway(giveawayId);

        // Use off-chain calculation functions
        uint256 tokenAmount = calculateTokenAllocationOffChain(
            giveawayId,
            participant1
        );
        uint256 refundAmount = calculateRefundOffChain(
            giveawayId,
            participant1
        );

        // Single-leaf merkle tree
        bytes32 leaf = keccak256(
            abi.encodePacked(
                uint256(0),
                participant1,
                tokenAmount,
                refundAmount
            )
        );

        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;

        bytes32 merkleRoot = createMerkleTree(leaves);
        bytes32[] memory proof = generateMerkleProof(leaves, leaf);

        vm.prank(projectOwner);
        giveaway.setMerkleRoot(giveawayId, merkleRoot);

        // First claim - should succeed
        vm.prank(participant1);
        giveaway.merkleClaim(
            giveawayId,
            0,
            participant1,
            tokenAmount,
            refundAmount,
            proof
        );

        // Second claim - should fail
        vm.prank(participant1);
        vm.expectRevert(Giveaway.MerkleAlreadyClaimed.selector);
        giveaway.merkleClaim(
            giveawayId,
            0,
            participant1,
            tokenAmount,
            refundAmount,
            proof
        );
    }
    */

    // TODO: This test needs to be updated for the new Self.xyz integration
    /*
    function testCannotClaimWithoutMerkleEnabled() public {
        // Setup finalized giveaway without merkle
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        vm.warp(startTime);
        vm.prank(participant1);
        giveaway.deposit(giveawayId, 5000e6);

        vm.warp(endTime + 1);
        vm.prank(projectOwner);
        giveaway.finalizeGiveaway(giveawayId);

        // Try to claim without setting merkle root
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(participant1);
        vm.expectRevert(Giveaway.MerkleNotEnabled.selector);
        giveaway.merkleClaim(giveawayId, 0, participant1, 1000e18, 0, proof);
    }
    */

    // TODO: This test needs to be updated for the new Self.xyz integration
    /*
    function testBatchMerkleClaim() public {
        // Setup giveaway with two participants
        vm.prank(participant1);
        giveaway.registerPassportVerification(NULLIFIER_1, USER_ID_1);

        vm.prank(participant2);
        giveaway.registerPassportVerification(NULLIFIER_2, USER_ID_2);

        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + 3600;

        vm.prank(projectOwner);
        uint256 giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        vm.warp(startTime);
        vm.prank(participant1);
        giveaway.deposit(giveawayId, 6000e6);

        vm.prank(participant2);
        giveaway.deposit(giveawayId, 4000e6);

        vm.warp(endTime + 1);
        vm.prank(projectOwner);
        giveaway.finalizeGiveaway(giveawayId);

        // Use off-chain calculation functions for accurate allocations
        uint256 tokenAmount1 = calculateTokenAllocationOffChain(
            giveawayId,
            participant1
        );
        uint256 tokenAmount2 = calculateTokenAllocationOffChain(
            giveawayId,
            participant2
        );
        uint256 refundAmount1 = calculateRefundOffChain(
            giveawayId,
            participant1
        );
        uint256 refundAmount2 = calculateRefundOffChain(
            giveawayId,
            participant2
        );

        // Create proper merkle tree with OpenZeppelin compatibility
        bytes32 leaf1 = keccak256(
            abi.encodePacked(
                uint256(0),
                participant1,
                tokenAmount1,
                refundAmount1
            )
        );
        bytes32 leaf2 = keccak256(
            abi.encodePacked(
                uint256(1),
                participant2,
                tokenAmount2,
                refundAmount2
            )
        );

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = leaf1;
        leaves[1] = leaf2;

        bytes32 merkleRoot = createMerkleTree(leaves);
        bytes32[] memory proof1 = generateMerkleProof(leaves, leaf1);
        bytes32[] memory proof2 = generateMerkleProof(leaves, leaf2);

        vm.prank(projectOwner);
        giveaway.setMerkleRoot(giveawayId, merkleRoot);

        // Prepare batch claim data
        uint256[] memory claimIndices = new uint256[](2);
        claimIndices[0] = 0;
        claimIndices[1] = 1;

        address[] memory claimants = new address[](2);
        claimants[0] = participant1;
        claimants[1] = participant2;

        uint256[] memory tokenAmounts = new uint256[](2);
        tokenAmounts[0] = tokenAmount1;
        tokenAmounts[1] = tokenAmount2;

        uint256[] memory refundAmounts = new uint256[](2);
        refundAmounts[0] = refundAmount1;
        refundAmounts[1] = refundAmount2;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = proof1;
        proofs[1] = proof2;

        // Execute batch claim
        uint256 balance1Before = projectToken.balanceOf(participant1);
        uint256 balance2Before = projectToken.balanceOf(participant2);

        giveaway.batchMerkleClaim(
            giveawayId,
            claimIndices,
            claimants,
            tokenAmounts,
            refundAmounts,
            proofs
        );

        uint256 balance1After = projectToken.balanceOf(participant1);
        uint256 balance2After = projectToken.balanceOf(participant2);

        assertEq(balance1After - balance1Before, tokenAmount1);
        assertEq(balance2After - balance2Before, tokenAmount2);

        // Check both claims are marked as claimed
        assertTrue(giveaway.isMerkleClaimed(giveawayId, 0));
        assertTrue(giveaway.isMerkleClaimed(giveawayId, 1));
    }
    */

    // ============ OFF-CHAIN CALCULATION HELPER FUNCTIONS ============
    // These replicate the JavaScript logic from MerkleTreeUtils.js for testing

    function calculateTokenAllocationOffChain(
        uint256 giveawayId,
        address participant
    ) internal view returns (uint256 tokenAmount) {
        Giveaway.GiveawayData memory giveawayData = giveaway.getGiveaway(
            giveawayId
        );
        Giveaway.Participant memory p = giveaway.getParticipant(
            giveawayId,
            participant
        );

        if (p.depositAmount == 0) return 0;

        // Calculate tokens available for participants (excluding dev and liquidity allocations)
        uint256 tokensForParticipants = giveawayData.totalTokensForSale -
            (giveawayData.totalTokensForSale * giveawayData.devPercentage) /
            10000 -
            (giveawayData.totalTokensForSale *
                giveawayData.liquidityPercentage) /
            10000;

        // Under-allocated scenario: simple proportional allocation
        if (giveawayData.totalDeposited <= giveawayData.maxAllocation) {
            // Everyone pays same price per token
            tokenAmount =
                (p.depositAmount * tokensForParticipants) /
                giveawayData.totalDeposited;
            return tokenAmount;
        }

        // Over-allocated scenario: fair allocation algorithm
        uint256 avgAllocation = giveawayData.maxAllocation /
            giveawayData.participantCount;

        if (p.depositAmount < avgAllocation) {
            // Person contributed less than average: gets tokens for what they paid
            tokenAmount =
                (p.depositAmount * tokensForParticipants) /
                giveawayData.maxAllocation;
        } else {
            // Person contributed more than average: gets average allocation + share of leftover
            uint256 baseAllocation = (avgAllocation * tokensForParticipants) /
                giveawayData.maxAllocation;

            // Calculate global leftover and excess (simplified for demo)
            (
                uint256 totalLeftoverFunds,
                uint256 totalExcessFunds
            ) = calculateGlobalValuesHelper(giveawayId);

            if (totalExcessFunds > 0) {
                uint256 participantExcess = p.depositAmount - avgAllocation;
                uint256 additionalAllocation = (participantExcess *
                    totalLeftoverFunds *
                    tokensForParticipants) /
                    (totalExcessFunds * giveawayData.maxAllocation);
                tokenAmount = baseAllocation + additionalAllocation;
            } else {
                tokenAmount = baseAllocation;
            }
        }
    }

    function calculateRefundOffChain(
        uint256 giveawayId,
        address participant
    ) internal view returns (uint256 refundAmount) {
        Giveaway.GiveawayData memory giveawayData = giveaway.getGiveaway(
            giveawayId
        );
        Giveaway.Participant memory p = giveaway.getParticipant(
            giveawayId,
            participant
        );

        if (
            giveawayData.totalDeposited <= giveawayData.maxAllocation ||
            p.depositAmount == 0
        ) {
            return 0;
        }

        // Calculate how much USDC was used for tokens
        uint256 tokenAmount = calculateTokenAllocationOffChain(
            giveawayId,
            participant
        );

        // Calculate tokens available for participants (excluding dev and liquidity allocations)
        uint256 tokensForParticipants = giveawayData.totalTokensForSale -
            (giveawayData.totalTokensForSale * giveawayData.devPercentage) /
            10000 -
            (giveawayData.totalTokensForSale *
                giveawayData.liquidityPercentage) /
            10000;

        uint256 usedAmount = (tokenAmount * giveawayData.maxAllocation) /
            tokensForParticipants;

        // Refund is the difference
        refundAmount = p.depositAmount - usedAmount;
    }

    function calculateGlobalValuesHelper(
        uint256 giveawayId
    )
        internal
        view
        returns (uint256 totalLeftoverFunds, uint256 totalExcessFunds)
    {
        Giveaway.GiveawayData memory giveawayData = giveaway.getGiveaway(
            giveawayId
        );
        uint256 avgAllocation = giveawayData.maxAllocation /
            giveawayData.participantCount;

        address[] memory participants = giveaway.getGiveawayParticipants(
            giveawayId
        );

        for (uint256 i = 0; i < participants.length; i++) {
            Giveaway.Participant memory p = giveaway.getParticipant(
                giveawayId,
                participants[i]
            );

            if (p.depositAmount < avgAllocation) {
                // Leftover from participants who contributed less than average
                totalLeftoverFunds += avgAllocation - p.depositAmount;
            } else {
                // Excess from participants who contributed more than average
                totalExcessFunds += p.depositAmount - avgAllocation;
            }
        }
    }
}
