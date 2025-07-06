// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

// Uniswap V3 interfaces (simplified for this implementation)
interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(
        MintParams calldata params
    )
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
}

interface IUniswapV3Factory {
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);
}

interface IUniswapV3Pool {
    function initialize(uint160 sqrtPriceX96) external;
}



/**
 * @title Giveaway
 * @dev Smart contract for managing token giveaways with Self.xyz passport verification
 * @notice This contract manages USDC deposits, fair distribution, and Self.xyz Sybil resistance
 */
contract Giveaway is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    /// @notice USDC token contract address
    IERC20 public immutable USDC;

    /// @notice Uniswap V2 Router contract address (for liquidity deployment)
    address public constant UNISWAP_V2_ROUTER =
        0x0000000000000000000000000000000000000000; // Set actual router address in deployment

    /// @notice Uniswap V2 Factory contract address (for liquidity deployment)
    address public constant UNISWAP_V2_FACTORY =
        0x0000000000000000000000000000000000000000; // Set actual factory address in deployment

    /// @notice Uniswap V3 NonfungiblePositionManager contract address
    // address public constant UNISWAP_V3_POSITION_MANAGER =
    //     0x3d79EdAaBC0EaB6F08ED885C05Fc0B014290D95A;
    address public constant UNISWAP_V3_POSITION_MANAGER =
        0xB00B8C3aB078EB0f7DeC6cE19c1a1da5bf4f8d7e;

    /// @notice Uniswap V3 Factory contract address
    // address public constant UNISWAP_V3_FACTORY =
    //     0xAfE208a311B21f13EF87E33A90049fC17A7acDEc;
    address public constant UNISWAP_V3_FACTORY =
        0x229Fd76DA9062C1a10eb4193768E192bdEA99572; // testnet

    /// @notice Default fee tier for Uniswap V3 pools (0.3% = 3000)
    uint24 public constant DEFAULT_V3_FEE_TIER = 3000;

    /// @notice Default lower tick for full-range Uniswap V3 positions
    int24 public constant DEFAULT_V3_TICK_LOWER = -887272;

    /// @notice Default upper tick for full-range Uniswap V3 positions
    int24 public constant DEFAULT_V3_TICK_UPPER = 887272;

    /// @notice Standard token decimals (18 decimals is the ERC20 standard)
    uint8 public constant TOKEN_DECIMALS = 18;

    /// @notice USDC decimals (6 decimals)
    uint8 public constant USDC_DECIMALS = 6;

    /// @notice Platform fee percentage (in basis points, e.g., 250 = 2.5%)
    uint256 public constant PLATFORM_FEE = 250;

    /// @notice Platform fee recipient
    address public immutable platformFeeRecipient;

    /// @notice Giveaway counter for unique giveaway IDs
    uint256 public giveawayCounter;

    // Professional allocation limits
    /// @notice Minimum liquidity percentage for healthy trading (20%)
    uint256 public constant MIN_LIQUIDITY_PERCENTAGE = 2000; // 20% in basis points

    /// @notice Maximum combined dev + liquidity percentage (70%)
    uint256 public constant MAX_COMBINED_PERCENTAGE = 7000; // 70% in basis points

    // ============ Self.xyz Integration Mappings ============

    /// @notice Maps nullifiers to user identifiers (prevents same passport registering twice)
    mapping(uint256 => uint256) internal _nullifierToUserIdentifier;

    /// @notice Maps user identifiers to registration status
    mapping(uint256 => bool) internal _registeredUserIdentifiers;

    /// @notice Maps wallet to passport verification status
    mapping(address => bool) public walletVerified;

    // ============ Structs ============

    struct GiveawayData {
        address projectOwner; // Project owner address
        address tokenAddress; // Token being given away
        uint256 startTime; // Giveaway start timestamp
        uint256 endTime; // Giveaway end timestamp
        uint256 maxAllocation; // Maximum USDC allocation
        uint256 totalTokensForSale; // Total tokens available for giveaway
        uint256 totalDeposited; // Total USDC deposited
        uint256 participantCount; // Number of unique participants
        bool finalized; // Whether giveaway has been finalized
        bool cancelled; // Whether giveaway has been cancelled
        bytes32 merkleRoot; // Merkle root for gas-efficient distribution
        bool merkleEnabled; // Whether merkle tree distribution is enabled
        uint256 devPercentage; // Percentage of tokens for developer (in basis points, e.g., 1000 = 10%)
        uint256 devTokensClaimed; // Amount of dev tokens claimed
        bool devTokensAllocated; // Whether dev tokens have been allocated
        uint256 liquidityPercentage; // Percentage of tokens for liquidity pool (in basis points, e.g., 3000 = 30%)
        uint256 liquidityTokensClaimed; // Amount of liquidity tokens claimed
        bool liquidityTokensAllocated; // Whether liquidity tokens have been allocated
        bool liquidityDeployed; // Whether liquidity has been deployed
    }

    struct Participant {
        uint256 depositAmount; // USDC deposited by participant
        uint256 userIdentifier; // Self.xyz user identifier
        bool verified; // Whether participant completed Self.xyz verification
    }

    struct PassportVerification {
        uint256 nullifier; // Self.xyz nullifier (prevents duplicate passport use)
        uint256 userIdentifier; // Self.xyz user identifier
        address wallet; // Wallet address
        uint256 timestamp; // Verification timestamp
    }

    // ============ Mappings ============

    /// @notice Giveaway ID to Giveaway details
    mapping(uint256 => GiveawayData) public giveaways;

    /// @notice Giveaway ID => participant address => participant details
    mapping(uint256 => mapping(address => Participant)) public participants;

    /// @notice Giveaway ID => array of participant addresses
    mapping(uint256 => address[]) public giveawayParticipants;

    /// @notice Verification records for transparency
    mapping(address => PassportVerification) public verifications;

    /// @notice Merkle claim tracking: giveawayId => claimIndex => claimed status
    mapping(uint256 => mapping(uint256 => bool)) public merkleClaimed;

    // ============ Events ============

    event LiquidityDeployed(
        uint256 indexed giveawayId,
        address indexed poolAddress,
        uint256 amountToken,
        uint256 amountUSDC
    );

    event GiveawayCreated(
        uint256 indexed giveawayId,
        address indexed projectOwner,
        address indexed tokenAddress,
        uint256 startTime,
        uint256 endTime,
        uint256 maxAllocation,
        uint256 totalTokensForSale,
        uint256 devPercentage,
        uint256 liquidityPercentage
    );

    event PassportVerified(
        address indexed wallet,
        uint256 indexed userIdentifier,
        uint256 nullifier,
        uint256 timestamp
    );

    event Deposit(
        uint256 indexed giveawayId,
        address indexed participant,
        uint256 amount,
        bool verified
    );

    event GiveawayFinalized(
        uint256 indexed giveawayId,
        uint256 totalDeposited,
        uint256 participantCount,
        uint256 devTokensAllocated,
        uint256 liquidityTokensAllocated
    );

    event GiveawayCancelled(uint256 indexed giveawayId);

    event MerkleRootSet(uint256 indexed giveawayId, bytes32 merkleRoot);

    event MerkleTokensClaimed(
        uint256 indexed giveawayId,
        uint256 indexed claimIndex,
        address indexed participant,
        uint256 tokenAmount,
        uint256 refundAmount
    );

    event DevTokensClaimed(
        uint256 indexed giveawayId,
        address indexed projectOwner,
        uint256 tokenAmount
    );

    event LiquidityTokensClaimed(
        uint256 indexed giveawayId,
        address indexed projectOwner,
        uint256 tokenAmount
    );

    // ============ Errors ============

    error GiveawayNotFound();
    error GiveawayNotActive();
    error GiveawayAlreadyFinalized();
    error GiveawayNotFinalized();
    error InvalidTimeRange();
    error InvalidAllocation();
    error UnauthorizedAccess();
    error SybilDetected();
    error AlreadyParticipated();
    error InsufficientDeposit();
    error TransferFailed();

    error GiveawayAlreadyCancelled();

    // Self.xyz specific errors
    error VerificationRequired();
    error InvalidNullifier();
    error InvalidUserIdentifier();
    error NullifierAlreadyUsed();
    error UserIdentifierAlreadyRegistered();
    error WalletAlreadyVerified();

    // Merkle tree specific errors
    error MerkleNotEnabled();
    error MerkleAlreadySet();
    error InvalidMerkleProof();
    error MerkleAlreadyClaimed();
    error InvalidMerkleRoot();

    // Dev token specific errors
    error InvalidDevPercentage();
    error DevTokensAlreadyClaimed();
    error DevTokensNotAllocated();

    // Liquidity token specific errors
    error InvalidLiquidityPercentage();
    error LiquidityTokensAlreadyClaimed();
    error LiquidityTokensNotAllocated();
    error InvalidAllocationSum();
    error LiquidityAlreadyDeployed();

    // ============ Modifiers ============

    modifier validGiveaway(uint256 giveawayId) {
        if (giveawayId >= giveawayCounter) revert GiveawayNotFound();
        _;
    }

    modifier onlyProjectOwner(uint256 giveawayId) {
        if (giveaways[giveawayId].projectOwner != msg.sender)
            revert UnauthorizedAccess();
        _;
    }

    modifier giveawayActive(uint256 giveawayId) {
        GiveawayData memory giveaway = giveaways[giveawayId];
        if (giveaway.cancelled) revert GiveawayAlreadyCancelled();
        if (
            block.timestamp < giveaway.startTime ||
            block.timestamp > giveaway.endTime
        ) {
            revert GiveawayNotActive();
        }
        _;
    }

    modifier giveawayFinalized(uint256 giveawayId) {
        if (!giveaways[giveawayId].finalized) revert GiveawayNotFinalized();
        _;
    }

    modifier requiresVerification(uint256 giveawayId) {
        if (!walletVerified[msg.sender]) {
            revert VerificationRequired();
        }
        _;
    }

     /**
     * @notice Constructor for the Giveaway contract
     * @param _usdc USDC token contract address
     * @param _platformFeeRecipient Platform fee recipient address
     */
    constructor(
        address _usdc,
        address _platformFeeRecipient
    ) Ownable(msg.sender)  {
        USDC = IERC20(_usdc);
        platformFeeRecipient = _platformFeeRecipient;
    }

    // ============ External Functions ============

    /**
     * @notice Create a new token giveaway
     * @param tokenAddress Address of the token being given away
     * @param startTime Giveaway start timestamp
     * @param endTime Giveaway end timestamp
     * @param maxAllocation Maximum USDC allocation for the giveaway
     * @param totalTokensForSale Total tokens available for giveaway
     * @param devPercentage Percentage of tokens for developer (in basis points, e.g., 1000 = 10%)
     * @param liquidityPercentage Percentage of tokens for liquidity pool (in basis points, e.g., 3000 = 30%)
     * @dev Self.xyz verification is always required for all giveaways
     */
    function createGiveaway(
        address tokenAddress,
        uint256 startTime,
        uint256 endTime,
        uint256 maxAllocation,
        uint256 totalTokensForSale,
        uint256 devPercentage,
        uint256 liquidityPercentage
    ) external nonReentrant returns (uint256 giveawayId) {
        if (startTime >= endTime || startTime < block.timestamp)
            revert InvalidTimeRange();
        if (maxAllocation == 0 || totalTokensForSale == 0)
            revert InvalidAllocation();
        if (devPercentage > 10000)
            // Cannot exceed 100%
            revert InvalidDevPercentage();
        if (liquidityPercentage > 10000)
            // Cannot exceed 100%
            revert InvalidLiquidityPercentage();

        // Professional limits enforcement
        if (liquidityPercentage < MIN_LIQUIDITY_PERCENTAGE) {
            revert InvalidLiquidityPercentage(); // Minimum 20% liquidity required for all projects
        }

        // Ensure total allocations don't exceed 70% (professional maximum)
        if (devPercentage + liquidityPercentage > MAX_COMBINED_PERCENTAGE) {
            revert InvalidAllocationSum(); // Maximum 70% combined to ensure fair participant allocation
        }

        // Transfer tokens to contract using SafeERC20
        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            totalTokensForSale
        );

        giveawayId = giveawayCounter++;

        giveaways[giveawayId] = GiveawayData({
            projectOwner: msg.sender,
            tokenAddress: tokenAddress,
            startTime: startTime,
            endTime: endTime,
            maxAllocation: maxAllocation,
            totalTokensForSale: totalTokensForSale,
            totalDeposited: 0,
            participantCount: 0,
            finalized: false,
            cancelled: false,
            merkleRoot: 0,
            merkleEnabled: false,
            devPercentage: devPercentage,
            devTokensClaimed: 0,
            devTokensAllocated: false,
            liquidityPercentage: liquidityPercentage,
            liquidityTokensClaimed: 0,
            liquidityTokensAllocated: false,
            liquidityDeployed: false
        });

        emit GiveawayCreated(
            giveawayId,
            msg.sender,
            tokenAddress,
            startTime,
            endTime,
            maxAllocation,
            totalTokensForSale,
            devPercentage,
            liquidityPercentage
        );
    }

    /**
     * @notice Deposit USDC to participate in a giveaway
     * @param giveawayId ID of the giveaway
     * @param amount Amount of USDC to deposit
     */
    function deposit(
        uint256 giveawayId,
        uint256 amount
    )
        external
        nonReentrant
        validGiveaway(giveawayId)
        giveawayActive(giveawayId)
        requiresVerification(giveawayId)
    {
        if (amount == 0) revert InsufficientDeposit();

        // Check if user already participated
        if (participants[giveawayId][msg.sender].depositAmount > 0) {
            revert AlreadyParticipated();
        }

        // Get user identifier from verification (always required)
        PassportVerification memory verification = verifications[msg.sender];
        uint256 userIdentifier = verification.userIdentifier;
        bool isVerified = true;

        // Transfer USDC from user using SafeERC20
        USDC.safeTransferFrom(msg.sender, address(this), amount);

        // Record participation
        participants[giveawayId][msg.sender] = Participant({
            depositAmount: amount,
            userIdentifier: userIdentifier,
            verified: isVerified
        });

        // Add to participants list
        giveawayParticipants[giveawayId].push(msg.sender);

        // Update giveaway totals
        giveaways[giveawayId].totalDeposited += amount;
        giveaways[giveawayId].participantCount++;

        emit Deposit(giveawayId, msg.sender, amount, isVerified);
    }

    /**
     * @notice Claim liquidity tokens and automatically deploy to Uniswap V2
     * @param giveawayId ID of the giveaway
     * @param usdcAmount Amount of project USDC to use for liquidity pairing
     */
    function claimAndDeployLiquidity(
        uint256 giveawayId,
        uint256 usdcAmount,
        uint256 tokenAmount
    )
        public
        nonReentrant
        validGiveaway(giveawayId)
        onlyProjectOwner(giveawayId)
        giveawayFinalized(giveawayId)
    {
        // Two steps for adding liquidity:
        // 1. Calculate the amount of liquidity tokens to add
        // 2. Add liquidity to Uniswap V2 using the router interface

        GiveawayData storage giveaway = giveaways[giveawayId];

        // Error handling:
        if (giveaway.liquidityDeployed) revert LiquidityAlreadyDeployed();
        if (usdcAmount == 0) revert("USDC amount must be greater than zero");
        if (tokenAmount == 0) revert("Token amount must be greater than zero");

        // Approvals are required before adding liquidity so that the Uniswap V2 router
        // contract is allowed to transfer the specified amounts of tokens from this contract.
        // Without these approvals, the router would not be able to move the tokens needed
        // to create the liquidity pool.
        IERC20(giveaway.tokenAddress).approve(UNISWAP_V2_ROUTER, tokenAmount);
        USDC.approve(UNISWAP_V2_ROUTER, usdcAmount);

        // Add liquidity to Uniswap V2 using the router interface
        (uint256 amountToken, uint256 amountUSDC, ) = IUniswapV2Router02(
            UNISWAP_V2_ROUTER
        ).addLiquidity(
                giveaway.tokenAddress, // Token A (project token)
                address(USDC), // Token B (USDC)
                tokenAmount, // Amount of token A
                usdcAmount, // Amount of token B
                (tokenAmount * 95) / 100, // Minimum amount of token A (5% slippage)
                (usdcAmount * 95) / 100, // Minimum amount of token B (5% slippage)
                address(0), // LP tokens recipient (burned)
                block.timestamp + 300 // Deadline (5 minutes from now)
            );

        // Get pool address for reference
        address poolAddress = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(
            giveaway.tokenAddress,
            address(USDC)
        );

        // Update state
        giveaway.liquidityDeployed = true;

        emit LiquidityDeployed(
            giveawayId,
            poolAddress,
            amountToken,
            amountUSDC
        );
    }

    /**
     * @notice Claim liquidity tokens and automatically deploy to Uniswap V3
     * @param giveawayId ID of the giveaway
     * @param usdcAmount Amount of project USDC to use for liquidity pairing
     * @param tokenAmount Amount of project tokens to use for liquidity pairing
     * @dev Uses default parameters: 0.3% fee tier, full-range position
     */
    function claimAndDeployLiquidityUniswapV3(
        uint256 giveawayId,
        uint256 usdcAmount,
        uint256 tokenAmount
    )
        private
        validGiveaway(giveawayId)
        onlyProjectOwner(giveawayId)
        giveawayFinalized(giveawayId)
    {
        GiveawayData storage giveaway = giveaways[giveawayId];

        // Error handling:
        if (giveaway.liquidityDeployed) revert LiquidityAlreadyDeployed();
        if (usdcAmount == 0) revert("USDC amount must be greater than zero");
        if (tokenAmount == 0) revert("Token amount must be greater than zero");

        // Check that the contract has sufficient USDC balance
        uint256 contractUsdcBalance = USDC.balanceOf(address(this));
        if (contractUsdcBalance < usdcAmount) {
            revert("Insufficient USDC balance in contract");
        }

        // Calculate sqrtPriceX96 based on the fair launch price
        // Using the correct formula from Uniswap V3 documentation

        // Determine token order (V3 requires token0 < token1)
        address token0 = giveaway.tokenAddress < address(USDC)
            ? giveaway.tokenAddress
            : address(USDC);
        address token1 = giveaway.tokenAddress < address(USDC)
            ? address(USDC)
            : giveaway.tokenAddress;

        // Calculate the price ratio with proper decimal handling
        // Price should be in the format: token1_amount / token0_amount
        uint256 numerator;
        uint256 denominator;

        if (token0 == giveaway.tokenAddress) {
            // price = token1/token0 = USDC/token
            numerator = usdcAmount; // USDC amount (6 decimals)
            denominator = tokenAmount; // token amount (18 decimals)
            // Adjust for decimal difference: multiply numerator by 10^(18-6) = 10^12
            numerator = numerator * (10 ** (TOKEN_DECIMALS - USDC_DECIMALS));
        } else {
            // price = token1/token0 = token/USDC
            numerator = tokenAmount; // token amount (18 decimals)
            denominator = usdcAmount; // USDC amount (6 decimals)
            // Adjust for decimal difference: multiply denominator by 10^(18-6) = 10^12
            denominator =
                denominator *
                (10 ** (TOKEN_DECIMALS - USDC_DECIMALS));
        }

        // Calculate sqrtPriceX96 = sqrt(numerator/denominator) * 2^96
        // To maintain precision, we calculate: sqrt(numerator * 2^192 / denominator)
        // But to avoid overflow, we use: sqrt(numerator) * 2^96 / sqrt(denominator)
        uint256 sqrtNumerator = _sqrt(numerator);
        uint256 sqrtDenominator = _sqrt(denominator);

        // Scale by 2^96 and divide
        uint160 sqrtPriceX96 = uint160((sqrtNumerator << 96) / sqrtDenominator);
        // uint160 sqrtPriceX96 = uint160(_sqrt(1) << 96);

        // Use default parameters
        uint24 feeTier = DEFAULT_V3_FEE_TIER;
        int24 tickLower = DEFAULT_V3_TICK_LOWER;
        int24 tickUpper = DEFAULT_V3_TICK_UPPER;

        uint256 amount0Desired = token0 == giveaway.tokenAddress
            ? tokenAmount
            : usdcAmount;
        uint256 amount1Desired = token1 == giveaway.tokenAddress
            ? tokenAmount
            : usdcAmount;

        // Check if pool exists, create if it doesn't
        address poolAddress = IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool(
            token0,
            token1,
            feeTier
        );

        if (poolAddress == address(0)) {
            // Create new pool
            poolAddress = IUniswapV3Factory(UNISWAP_V3_FACTORY).createPool(
                token0,
                token1,
                feeTier
            );

            // Initialize the pool with the specified price
            IUniswapV3Pool(poolAddress).initialize(sqrtPriceX96);
        }

        // Approve the position manager to spend our tokens
        IERC20(giveaway.tokenAddress).approve(
            UNISWAP_V3_POSITION_MANAGER,
            tokenAmount
        );
        USDC.approve(UNISWAP_V3_POSITION_MANAGER, usdcAmount);

        // Mint the liquidity position
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: token0,
                token1: token1,
                fee: feeTier,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: (amount0Desired * 95) / 100, // 5% slippage tolerance
                amount1Min: (amount1Desired * 95) / 100, // 5% slippage tolerance
                recipient: address(0), // Burn the NFT position (permanent liquidity)
                deadline: block.timestamp + 300 // 5 minutes from now
            });

        (, , uint256 amount0, uint256 amount1) = INonfungiblePositionManager(
            UNISWAP_V3_POSITION_MANAGER
        ).mint(params);

        // Update state
        giveaway.liquidityDeployed = true;

        emit LiquidityDeployed(
            giveawayId,
            poolAddress,
            token0 == giveaway.tokenAddress ? amount0 : amount1,
            token0 == address(USDC) ? amount0 : amount1
        );
    }

    /**
     * @notice Finalize a giveaway after the end time
     * @param giveawayId ID of the giveaway to finalize
     */
    function finalizeGiveaway(
        uint256 giveawayId
    )
        external
        nonReentrant
        validGiveaway(giveawayId)
        onlyProjectOwner(giveawayId)
    {
        GiveawayData storage giveaway = giveaways[giveawayId];

        if (giveaway.finalized) revert GiveawayAlreadyFinalized();
        if (block.timestamp <= giveaway.endTime) revert GiveawayNotFinalized();
        if (giveaway.cancelled) revert GiveawayAlreadyCancelled();

        giveaway.finalized = true;

        // Calculate and transfer platform fee + project proceeds
        uint256 finalAllocation = giveaway.totalDeposited >
            giveaway.maxAllocation
            ? giveaway.maxAllocation
            : giveaway.totalDeposited;

        uint256 platformFee = (finalAllocation * PLATFORM_FEE) / 10000;
        // uint256 projectProceeds = finalAllocation - platformFee;

        // Transfer platform fee using SafeERC20
        if (platformFee > 0) {
            USDC.safeTransfer(platformFeeRecipient, platformFee);
        }

        // Calculate remaining USDC for liquidity deployment
        uint256 remainingUSDC = finalAllocation - platformFee;

        // Allocate dev tokens if devPercentage > 0
        uint256 devTokensAllocated = 0;
        if (giveaway.devPercentage > 0) {
            devTokensAllocated =
                (giveaway.totalTokensForSale * giveaway.devPercentage) /
                10000;
            giveaway.devTokensAllocated = true;
        }

        // Allocate liquidity tokens if liquidityPercentage > 0
        uint256 liquidityTokensAllocated = 0;
        if (giveaway.liquidityPercentage > 0) {
            liquidityTokensAllocated =
                (giveaway.totalTokensForSale * giveaway.liquidityPercentage) /
                10000;
            giveaway.liquidityTokensAllocated = true;
        }

        emit GiveawayFinalized(
            giveawayId,
            giveaway.totalDeposited,
            giveaway.participantCount,
            devTokensAllocated,
            liquidityTokensAllocated
        );

        claimAndDeployLiquidityUniswapV3(
            giveawayId,
            remainingUSDC,
            liquidityTokensAllocated
        );
    }

    /**
     * @notice Claim dev tokens after giveaway finalization
     * @param giveawayId ID of the giveaway
     */
    function claimDevTokens(
        uint256 giveawayId
    )
        external
        nonReentrant
        validGiveaway(giveawayId)
        onlyProjectOwner(giveawayId)
        giveawayFinalized(giveawayId)
    {
        GiveawayData storage giveaway = giveaways[giveawayId];

        if (!giveaway.devTokensAllocated) revert DevTokensNotAllocated();
        if (giveaway.devTokensClaimed > 0) revert DevTokensAlreadyClaimed();

        // Calculate dev tokens
        uint256 devTokens = (giveaway.totalTokensForSale *
            giveaway.devPercentage) / 10000;
        giveaway.devTokensClaimed = devTokens;

        // Transfer dev tokens
        IERC20(giveaway.tokenAddress).safeTransfer(
            giveaway.projectOwner,
            devTokens
        );

        emit DevTokensClaimed(giveawayId, giveaway.projectOwner, devTokens);
    }

    /**
     * @notice Claim liquidity tokens after giveaway finalization
     * @param giveawayId ID of the giveaway
     */
    function claimLiquidityTokens(
        uint256 giveawayId
    )
        external
        nonReentrant
        validGiveaway(giveawayId)
        onlyProjectOwner(giveawayId)
        giveawayFinalized(giveawayId)
    {
        GiveawayData storage giveaway = giveaways[giveawayId];

        if (!giveaway.liquidityTokensAllocated)
            revert LiquidityTokensNotAllocated();
        if (giveaway.liquidityTokensClaimed > 0)
            revert LiquidityTokensAlreadyClaimed();

        // Calculate liquidity tokens
        uint256 liquidityTokens = (giveaway.totalTokensForSale *
            giveaway.liquidityPercentage) / 10000;
        giveaway.liquidityTokensClaimed = liquidityTokens;

        // Transfer liquidity tokens
        IERC20(giveaway.tokenAddress).safeTransfer(
            giveaway.projectOwner,
            liquidityTokens
        );

        emit LiquidityTokensClaimed(
            giveawayId,
            giveaway.projectOwner,
            liquidityTokens
        );
    }

    /**
     * @notice Cancel a giveaway (only before it starts)
     * @param giveawayId ID of the giveaway to cancel
     */
    function cancelGiveaway(
        uint256 giveawayId
    )
        external
        nonReentrant
        validGiveaway(giveawayId)
        onlyProjectOwner(giveawayId)
    {
        GiveawayData storage giveaway = giveaways[giveawayId];

        if (giveaway.finalized) revert GiveawayAlreadyFinalized();
        if (block.timestamp >= giveaway.startTime) revert GiveawayNotActive();

        giveaway.cancelled = true;

        // Return tokens to project owner using SafeERC20
        IERC20(giveaway.tokenAddress).safeTransfer(
            giveaway.projectOwner,
            giveaway.totalTokensForSale
        );

        emit GiveawayCancelled(giveawayId);
    }

    // ============ Merkle Tree Functions ============

    /**
     * @notice Set merkle root for gas-efficient token distribution
     * @param giveawayId ID of the giveaway
     * @param merkleRoot_ Merkle root containing all participant allocations
     * @dev Can only be called by project owner after giveaway is finalized
     */
    function setMerkleRoot(
        uint256 giveawayId,
        bytes32 merkleRoot_
    )
        external
        nonReentrant
        validGiveaway(giveawayId)
        onlyProjectOwner(giveawayId)
        giveawayFinalized(giveawayId)
    {
        GiveawayData storage giveaway = giveaways[giveawayId];

        if (giveaway.merkleEnabled) revert MerkleAlreadySet();
        if (merkleRoot_ == bytes32(0)) revert InvalidMerkleRoot();

        giveaway.merkleRoot = merkleRoot_;
        giveaway.merkleEnabled = true;

        emit MerkleRootSet(giveawayId, merkleRoot_);
    }

    /**
     * @notice Claim tokens using merkle proof (gas-efficient method)
     * @param giveawayId ID of the giveaway
     * @param claimIndex Unique index for this claim in the merkle tree
     * @param participant Address of the participant claiming tokens
     * @param tokenAmount Amount of tokens to claim
     * @param refundAmount Amount of USDC to refund (if any)
     * @param merkleProof Merkle proof for the claim
     */
    function merkleClaim(
        uint256 giveawayId,
        uint256 claimIndex,
        address participant,
        uint256 tokenAmount,
        uint256 refundAmount,
        bytes32[] calldata merkleProof
    )
        external
        nonReentrant
        validGiveaway(giveawayId)
        giveawayFinalized(giveawayId)
    {
        GiveawayData memory giveaway = giveaways[giveawayId];

        if (!giveaway.merkleEnabled) revert MerkleNotEnabled();
        if (merkleClaimed[giveawayId][claimIndex])
            revert MerkleAlreadyClaimed();

        // Verify merkle proof
        bytes32 leaf = keccak256(
            abi.encodePacked(claimIndex, participant, tokenAmount, refundAmount)
        );
        if (!MerkleProof.verify(merkleProof, giveaway.merkleRoot, leaf)) {
            revert InvalidMerkleProof();
        }

        // Mark as claimed
        merkleClaimed[giveawayId][claimIndex] = true;

        // Transfer tokens
        if (tokenAmount > 0) {
            IERC20(giveaway.tokenAddress).safeTransfer(
                participant,
                tokenAmount
            );
        }

        // Transfer refund
        if (refundAmount > 0) {
            USDC.safeTransfer(participant, refundAmount);
        }

        emit MerkleTokensClaimed(
            giveawayId,
            claimIndex,
            participant,
            tokenAmount,
            refundAmount
        );
    }

    /**
     * @notice Batch claim tokens for multiple participants using merkle proofs
     * @param giveawayId ID of the giveaway
     * @param claimIndices Array of claim indices
     * @param claimants Array of participant addresses
     * @param tokenAmounts Array of token amounts to claim
     * @param refundAmounts Array of refund amounts
     * @param merkleProofs Array of merkle proofs
     */
    function batchMerkleClaim(
        uint256 giveawayId,
        uint256[] calldata claimIndices,
        address[] calldata claimants,
        uint256[] calldata tokenAmounts,
        uint256[] calldata refundAmounts,
        bytes32[][] calldata merkleProofs
    )
        external
        nonReentrant
        validGiveaway(giveawayId)
        giveawayFinalized(giveawayId)
    {
        uint256 length = claimIndices.length;
        require(
            length == claimants.length &&
                length == tokenAmounts.length &&
                length == refundAmounts.length &&
                length == merkleProofs.length,
            "Array length mismatch"
        );

        GiveawayData memory giveaway = giveaways[giveawayId];
        if (!giveaway.merkleEnabled) revert MerkleNotEnabled();

        for (uint256 i = 0; i < length; i++) {
            uint256 claimIndex = claimIndices[i];
            address participant = claimants[i];
            uint256 tokenAmount = tokenAmounts[i];
            uint256 refundAmount = refundAmounts[i];
            bytes32[] memory merkleProof = merkleProofs[i];

            if (merkleClaimed[giveawayId][claimIndex]) continue; // Skip already claimed

            // Verify merkle proof
            bytes32 leaf = keccak256(
                abi.encodePacked(
                    claimIndex,
                    participant,
                    tokenAmount,
                    refundAmount
                )
            );
            if (!MerkleProof.verify(merkleProof, giveaway.merkleRoot, leaf)) {
                continue; // Skip invalid proofs
            }

            // Mark as claimed
            merkleClaimed[giveawayId][claimIndex] = true;

            // Transfer tokens
            if (tokenAmount > 0) {
                IERC20(giveaway.tokenAddress).safeTransfer(
                    participant,
                    tokenAmount
                );
            }

            // Transfer refund
            if (refundAmount > 0) {
                USDC.safeTransfer(participant, refundAmount);
            }

            emit MerkleTokensClaimed(
                giveawayId,
                claimIndex,
                participant,
                tokenAmount,
                refundAmount
            );
        }
    }

    // ============ View Functions ============

    // ============ REMOVED: On-chain calculations moved to off-chain for maximum efficiency ============
    // Previously: calculateTokenAllocation() and calculateRefund()
    // Now: All calculations happen in JavaScript (MerkleTreeUtils.js)
    // This provides unlimited scalability and minimal gas costs

    /**
     * @notice Get giveaway details
     * @param giveawayId ID of the giveaway
     * @return giveaway Giveaway struct
     */
    function getGiveaway(
        uint256 giveawayId
    )
        external
        view
        validGiveaway(giveawayId)
        returns (GiveawayData memory giveaway)
    {
        return giveaways[giveawayId];
    }

    /**
     * @notice Get participant details
     * @param giveawayId ID of the giveaway
     * @param participant Address of the participant
     * @return p Participant struct
     */
    function getParticipant(
        uint256 giveawayId,
        address participant
    ) external view validGiveaway(giveawayId) returns (Participant memory p) {
        return participants[giveawayId][participant];
    }

    /**
     * @notice Get all participants for a giveaway
     * @param giveawayId ID of the giveaway
     * @return participantList Array of participant addresses
     */
    function getGiveawayParticipants(
        uint256 giveawayId
    )
        external
        view
        validGiveaway(giveawayId)
        returns (address[] memory participantList)
    {
        return giveawayParticipants[giveawayId];
    }

    /**
     * @notice Get passport verification details for a wallet
     * @param wallet Address to check
     * @return verification PassportVerification struct
     */
    function getVerification(
        address wallet
    ) external view returns (PassportVerification memory verification) {
        return verifications[wallet];
    }

    /**
     * @notice Check if a merkle claim has been made
     * @param giveawayId ID of the giveaway
     * @param claimIndex Index of the claim to check
     * @return claimed Whether the claim has been made
     */
    function isMerkleClaimed(
        uint256 giveawayId,
        uint256 claimIndex
    ) external view validGiveaway(giveawayId) returns (bool claimed) {
        return merkleClaimed[giveawayId][claimIndex];
    }

    /**
     * @notice Get merkle tree information for a giveaway
     * @param giveawayId ID of the giveaway
     * @return merkleRoot The merkle root
     * @return merkleEnabled Whether merkle distribution is enabled
     */
    function getMerkleInfo(
        uint256 giveawayId
    )
        external
        view
        validGiveaway(giveawayId)
        returns (bytes32 merkleRoot, bool merkleEnabled)
    {
        GiveawayData memory giveaway = giveaways[giveawayId];
        return (giveaway.merkleRoot, giveaway.merkleEnabled);
    }

    /**
     * @notice Get token price for a giveaway (same for all participants)
     * @param giveawayId ID of the giveaway
     * @return tokenPrice Price per token in USDC (with 6 decimals)
     */
    function getTokenPrice(
        uint256 giveawayId
    ) external view validGiveaway(giveawayId) returns (uint256 tokenPrice) {
        GiveawayData memory giveaway = giveaways[giveawayId];

        // Calculate tokens available for participants (excluding dev and liquidity allocation)
        uint256 totalReservedPercentage = giveaway.devPercentage +
            giveaway.liquidityPercentage;
        uint256 tokensForParticipants = giveaway.totalTokensForSale -
            (giveaway.totalTokensForSale * totalReservedPercentage) /
            10000;

        if (giveaway.totalDeposited <= giveaway.maxAllocation) {
            // Under-allocated: price based on actual deposits
            tokenPrice =
                (giveaway.totalDeposited * 1e18) /
                tokensForParticipants;
        } else {
            // Over-allocated: price based on max allocation
            tokenPrice =
                (giveaway.maxAllocation * 1e18) /
                tokensForParticipants;
        }
    }

    /**
     * @notice Get tokens available for participants (excluding dev and liquidity allocation)
     * @param giveawayId ID of the giveaway
     * @return tokensForParticipants Tokens available for participants
     */
    function getTokensForParticipants(
        uint256 giveawayId
    )
        external
        view
        validGiveaway(giveawayId)
        returns (uint256 tokensForParticipants)
    {
        GiveawayData memory giveaway = giveaways[giveawayId];
        uint256 totalReservedPercentage = giveaway.devPercentage +
            giveaway.liquidityPercentage;
        tokensForParticipants =
            giveaway.totalTokensForSale -
            (giveaway.totalTokensForSale * totalReservedPercentage) /
            10000;
    }

    /**
     * @notice Get dev token allocation information
     * @param giveawayId ID of the giveaway
     * @return devTokensAllocated Amount of tokens allocated to dev
     * @return devTokensClaimed Amount of tokens claimed by dev
     * @return devPercentage Percentage allocated to dev (in basis points)
     */
    function getDevTokenInfo(
        uint256 giveawayId
    )
        external
        view
        validGiveaway(giveawayId)
        returns (
            uint256 devTokensAllocated,
            uint256 devTokensClaimed,
            uint256 devPercentage
        )
    {
        GiveawayData memory giveaway = giveaways[giveawayId];
        devTokensAllocated =
            (giveaway.totalTokensForSale * giveaway.devPercentage) /
            10000;
        devTokensClaimed = giveaway.devTokensClaimed;
        devPercentage = giveaway.devPercentage;
    }

    /**
     * @notice Get liquidity token allocation information
     * @param giveawayId ID of the giveaway
     * @return liquidityTokensAllocated Amount of tokens allocated to liquidity
     * @return liquidityTokensClaimed Amount of tokens claimed for liquidity
     * @return liquidityPercentage Percentage allocated to liquidity (in basis points)
     */
    function getLiquidityTokenInfo(
        uint256 giveawayId
    )
        external
        view
        validGiveaway(giveawayId)
        returns (
            uint256 liquidityTokensAllocated,
            uint256 liquidityTokensClaimed,
            uint256 liquidityPercentage
        )
    {
        GiveawayData memory giveaway = giveaways[giveawayId];
        liquidityTokensAllocated =
            (giveaway.totalTokensForSale * giveaway.liquidityPercentage) /
            10000;
        liquidityTokensClaimed = giveaway.liquidityTokensClaimed;
        liquidityPercentage = giveaway.liquidityPercentage;
    }

    /**
     * @notice Get complete allocation breakdown for a giveaway
     * @param giveawayId ID of the giveaway
     * @return participantTokens Tokens available for participants
     * @return devTokens Tokens allocated to developer
     * @return liquidityTokens Tokens allocated to liquidity
     * @return participantPercentage Percentage for participants (in basis points)
     * @return devPercentage Percentage for developer (in basis points)
     * @return liquidityPercentage Percentage for liquidity (in basis points)
     */
    function getAllocationBreakdown(
        uint256 giveawayId
    )
        external
        view
        validGiveaway(giveawayId)
        returns (
            uint256 participantTokens,
            uint256 devTokens,
            uint256 liquidityTokens,
            uint256 participantPercentage,
            uint256 devPercentage,
            uint256 liquidityPercentage
        )
    {
        GiveawayData memory giveaway = giveaways[giveawayId];

        devTokens =
            (giveaway.totalTokensForSale * giveaway.devPercentage) /
            10000;
        liquidityTokens =
            (giveaway.totalTokensForSale * giveaway.liquidityPercentage) /
            10000;
        participantTokens =
            giveaway.totalTokensForSale -
            devTokens -
            liquidityTokens;

        devPercentage = giveaway.devPercentage;
        liquidityPercentage = giveaway.liquidityPercentage;
        participantPercentage = 10000 - devPercentage - liquidityPercentage;
    }

    /**
     * @notice Check if dev tokens are available to claim
     * @param giveawayId ID of the giveaway
     * @return canClaim Whether dev tokens can be claimed
     * @return reason Reason if cannot claim (0=can claim, 1=not finalized, 2=already claimed, 3=no allocation)
     */
    function canClaimDevTokens(
        uint256 giveawayId
    )
        external
        view
        validGiveaway(giveawayId)
        returns (bool canClaim, uint256 reason)
    {
        GiveawayData memory giveaway = giveaways[giveawayId];

        if (giveaway.devPercentage == 0) {
            return (false, 3); // No allocation
        }

        if (!giveaway.finalized) {
            return (false, 1); // Not finalized
        }

        if (giveaway.devTokensClaimed > 0) {
            return (false, 2); // Already claimed
        }

        return (true, 0); // Can claim
    }

    /**
     * @notice Check if liquidity tokens are available to claim
     * @param giveawayId ID of the giveaway
     * @return canClaim Whether liquidity tokens can be claimed
     * @return reason Reason if cannot claim (0=can claim, 1=not finalized, 2=already claimed, 3=no allocation)
     */
    function canClaimLiquidityTokens(
        uint256 giveawayId
    )
        external
        view
        validGiveaway(giveawayId)
        returns (bool canClaim, uint256 reason)
    {
        GiveawayData memory giveaway = giveaways[giveawayId];

        if (giveaway.liquidityPercentage == 0) {
            return (false, 3); // No allocation
        }

        if (!giveaway.finalized) {
            return (false, 1); // Not finalized
        }

        if (giveaway.liquidityTokensClaimed > 0) {
            return (false, 2); // Already claimed
        }

        return (true, 0); // Can claim
    }

    /**
     * @notice Get average allocation per participant for over-allocated scenario
     * @param giveawayId ID of the giveaway
     * @return avgAllocation Average USDC allocation per participant
     */
    function getAverageAllocation(
        uint256 giveawayId
    ) external view validGiveaway(giveawayId) returns (uint256 avgAllocation) {
        GiveawayData memory giveaway = giveaways[giveawayId];

        if (giveaway.participantCount == 0) return 0;

        uint256 effectiveAllocation = giveaway.totalDeposited >
            giveaway.maxAllocation
            ? giveaway.maxAllocation
            : giveaway.totalDeposited;

        avgAllocation = effectiveAllocation / giveaway.participantCount;
    }

    /**
     * @notice Validate allocation parameters before giveaway creation
     * @param devPercentage Percentage of tokens for developer (in basis points)
     * @param liquidityPercentage Percentage of tokens for liquidity pool (in basis points)
     * @return isValid Whether the allocation parameters are valid
     * @return reason Reason if invalid (0=valid, 1=dev too high, 2=liquidity too high, 3=liquidity below 20% minimum, 4=combined too high)
     */
    function validateAllocationParameters(
        uint256 devPercentage,
        uint256 liquidityPercentage
    ) external pure returns (bool isValid, uint256 reason) {
        // Check individual percentages
        if (devPercentage > 10000) {
            return (false, 1); // Dev percentage too high
        }

        if (liquidityPercentage > 10000) {
            return (false, 2); // Liquidity percentage too high
        }

        // Check minimum liquidity requirement (now mandatory)
        if (liquidityPercentage < MIN_LIQUIDITY_PERCENTAGE) {
            return (false, 3); // Liquidity below 20% minimum (required for all projects)
        }

        // Check combined maximum
        if (devPercentage + liquidityPercentage > MAX_COMBINED_PERCENTAGE) {
            return (false, 4); // Combined percentage exceeds 70% maximum
        }

        return (true, 0); // Valid
    }

    // ============ Internal Helper Functions ============

    /**
     * @notice Calculate integer square root using Babylonian method
     * @param x Input value
     * @return result Square root of x
     */
    function _sqrt(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) return 0;

        // Initial guess
        result = x;
        uint256 k = (x >> 1) + 1;

        // Babylonian method
        while (k < result) {
            result = k;
            k = (x / k + k) >> 1;
        }
    }
}
