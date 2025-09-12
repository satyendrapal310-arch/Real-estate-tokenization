// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Real Estate Tokenization
 * @dev Smart contract for tokenizing real estate properties into fractional ownership
 * @author Real Estate Tokenization Team
 */
contract Project is ERC20, Ownable, ReentrancyGuard {
    
    // Property structure
    struct Property {
        uint256 propertyId;
        string propertyAddress;
        uint256 totalValue;
        uint256 totalTokens;
        bool isActive;
        address propertyOwner;
        uint256 createdAt;
    }
    
    // State variables
    mapping(uint256 => Property) public properties;
    mapping(uint256 => mapping(address => uint256)) public propertyTokenBalances;
    mapping(address => uint256[]) public investorProperties;
    
    uint256 public propertyCounter;
    uint256 public constant TOKENS_PER_ETH = 1000; // 1 ETH = 1000 tokens
    
    // Events
    event PropertyTokenized(
        uint256 indexed propertyId,
        string propertyAddress,
        uint256 totalValue,
        uint256 totalTokens,
        address indexed owner
    );
    
    event TokensPurchased(
        uint256 indexed propertyId,
        address indexed buyer,
        uint256 tokenAmount,
        uint256 ethAmount
    );
    
    event TokensTransferred(
        uint256 indexed propertyId,
        address indexed from,
        address indexed to,
        uint256 tokenAmount
    );
    
    constructor() ERC20("RealEstateToken", "RET") Ownable(msg.sender) {}
    
    /**
     * @dev Core Function 1: Tokenize a real estate property
     * @param _propertyAddress Physical address of the property
     * @param _totalValue Total value of the property in wei
     * @param _totalTokens Total tokens to be created for this property
     */
    function tokenizeProperty(
        string memory _propertyAddress,
        uint256 _totalValue,
        uint256 _totalTokens
    ) external returns (uint256) {
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_totalValue > 0, "Property value must be greater than 0");
        require(_totalTokens > 0, "Total tokens must be greater than 0");
        
        propertyCounter++;
        uint256 newPropertyId = propertyCounter;
        
        // Create property
        properties[newPropertyId] = Property({
            propertyId: newPropertyId,
            propertyAddress: _propertyAddress,
            totalValue: _totalValue,
            totalTokens: _totalTokens,
            isActive: true,
            propertyOwner: msg.sender,
            createdAt: block.timestamp
        });
        
        // Mint tokens to property owner initially
        _mint(msg.sender, _totalTokens);
        propertyTokenBalances[newPropertyId][msg.sender] = _totalTokens;
        investorProperties[msg.sender].push(newPropertyId);
        
        emit PropertyTokenized(
            newPropertyId,
            _propertyAddress,
            _totalValue,
            _totalTokens,
            msg.sender
        );
        
        return newPropertyId;
    }
    
    /**
     * @dev Core Function 2: Purchase property tokens with ETH
     * @param _propertyId ID of the property to invest in
     * @param _tokenAmount Number of tokens to purchase
     */
    function purchasePropertyTokens(
        uint256 _propertyId,
        uint256 _tokenAmount
    ) external payable nonReentrant {
        require(_propertyId <= propertyCounter && _propertyId > 0, "Invalid property ID");
        require(properties[_propertyId].isActive, "Property is not active");
        require(_tokenAmount > 0, "Token amount must be greater than 0");
        
        Property storage property = properties[_propertyId];
        
        // Calculate required ETH based on property value and token ratio
        uint256 tokenPrice = property.totalValue / property.totalTokens;
        uint256 requiredEth = _tokenAmount * tokenPrice;
        
        require(msg.value >= requiredEth, "Insufficient ETH sent");
        require(balanceOf(property.propertyOwner) >= _tokenAmount, "Not enough tokens available");
        
        // Transfer tokens from property owner to buyer
        _transfer(property.propertyOwner, msg.sender, _tokenAmount);
        
        // Update property token balances
        propertyTokenBalances[_propertyId][property.propertyOwner] -= _tokenAmount;
        propertyTokenBalances[_propertyId][msg.sender] += _tokenAmount;
        
        // Add property to investor's list if first purchase
        if (propertyTokenBalances[_propertyId][msg.sender] == _tokenAmount) {
            investorProperties[msg.sender].push(_propertyId);
        }
        
        // Transfer ETH to property owner
        payable(property.propertyOwner).transfer(requiredEth);
        
        // Refund excess ETH
        if (msg.value > requiredEth) {
            payable(msg.sender).transfer(msg.value - requiredEth);
        }
        
        emit TokensPurchased(_propertyId, msg.sender, _tokenAmount, requiredEth);
    }
    
    /**
     * @dev Core Function 3: Transfer property tokens between addresses
     * @param _propertyId ID of the property
     * @param _to Address to transfer tokens to
     * @param _tokenAmount Number of tokens to transfer
     */
    function transferPropertyTokens(
        uint256 _propertyId,
        address _to,
        uint256 _tokenAmount
    ) external nonReentrant {
        require(_propertyId <= propertyCounter && _propertyId > 0, "Invalid property ID");
        require(_to != address(0), "Cannot transfer to zero address");
        require(_to != msg.sender, "Cannot transfer to yourself");
        require(_tokenAmount > 0, "Token amount must be greater than 0");
        require(propertyTokenBalances[_propertyId][msg.sender] >= _tokenAmount, "Insufficient token balance");
        
        // Transfer tokens
        _transfer(msg.sender, _to, _tokenAmount);
        
        // Update property token balances
        propertyTokenBalances[_propertyId][msg.sender] -= _tokenAmount;
        propertyTokenBalances[_propertyId][_to] += _tokenAmount;
        
        // Add property to recipient's list if first time receiving
        if (propertyTokenBalances[_propertyId][_to] == _tokenAmount) {
            investorProperties[_to].push(_propertyId);
        }
        
        emit TokensTransferred(_propertyId, msg.sender, _to, _tokenAmount);
    }
    
    // View functions
    function getProperty(uint256 _propertyId) external view returns (Property memory) {
        require(_propertyId <= propertyCounter && _propertyId > 0, "Invalid property ID");
        return properties[_propertyId];
    }
    
    function getPropertyTokenBalance(uint256 _propertyId, address _investor) external view returns (uint256) {
        return propertyTokenBalances[_propertyId][_investor];
    }
    
    function getInvestorProperties(address _investor) external view returns (uint256[] memory) {
        return investorProperties[_investor];
    }
    
    function getPropertyCount() external view returns (uint256) {
        return propertyCounter;
    }
    
    // Owner functions
    function deactivateProperty(uint256 _propertyId) external onlyOwner {
        require(_propertyId <= propertyCounter && _propertyId > 0, "Invalid property ID");
        properties[_propertyId].isActive = false;
    }
    
    function activateProperty(uint256 _propertyId) external onlyOwner {
        require(_propertyId <= propertyCounter && _propertyId > 0, "Invalid property ID");
        properties[_propertyId].isActive = true;
    }
}
