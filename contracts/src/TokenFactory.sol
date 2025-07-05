// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ProjectToken.sol";

/**
 * @title TokenFactory
 * @dev Professional factory contract for creating project tokens
 * @notice This contract manages the creation and deployment of new project tokens
 */
contract TokenFactory is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Platform fee for token creation (in native currency)
    uint256 public constant CREATION_FEE = 0.1 ether; // 0.1 ETH/CELO

    /// @notice Minimum initial supply for tokens
    uint256 public constant MIN_INITIAL_SUPPLY = 1000 * 10 ** 18; // 1,000 tokens

    /// @notice Maximum initial supply for tokens
    uint256 public constant MAX_INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18; // 1 billion tokens

    /// @notice Maximum name length
    uint256 public constant MAX_NAME_LENGTH = 50;

    /// @notice Maximum symbol length
    uint256 public constant MAX_SYMBOL_LENGTH = 10;

    /// @notice Maximum description length
    uint256 public constant MAX_DESCRIPTION_LENGTH = 500;

    // ============ State Variables ============

    /// @notice Platform fee recipient
    address public immutable platformFeeRecipient;

    /// @notice Total number of tokens created
    uint256 public totalTokensCreated;

    /// @notice Current creation fee (can be updated by owner)
    uint256 public creationFee;

    /// @notice Mapping of creator to their created tokens
    mapping(address => address[]) public creatorTokens;

    /// @notice Mapping of token address to creator
    mapping(address => address) public tokenCreator;

    /// @notice Mapping of token address to creation timestamp
    mapping(address => uint256) public tokenCreationTime;

    /// @notice Mapping of token address to verified status
    mapping(address => bool) public isVerifiedToken;

    /// @notice Array of all created tokens
    address[] public allTokens;

    /// @notice Mapping to prevent duplicate token names/symbols
    mapping(string => bool) public usedNames;
    mapping(string => bool) public usedSymbols;

    // ============ Events ============

    event TokenCreated(
        address indexed tokenAddress,
        address indexed creator,
        string name,
        string symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        uint256 timestamp
    );

    event TokenVerified(
        address indexed tokenAddress,
        address indexed verifier,
        uint256 timestamp
    );

    event CreationFeeUpdated(uint256 oldFee, uint256 newFee, uint256 timestamp);

    event PlatformFeesWithdrawn(
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );

    // ============ Errors ============

    error InvalidName();
    error InvalidSymbol();
    error InvalidDescription();
    error InvalidSupply();
    error InvalidAddress();
    error InsufficientCreationFee();
    error TokenAlreadyExists();
    error NameAlreadyUsed();
    error SymbolAlreadyUsed();
    error TransferFailed();
    error NoFeesToWithdraw();
    error TokenNotFound();

    // ============ Modifiers ============

    modifier validTokenCreation(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        string memory description
    ) {
        if (bytes(name).length == 0 || bytes(name).length > MAX_NAME_LENGTH) {
            revert InvalidName();
        }
        if (
            bytes(symbol).length == 0 ||
            bytes(symbol).length > MAX_SYMBOL_LENGTH
        ) {
            revert InvalidSymbol();
        }
        if (
            bytes(description).length == 0 ||
            bytes(description).length > MAX_DESCRIPTION_LENGTH
        ) {
            revert InvalidDescription();
        }
        if (
            initialSupply < MIN_INITIAL_SUPPLY ||
            initialSupply > MAX_INITIAL_SUPPLY
        ) {
            revert InvalidSupply();
        }
        if (maxSupply != 0 && maxSupply < initialSupply) {
            revert InvalidSupply();
        }
        if (usedNames[name]) {
            revert NameAlreadyUsed();
        }
        if (usedSymbols[symbol]) {
            revert SymbolAlreadyUsed();
        }
        _;
    }

    // ============ Constructor ============

    constructor(address platformFeeRecipient_) Ownable(msg.sender) {
        if (platformFeeRecipient_ == address(0)) revert InvalidAddress();

        platformFeeRecipient = platformFeeRecipient_;
        creationFee = CREATION_FEE;
    }

    // ============ External Functions ============

    /**
     * @notice Create a new project token
     * @param name Token name
     * @param symbol Token symbol
     * @param initialSupply Initial token supply
     * @param maxSupply Maximum token supply (0 = no limit)
     * @param description Project description
     * @return tokenAddress Address of the created token
     */
    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        string memory description
    )
        external
        payable
        nonReentrant
        whenNotPaused
        validTokenCreation(name, symbol, initialSupply, maxSupply, description)
        returns (address tokenAddress)
    {
        if (msg.value < creationFee) {
            revert InsufficientCreationFee();
        }

        // Create deterministic address using CREATE2
        bytes32 salt = keccak256(
            abi.encodePacked(
                msg.sender,
                name,
                symbol,
                block.timestamp,
                totalTokensCreated
            )
        );

        bytes memory bytecode = abi.encodePacked(
            type(ProjectToken).creationCode,
            abi.encode(
                name,
                symbol,
                initialSupply,
                maxSupply,
                msg.sender,
                platformFeeRecipient,
                description
            )
        );

        assembly {
            tokenAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        if (tokenAddress == address(0)) revert TokenAlreadyExists();

        // Record token creation
        creatorTokens[msg.sender].push(tokenAddress);
        tokenCreator[tokenAddress] = msg.sender;
        tokenCreationTime[tokenAddress] = block.timestamp;
        allTokens.push(tokenAddress);

        // Mark name and symbol as used
        usedNames[name] = true;
        usedSymbols[symbol] = true;

        totalTokensCreated++;

        // Refund excess payment
        if (msg.value > creationFee) {
            payable(msg.sender).transfer(msg.value - creationFee);
        }

        emit TokenCreated(
            tokenAddress,
            msg.sender,
            name,
            symbol,
            initialSupply,
            maxSupply,
            block.timestamp
        );
    }

    /**
     * @notice Predict the address of a token before creation
     * @param creator Address of the token creator
     * @param name Token name
     * @param symbol Token symbol
     * @param timestamp Creation timestamp
     * @param nonce Creation nonce
     * @return predictedAddress The predicted token address
     */
    function predictTokenAddress(
        address creator,
        string memory name,
        string memory symbol,
        uint256 timestamp,
        uint256 nonce
    ) external view returns (address predictedAddress) {
        bytes32 salt = keccak256(
            abi.encodePacked(creator, name, symbol, timestamp, nonce)
        );

        bytes memory bytecode = abi.encodePacked(
            type(ProjectToken).creationCode,
            abi.encode(
                name,
                symbol,
                0, // initialSupply placeholder
                0, // maxSupply placeholder
                creator,
                platformFeeRecipient,
                "" // description placeholder
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );

        predictedAddress = address(uint160(uint256(hash)));
    }

    /**
     * @notice Verify a token (only owner)
     * @param tokenAddress Address of the token to verify
     */
    function verifyToken(address tokenAddress) external onlyOwner {
        if (tokenCreator[tokenAddress] == address(0)) revert TokenNotFound();

        isVerifiedToken[tokenAddress] = true;
        emit TokenVerified(tokenAddress, msg.sender, block.timestamp);
    }

    /**
     * @notice Update creation fee (only owner)
     * @param newFee New creation fee amount
     */
    function updateCreationFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = creationFee;
        creationFee = newFee;
        emit CreationFeeUpdated(oldFee, newFee, block.timestamp);
    }

    /**
     * @notice Withdraw platform fees (only owner)
     * @param recipient Address to send fees to
     */
    function withdrawPlatformFees(address recipient) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();

        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFeesToWithdraw();

        (bool success, ) = recipient.call{value: balance}("");
        if (!success) revert TransferFailed();

        emit PlatformFeesWithdrawn(recipient, balance, block.timestamp);
    }

    /**
     * @notice Pause token creation (only owner)
     */
    function pauseCreation() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause token creation (only owner)
     */
    function unpauseCreation() external onlyOwner {
        _unpause();
    }

    // ============ View Functions ============

    /**
     * @notice Get tokens created by a specific creator
     * @param creator Address of the creator
     * @return tokens Array of token addresses
     */
    function getCreatorTokens(
        address creator
    ) external view returns (address[] memory tokens) {
        return creatorTokens[creator];
    }

    /**
     * @notice Get total number of tokens created by a creator
     * @param creator Address of the creator
     * @return count Number of tokens created
     */
    function getCreatorTokenCount(
        address creator
    ) external view returns (uint256 count) {
        return creatorTokens[creator].length;
    }

    /**
     * @notice Get all created tokens
     * @return tokens Array of all token addresses
     */
    function getAllTokens() external view returns (address[] memory tokens) {
        return allTokens;
    }

    /**
     * @notice Get token information
     * @param tokenAddress Address of the token
     * @return creator Token creator address
     * @return creationTime Token creation timestamp
     * @return verified Whether the token is verified
     */
    function getTokenInfo(
        address tokenAddress
    )
        external
        view
        returns (address creator, uint256 creationTime, bool verified)
    {
        return (
            tokenCreator[tokenAddress],
            tokenCreationTime[tokenAddress],
            isVerifiedToken[tokenAddress]
        );
    }

    /**
     * @notice Check if a name is available
     * @param name Token name to check
     * @return available Whether the name is available
     */
    function isNameAvailable(
        string memory name
    ) external view returns (bool available) {
        return !usedNames[name];
    }

    /**
     * @notice Check if a symbol is available
     * @param symbol Token symbol to check
     * @return available Whether the symbol is available
     */
    function isSymbolAvailable(
        string memory symbol
    ) external view returns (bool available) {
        return !usedSymbols[symbol];
    }

    /**
     * @notice Get factory statistics
     * @return totalTokens Total number of tokens created
     * @return currentFee Current creation fee
     * @return contractBalance Contract balance
     */
    function getFactoryStats()
        external
        view
        returns (
            uint256 totalTokens,
            uint256 currentFee,
            uint256 contractBalance
        )
    {
        return (totalTokensCreated, creationFee, address(this).balance);
    }

    // ============ Receive Function ============

    /**
     * @notice Receive function to accept ETH
     */
    receive() external payable {
        // Allow direct ETH deposits
    }
}
