// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ProjectToken
 * @dev Professional ERC20 token template for project launches
 * @notice This contract serves as a template for all project tokens created through the platform
 */
contract ProjectToken is
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    Ownable,
    ReentrancyGuard
{
    // ============ Constants ============

    /// @notice Maximum supply cap to prevent inflation attacks
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18; // 1 billion tokens

    /// @notice Platform fee for token creation (in basis points)
    uint256 public constant PLATFORM_FEE_BPS = 100; // 1%

    // ============ State Variables ============

    /// @notice Token metadata
    string public projectDescription;
    string public projectWebsite;
    string public projectTwitter;
    string public projectTelegram;

    /// @notice Launch information
    uint256 public immutable launchTimestamp;
    address public immutable creator;
    address public immutable platformFeeRecipient;

    /// @notice Supply management
    uint256 public immutable maxSupply;
    bool public mintingFinished;

    /// @notice Trading controls
    bool public tradingEnabled;
    mapping(address => bool) public isExcludedFromTrading;

    // ============ Events ============

    event ProjectMetadataUpdated(
        string description,
        string website,
        string twitter,
        string telegram
    );

    event TradingEnabled(uint256 timestamp);
    event MintingFinished(uint256 timestamp);
    event TradingExclusionUpdated(address indexed account, bool excluded);

    // ============ Errors ============

    error TradingNotEnabled();
    error MintingAlreadyFinished();
    error MaxSupplyExceeded();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidMetadata();

    // ============ Modifiers ============

    modifier canTrade(address from, address to) {
        if (
            !tradingEnabled &&
            !isExcludedFromTrading[from] &&
            !isExcludedFromTrading[to] &&
            from != address(0) &&
            to != address(0)
        ) {
            revert TradingNotEnabled();
        }
        _;
    }

    modifier canMint() {
        if (mintingFinished) revert MintingAlreadyFinished();
        _;
    }

    // ============ Constructor ============

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 maxSupply_,
        address creator_,
        address platformFeeRecipient_,
        string memory description
    ) ERC20(name, symbol) Ownable(creator_) {
        if (creator_ == address(0) || platformFeeRecipient_ == address(0)) {
            revert InvalidAddress();
        }
        if (initialSupply > MAX_SUPPLY || maxSupply_ > MAX_SUPPLY) {
            revert MaxSupplyExceeded();
        }
        if (bytes(description).length == 0) {
            revert InvalidMetadata();
        }

        creator = creator_;
        platformFeeRecipient = platformFeeRecipient_;
        maxSupply = maxSupply_ == 0 ? MAX_SUPPLY : maxSupply_;
        launchTimestamp = block.timestamp;
        projectDescription = description;

        // Exclude creator and platform from trading restrictions initially
        isExcludedFromTrading[creator_] = true;
        isExcludedFromTrading[platformFeeRecipient_] = true;
        isExcludedFromTrading[address(0)] = true; // Allow burns

        // Mint initial supply to creator
        if (initialSupply > 0) {
            _mint(creator_, initialSupply);
        }
    }

    // ============ External Functions ============

    /**
     * @notice Update project metadata (only owner)
     * @param description_ Project description
     * @param website_ Project website URL
     * @param twitter_ Project Twitter handle
     * @param telegram_ Project Telegram link
     */
    function updateMetadata(
        string memory description_,
        string memory website_,
        string memory twitter_,
        string memory telegram_
    ) external onlyOwner {
        if (bytes(description_).length == 0) revert InvalidMetadata();

        projectDescription = description_;
        projectWebsite = website_;
        projectTwitter = twitter_;
        projectTelegram = telegram_;

        emit ProjectMetadataUpdated(
            description_,
            website_,
            twitter_,
            telegram_
        );
    }

    /**
     * @notice Enable trading for the token
     * @dev Once enabled, cannot be disabled
     */
    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        emit TradingEnabled(block.timestamp);
    }

    /**
     * @notice Finish minting permanently
     * @dev Once called, no more tokens can be minted
     */
    function finishMinting() external onlyOwner {
        mintingFinished = true;
        emit MintingFinished(block.timestamp);
    }

    /**
     * @notice Mint additional tokens (only owner, before minting finished)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(
        address to,
        uint256 amount
    ) external onlyOwner canMint nonReentrant {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (totalSupply() + amount > maxSupply) revert MaxSupplyExceeded();

        _mint(to, amount);
    }

    /**
     * @notice Batch mint tokens to multiple addresses
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to mint
     */
    function batchMint(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner canMint nonReentrant {
        if (recipients.length != amounts.length) revert InvalidAmount();
        if (recipients.length == 0) revert InvalidAmount();

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        if (totalSupply() + totalAmount > maxSupply) revert MaxSupplyExceeded();

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert InvalidAddress();
            if (amounts[i] == 0) revert InvalidAmount();
            _mint(recipients[i], amounts[i]);
        }
    }

    /**
     * @notice Update trading exclusion status for an address
     * @param account Address to update
     * @param excluded Whether to exclude from trading restrictions
     */
    function setTradingExclusion(
        address account,
        bool excluded
    ) external onlyOwner {
        if (account == address(0)) revert InvalidAddress();

        isExcludedFromTrading[account] = excluded;
        emit TradingExclusionUpdated(account, excluded);
    }

    /**
     * @notice Emergency pause (only owner)
     * @dev Pauses all token transfers
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause (only owner)
     * @dev Resumes all token transfers
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ View Functions ============

    /**
     * @notice Get comprehensive token information
     * @return name_ Token name
     * @return symbol_ Token symbol
     * @return totalSupply_ Current total supply
     * @return maxSupply_ Maximum supply cap
     * @return decimals_ Token decimals
     * @return creator_ Token creator address
     * @return launchTimestamp_ Launch timestamp
     * @return tradingEnabled_ Whether trading is enabled
     * @return mintingFinished_ Whether minting is finished
     * @return description_ Project description
     * @return website_ Project website
     * @return twitter_ Project Twitter handle
     * @return telegram_ Project Telegram link
     */
    function getTokenInfo()
        external
        view
        returns (
            string memory name_,
            string memory symbol_,
            uint256 totalSupply_,
            uint256 maxSupply_,
            uint256 decimals_,
            address creator_,
            uint256 launchTimestamp_,
            bool tradingEnabled_,
            bool mintingFinished_,
            string memory description_,
            string memory website_,
            string memory twitter_,
            string memory telegram_
        )
    {
        return (
            name(),
            symbol(),
            totalSupply(),
            maxSupply,
            decimals(),
            creator,
            launchTimestamp,
            tradingEnabled,
            mintingFinished,
            projectDescription,
            projectWebsite,
            projectTwitter,
            projectTelegram
        );
    }

    /**
     * @notice Check if an address can currently trade
     * @param account Address to check
     * @return Whether the address can trade
     */
    function canTradeTokens(address account) external view returns (bool) {
        return tradingEnabled || isExcludedFromTrading[account];
    }

    // ============ Internal Functions ============

    /**
     * @notice Override transfer to implement trading controls
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) canTrade(from, to) {
        super._update(from, to, value);
    }

    /**
     * @notice Get circulating supply (total supply minus burned tokens)
     * @return Circulating supply amount
     */
    function getCirculatingSupply() public view returns (uint256) {
        return totalSupply();
    }

    /**
     * @notice Calculate platform fee for a given amount
     * @param amount Amount to calculate fee for
     * @return Platform fee amount
     */
    function calculatePlatformFee(
        uint256 amount
    ) public pure returns (uint256) {
        return (amount * PLATFORM_FEE_BPS) / 10000;
    }
}
