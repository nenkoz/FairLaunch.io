// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./TokenFactory.sol";
import "./ProjectToken.sol";
import "./Giveaway.sol";

/**
 * @title LaunchPlatform
 * @dev Professional orchestrator contract for launching projects with token + giveaway
 * @notice This contract provides a single-transaction experience for launching projects
 */
contract LaunchPlatform is Ownable, ReentrancyGuard, Pausable {
    // ============ State Variables ============

    /// @notice TokenFactory contract
    TokenFactory public immutable tokenFactory;

    /// @notice Giveaway contract
    Giveaway public immutable giveaway;

    /// @notice Platform fee recipient
    address public immutable platformFeeRecipient;

    /// @notice Total projects launched
    uint256 public totalProjectsLaunched;

    // Professional allocation limits
    /// @notice Minimum liquidity percentage for healthy trading (20%)
    uint256 public constant MIN_LIQUIDITY_PERCENTAGE = 2000; // 20% in basis points

    /// @notice Maximum combined dev + liquidity percentage (70%)
    uint256 public constant MAX_COMBINED_PERCENTAGE = 7000; // 70% in basis points

    /// @notice Project launch records
    struct ProjectLaunch {
        address creator;
        address tokenAddress;
        uint256 giveawayId;
        uint256 launchTimestamp;
        string name;
        string symbol;
    }

    /// @notice Mapping of launch ID to project data
    mapping(uint256 => ProjectLaunch) public projectLaunches;

    /// @notice Mapping of creator to their launched projects
    mapping(address => uint256[]) public creatorProjects;

    // ============ Events ============

    event ProjectLaunched(
        uint256 indexed launchId,
        address indexed creator,
        address indexed tokenAddress,
        uint256 giveawayId,
        string name,
        string symbol,
        uint256 devPercentage,
        uint256 liquidityPercentage,
        uint256 timestamp
    );

    event DevAllocationTransferred(
        uint256 indexed launchId,
        address indexed creator,
        address indexed tokenAddress,
        uint256 devAllocation
    );

    // ============ Errors ============

    error InvalidParameters();
    error InsufficientFee();
    error ProjectLaunchFailed();
    error InsufficientAllowance();

    // ============ Constructor ============

    constructor(
        address tokenFactory_,
        address giveaway_,
        address platformFeeRecipient_
    ) Ownable(msg.sender) {
        tokenFactory = TokenFactory(payable(tokenFactory_));
        giveaway = Giveaway(giveaway_);
        platformFeeRecipient = platformFeeRecipient_;
    }

    // ============ External Functions ============

    /**
     * @notice Launch a complete project with token creation and giveaway setup
     * @param tokenParams Token creation parameters
     * @param giveawayParams Giveaway setup parameters including dev and liquidity percentages
     * @return launchId Unique launch ID
     * @return tokenAddress Address of created token
     * @return giveawayId ID of created giveaway
     * @dev Developer will receive devPercentage of giveaway tokens after finalization
     * @dev Liquidity pool will receive liquidityPercentage of giveaway tokens after finalization
     */
    function launchProject(
        TokenParams memory tokenParams,
        GiveawayParams memory giveawayParams
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 launchId, address tokenAddress, uint256 giveawayId)
    {
        // Validate parameters
        _validateLaunchParams(tokenParams, giveawayParams);

        // Check creation fee
        uint256 requiredFee = tokenFactory.creationFee();
        if (msg.value < requiredFee) revert InsufficientFee();

        // Step 1: Create token via TokenFactory
        tokenAddress = tokenFactory.createToken{value: requiredFee}(
            tokenParams.name,
            tokenParams.symbol,
            tokenParams.initialSupply,
            tokenParams.maxSupply,
            tokenParams.description
        );

        // Step 2: Setup token for giveaway
        ProjectToken projectToken = ProjectToken(tokenAddress);

        // Step 3: Approve giveaway contract to spend tokens
        projectToken.approve(
            address(giveaway),
            giveawayParams.tokensForGiveaway
        );

        // Step 4: Create giveaway with dev and liquidity percentages
        giveawayId = giveaway.createGiveaway(
            tokenAddress,
            giveawayParams.startTime,
            giveawayParams.endTime,
            giveawayParams.maxAllocation,
            giveawayParams.tokensForGiveaway,
            giveawayParams.devPercentage,
            giveawayParams.liquidityPercentage
        );

        // Step 5: Record launch
        launchId = totalProjectsLaunched++;

        projectLaunches[launchId] = ProjectLaunch({
            creator: msg.sender,
            tokenAddress: tokenAddress,
            giveawayId: giveawayId,
            launchTimestamp: block.timestamp,
            name: tokenParams.name,
            symbol: tokenParams.symbol
        });

        creatorProjects[msg.sender].push(launchId);

        // Step 6: Optional post-launch configuration
        if (giveawayParams.enableTradingImmediately) {
            projectToken.enableTrading();
        }

        // Refund excess payment
        if (msg.value > requiredFee) {
            payable(msg.sender).transfer(msg.value - requiredFee);
        }

        emit ProjectLaunched(
            launchId,
            msg.sender,
            tokenAddress,
            giveawayId,
            tokenParams.name,
            tokenParams.symbol,
            giveawayParams.devPercentage,
            giveawayParams.liquidityPercentage,
            block.timestamp
        );
    }

    /**
     * @notice Get launch information
     * @param launchId ID of the launch
     * @return launch Project launch data
     */
    function getLaunchInfo(
        uint256 launchId
    ) external view returns (ProjectLaunch memory launch) {
        return projectLaunches[launchId];
    }

    /**
     * @notice Get projects launched by a creator
     * @param creator Address of the creator
     * @return projectIds Array of launch IDs
     */
    function getCreatorProjects(
        address creator
    ) external view returns (uint256[] memory projectIds) {
        return creatorProjects[creator];
    }

    /**
     * @notice Get complete project information including token and giveaway data
     * @param launchId ID of the launch
     * @return launch Project launch data
     * @return tokenAddress Address of the project token
     * @return giveawayData Giveaway information
     */
    function getCompleteProjectInfo(
        uint256 launchId
    )
        external
        view
        returns (
            ProjectLaunch memory launch,
            address tokenAddress,
            Giveaway.GiveawayData memory giveawayData
        )
    {
        launch = projectLaunches[launchId];
        tokenAddress = launch.tokenAddress;
        giveawayData = giveaway.getGiveaway(launch.giveawayId);
    }

    /**
     * @notice Emergency pause (only owner)
     */
    function pauseLaunches() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause (only owner)
     */
    function unpauseLaunches() external onlyOwner {
        _unpause();
    }

    // ============ Internal Functions ============

    /**
     * @notice Validate launch parameters
     */
    function _validateLaunchParams(
        TokenParams memory tokenParams,
        GiveawayParams memory giveawayParams
    ) internal view {
        if (bytes(tokenParams.name).length == 0) revert InvalidParameters();
        if (bytes(tokenParams.symbol).length == 0) revert InvalidParameters();
        if (tokenParams.initialSupply == 0) revert InvalidParameters();
        if (tokenParams.maxSupply == 0) revert InvalidParameters();
        if (giveawayParams.tokensForGiveaway == 0) revert InvalidParameters();
        if (giveawayParams.startTime <= block.timestamp)
            revert InvalidParameters();
        if (giveawayParams.endTime <= giveawayParams.startTime)
            revert InvalidParameters();
        if (giveawayParams.maxAllocation == 0) revert InvalidParameters();

        // Ensure total supply doesn't exceed maximum allowed
        if (tokenParams.initialSupply > tokenParams.maxSupply) {
            revert InvalidParameters();
        }

        // Ensure giveaway tokens don't exceed total supply
        if (giveawayParams.tokensForGiveaway > tokenParams.initialSupply) {
            revert InvalidParameters();
        }

        // Ensure dev percentage is valid (0-100%)
        if (giveawayParams.devPercentage > 10000) {
            revert InvalidParameters();
        }

        // Ensure liquidity percentage is valid (0-100%)
        if (giveawayParams.liquidityPercentage > 10000) {
            revert InvalidParameters();
        }

        // Professional limits enforcement
        if (giveawayParams.liquidityPercentage < MIN_LIQUIDITY_PERCENTAGE) {
            revert InvalidParameters(); // Minimum 20% liquidity required for all projects
        }

        // Ensure total allocations don't exceed 70% (professional maximum)
        if (
            giveawayParams.devPercentage + giveawayParams.liquidityPercentage >
            MAX_COMBINED_PERCENTAGE
        ) {
            revert InvalidParameters(); // Maximum 70% combined to ensure fair participant allocation
        }
    }

    // ============ Structs ============

    struct TokenParams {
        string name;
        string symbol;
        uint256 initialSupply;
        uint256 maxSupply;
        string description;
    }

    struct GiveawayParams {
        uint256 startTime;
        uint256 endTime;
        uint256 maxAllocation;
        uint256 tokensForGiveaway;
        uint256 devPercentage; // Percentage of tokens for developer (in basis points, e.g., 1000 = 10%)
        uint256 liquidityPercentage; // Percentage of tokens for liquidity pool (in basis points, e.g., 3000 = 30%)
        bool enableTradingImmediately;
    }
}
