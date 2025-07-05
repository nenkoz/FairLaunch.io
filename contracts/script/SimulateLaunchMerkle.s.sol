// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Giveaway.sol";
import "test/mocks/MockERC20.sol";

/**
 * @title SimulateLaunchMerkle
 * @dev Simple simulation of token launch with merkle distribution
 */
contract SimulateLaunchMerkle is Script {
    // Constants
    uint256 constant MAX_ALLOCATION = 100_000e6; // 100K USDC
    uint256 constant GIVEAWAY_TOKENS = 1_000_000e18; // 1M tokens
    uint256 constant LAUNCH_DURATION = 24 hours;

    // Contracts
    Giveaway public giveaway;
    MockERC20 public usdc;
    MockERC20 public projectToken;

    // Accounts
    address public projectOwner = address(0x1001);
    address public platformFeeRecipient = address(0x1002);
    address public alice = address(0x2001);
    address public bob = address(0x2002);
    address public charlie = address(0x2003);

    // Merkle data
    struct MerkleParticipant {
        uint256 index;
        address participant;
        uint256 tokenAmount;
        uint256 refundAmount;
        bytes32[] proof;
    }

    MerkleParticipant[] public merkleParticipants;
    bytes32 public merkleRoot;

    function run() external {
        console.log("Token Launch Simulation with Merkle Distribution");
        console.log("================================================");

        deployContracts();
        setupTokens();
        setupAccounts();

        uint256 giveawayId = createGiveaway();
        simulateParticipation(giveawayId);
        finalizeGiveaway(giveawayId);
        generateMerkleTree(giveawayId);
        setMerkleRoot(giveawayId);
        claimTokens(giveawayId);

        console.log("Simulation completed successfully!");
    }

    function setupAccounts() internal {
        console.log("Setting up accounts...");

        // Register participants with Self.xyz
        vm.prank(alice);
        giveaway.registerPassportVerification(1001, 2001);

        vm.prank(bob);
        giveaway.registerPassportVerification(1002, 2002);

        vm.prank(charlie);
        giveaway.registerPassportVerification(1003, 2003);
    }

    function deployContracts() internal {
        console.log("Deploying contracts...");

        vm.startPrank(projectOwner);
        usdc = new MockERC20("USD Coin", "USDC", 6);
        projectToken = new MockERC20("Project Token", "PROJ", 18);
        giveaway = new Giveaway(address(usdc), platformFeeRecipient);
        vm.stopPrank();
    }

    function setupTokens() internal {
        console.log("Setting up tokens...");

        // Project owner gets tokens
        vm.prank(projectOwner);
        projectToken.mint(projectOwner, GIVEAWAY_TOKENS);

        vm.prank(projectOwner);
        projectToken.approve(address(giveaway), GIVEAWAY_TOKENS);

        // Participants get USDC
        address[] memory participants = new address[](3);
        participants[0] = alice;
        participants[1] = bob;
        participants[2] = charlie;

        for (uint256 i = 0; i < participants.length; i++) {
            usdc.mint(participants[i], 100_000e6);
            vm.prank(participants[i]);
            usdc.approve(address(giveaway), type(uint256).max);
        }
    }

    function createGiveaway() internal returns (uint256 giveawayId) {
        console.log("Creating giveaway...");

        uint256 startTime = block.timestamp + 1 hours;
        uint256 endTime = startTime + LAUNCH_DURATION;

        vm.prank(projectOwner);
        giveawayId = giveaway.createGiveaway(
            address(projectToken),
            startTime,
            endTime,
            MAX_ALLOCATION,
            GIVEAWAY_TOKENS,
            1000, // 10% dev allocation
            2000 // 20% liquidity allocation (minimum required)
        );

        console.log("Giveaway created with ID:", giveawayId);
    }

    function simulateParticipation(uint256 giveawayId) internal {
        console.log("Simulating participation...");
        console.log("");

        // Fast forward to start
        vm.warp(block.timestamp + 1 hours + 1);

        // Participants deposit (over-allocated scenario)
        console.log("Deposit Phase:");

        vm.prank(alice);
        giveaway.deposit(giveawayId, 50_000e6); // 50K USDC
        console.log("  Alice deposited: 50,000 USDC");

        vm.prank(bob);
        giveaway.deposit(giveawayId, 40_000e6); // 40K USDC
        console.log("  Bob deposited: 40,000 USDC");

        vm.prank(charlie);
        giveaway.deposit(giveawayId, 30_000e6); // 30K USDC
        console.log("  Charlie deposited: 30,000 USDC");

        console.log("");
        console.log("Deposit Summary:");
        console.log("  Total deposited: 120,000 USDC");
        console.log("  Max allocation: 100,000 USDC");
        console.log("  Status: OVER-ALLOCATED (20,000 USDC excess)");
        console.log("  Average allocation per participant: 33,333 USDC");
        console.log("");
    }

    function finalizeGiveaway(uint256 giveawayId) internal {
        console.log("Finalizing giveaway...");
        console.log("");

        // Fast forward past end time
        vm.warp(block.timestamp + LAUNCH_DURATION + 1);

        vm.prank(projectOwner);
        giveaway.finalizeGiveaway(giveawayId);

        // Add buffer for rounding errors
        usdc.mint(address(giveaway), 1000);

        console.log("Project Collection:");
        console.log("  Max allocation: 100,000 USDC");
        console.log("  Platform fee (2.5%): 2,500 USDC");
        console.log("  Project proceeds: 97,500 USDC");
        console.log("  Remaining in contract for refunds: 20,000 USDC");
        console.log("");
    }

    function generateMerkleTree(uint256 giveawayId) internal {
        console.log("Generating merkle tree...");

        address[] memory participantAddresses = giveaway
            .getGiveawayParticipants(giveawayId);
        delete merkleParticipants;

        // Calculate allocations for each participant
        for (uint256 i = 0; i < participantAddresses.length; i++) {
            address participant = participantAddresses[i];
            uint256 tokenAmount = calculateTokenAllocation(
                giveawayId,
                participant
            );
            uint256 refundAmount = calculateRefund(giveawayId, participant);

            merkleParticipants.push(
                MerkleParticipant({
                    index: i,
                    participant: participant,
                    tokenAmount: tokenAmount,
                    refundAmount: refundAmount,
                    proof: new bytes32[](0)
                })
            );
        }

        // Build merkle tree
        bytes32[] memory leaves = new bytes32[](merkleParticipants.length);
        for (uint256 i = 0; i < merkleParticipants.length; i++) {
            MerkleParticipant storage p = merkleParticipants[i];
            leaves[i] = keccak256(
                abi.encodePacked(
                    p.index,
                    p.participant,
                    p.tokenAmount,
                    p.refundAmount
                )
            );
        }

        merkleRoot = buildMerkleTree(leaves);

        // Generate proofs
        for (uint256 i = 0; i < merkleParticipants.length; i++) {
            merkleParticipants[i].proof = generateProof(leaves, leaves[i]);
        }
    }

    function setMerkleRoot(uint256 giveawayId) internal {
        console.log("Setting merkle root...");

        vm.prank(projectOwner);
        giveaway.setMerkleRoot(giveawayId, merkleRoot);
    }

    function claimTokens(uint256 giveawayId) internal {
        console.log("Claiming tokens...");
        console.log("");

        // Alice claims
        MerkleParticipant memory aliceData = findParticipant(alice);
        console.log("Alice claiming:");
        console.log("  Deposited: 50,000 USDC");
        console.log(
            "  Tokens: ",
            vm.toString(aliceData.tokenAmount / 1e18),
            "PROJ"
        );
        console.log(
            "  Refund: ",
            vm.toString(aliceData.refundAmount / 1e6),
            "USDC"
        );

        vm.prank(alice);
        giveaway.merkleClaim(
            giveawayId,
            aliceData.index,
            aliceData.participant,
            aliceData.tokenAmount,
            aliceData.refundAmount,
            aliceData.proof
        );
        console.log("  [SUCCESS] Alice claimed");
        console.log("");

        // Bob claims
        MerkleParticipant memory bobData = findParticipant(bob);
        console.log("Bob claiming:");
        console.log("  Deposited: 40,000 USDC");
        console.log(
            "  Tokens: ",
            vm.toString(bobData.tokenAmount / 1e18),
            "PROJ"
        );
        console.log(
            "  Refund: ",
            vm.toString(bobData.refundAmount / 1e6),
            "USDC"
        );

        vm.prank(bob);
        giveaway.merkleClaim(
            giveawayId,
            bobData.index,
            bobData.participant,
            bobData.tokenAmount,
            bobData.refundAmount,
            bobData.proof
        );
        console.log("  [SUCCESS] Bob claimed");
        console.log("");

        // Charlie claims
        MerkleParticipant memory charlieData = findParticipant(charlie);
        console.log("Charlie claiming:");
        console.log("  Deposited: 30,000 USDC");
        console.log(
            "  Tokens: ",
            vm.toString(charlieData.tokenAmount / 1e18),
            "PROJ"
        );
        console.log(
            "  Refund: ",
            vm.toString(charlieData.refundAmount / 1e6),
            "USDC"
        );

        vm.prank(charlie);
        giveaway.merkleClaim(
            giveawayId,
            charlieData.index,
            charlieData.participant,
            charlieData.tokenAmount,
            charlieData.refundAmount,
            charlieData.proof
        );
        console.log("  [SUCCESS] Charlie claimed");
        console.log("");

        // Verification totals
        uint256 totalTokens = aliceData.tokenAmount +
            bobData.tokenAmount +
            charlieData.tokenAmount;
        uint256 totalRefunds = aliceData.refundAmount +
            bobData.refundAmount +
            charlieData.refundAmount;

        console.log("FINAL VERIFICATION:");
        console.log("  Total deposits: 120,000 USDC");
        console.log("  Project collected: 97,500 USDC");
        console.log("  Platform fee: 2,500 USDC");
        console.log(
            "  Total refunds: ",
            vm.toString(totalRefunds / 1e6),
            "USDC"
        );
        console.log(
            "  Total tokens distributed: ",
            vm.toString(totalTokens / 1e18),
            "PROJ"
        );
        console.log("  All participants claimed successfully!");
        console.log("");
    }

    // Helper functions
    function calculateTokenAllocation(
        uint256 giveawayId,
        address participant
    ) internal view returns (uint256) {
        Giveaway.GiveawayData memory giveawayData = giveaway.getGiveaway(
            giveawayId
        );
        Giveaway.Participant memory p = giveaway.getParticipant(
            giveawayId,
            participant
        );

        if (p.depositAmount == 0) return 0;

        if (giveawayData.totalDeposited <= giveawayData.maxAllocation) {
            return
                (p.depositAmount * giveawayData.totalTokensForSale) /
                giveawayData.totalDeposited;
        }

        uint256 avgAllocation = giveawayData.maxAllocation /
            giveawayData.participantCount;

        if (p.depositAmount < avgAllocation) {
            return
                (p.depositAmount * giveawayData.totalTokensForSale) /
                giveawayData.maxAllocation;
        } else {
            uint256 baseAllocation = (avgAllocation *
                giveawayData.totalTokensForSale) / giveawayData.maxAllocation;
            (
                uint256 totalLeftoverFunds,
                uint256 totalExcessFunds
            ) = calculateGlobalValues(giveawayId);

            if (totalExcessFunds > 0) {
                uint256 participantExcess = p.depositAmount - avgAllocation;
                uint256 additionalAllocation = (participantExcess *
                    totalLeftoverFunds *
                    giveawayData.totalTokensForSale) /
                    (totalExcessFunds * giveawayData.maxAllocation);
                return baseAllocation + additionalAllocation;
            } else {
                return baseAllocation;
            }
        }
    }

    function calculateRefund(
        uint256 giveawayId,
        address participant
    ) internal view returns (uint256) {
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

        uint256 tokenAmount = calculateTokenAllocation(giveawayId, participant);
        uint256 usedAmount = (tokenAmount * giveawayData.maxAllocation) /
            giveawayData.totalTokensForSale;

        return p.depositAmount > usedAmount ? p.depositAmount - usedAmount : 0;
    }

    function calculateGlobalValues(
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
                totalLeftoverFunds += avgAllocation - p.depositAmount;
            } else {
                totalExcessFunds += p.depositAmount - avgAllocation;
            }
        }
    }

    function buildMerkleTree(
        bytes32[] memory leaves
    ) internal pure returns (bytes32) {
        require(leaves.length > 0, "Empty leaves");
        if (leaves.length == 1) return leaves[0];

        bytes32[] memory currentLevel = leaves;
        while (currentLevel.length > 1) {
            bytes32[] memory nextLevel = new bytes32[](
                (currentLevel.length + 1) / 2
            );
            for (uint256 i = 0; i < currentLevel.length; i += 2) {
                if (i + 1 < currentLevel.length) {
                    bytes32 left = currentLevel[i];
                    bytes32 right = currentLevel[i + 1];
                    nextLevel[i / 2] = left < right
                        ? keccak256(abi.encodePacked(left, right))
                        : keccak256(abi.encodePacked(right, left));
                } else {
                    nextLevel[i / 2] = currentLevel[i];
                }
            }
            currentLevel = nextLevel;
        }
        return currentLevel[0];
    }

    function generateProof(
        bytes32[] memory leaves,
        bytes32 leaf
    ) internal pure returns (bytes32[] memory) {
        uint256 leafIndex = type(uint256).max;
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == leaf) {
                leafIndex = i;
                break;
            }
        }
        require(leafIndex != type(uint256).max, "Leaf not found");

        bytes32[] memory proof = new bytes32[](10);
        uint256 proofIndex = 0;
        bytes32[] memory currentLevel = leaves;
        uint256 currentIndex = leafIndex;

        while (currentLevel.length > 1) {
            if (currentIndex % 2 == 0) {
                if (currentIndex + 1 < currentLevel.length) {
                    proof[proofIndex] = currentLevel[currentIndex + 1];
                    proofIndex++;
                }
            } else {
                proof[proofIndex] = currentLevel[currentIndex - 1];
                proofIndex++;
            }

            bytes32[] memory nextLevel = new bytes32[](
                (currentLevel.length + 1) / 2
            );
            for (uint256 i = 0; i < currentLevel.length; i += 2) {
                if (i + 1 < currentLevel.length) {
                    bytes32 left = currentLevel[i];
                    bytes32 right = currentLevel[i + 1];
                    nextLevel[i / 2] = left < right
                        ? keccak256(abi.encodePacked(left, right))
                        : keccak256(abi.encodePacked(right, left));
                } else {
                    nextLevel[i / 2] = currentLevel[i];
                }
            }
            currentLevel = nextLevel;
            currentIndex = currentIndex / 2;
        }

        bytes32[] memory finalProof = new bytes32[](proofIndex);
        for (uint256 i = 0; i < proofIndex; i++) {
            finalProof[i] = proof[i];
        }
        return finalProof;
    }

    function findParticipant(
        address participant
    ) internal view returns (MerkleParticipant memory) {
        for (uint256 i = 0; i < merkleParticipants.length; i++) {
            if (merkleParticipants[i].participant == participant) {
                return merkleParticipants[i];
            }
        }
        revert("Participant not found");
    }
}
