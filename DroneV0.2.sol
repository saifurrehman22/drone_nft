// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Drone is ERC721Enumerable, Ownable, ReentrancyGuard 
{
    using SafeMath for uint256;
    using ECDSA for bytes32;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    string public baseUri = "https://gateway.pinata.cloud/ipfs/";
    bool public mintEnabled = false;
    uint public totalMinted = 0;
    uint public mintSupplyCount;
    uint public whitelistAddressCount = 0;
    
    mapping(address => mapping(uint256 => Listing)) private listings;
    mapping(address => uint16) private addressMintCount;
    mapping(address => bool) private whitelist;
    mapping(uint => string) public tokenMetadataHashs;
    mapping(string => uint) private HashToTokenIds;

    struct Listing {
        uint256 price;
        address seller;
    }

    event TokenListed(
        address indexed seller,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 price);

    event CancelTokenList(
        address indexed seller,
        address indexed tokenAddress,
        uint256 indexed tokenId);

    event TokenBought(
        address indexed buyer,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 price);  

    event AddedWhitelistAddress(
        address whitelistedAddress,
        address addedBy
    );

    event RemovedWhitelistAddress(
        address whitelistedAddress,
        address addedBy
    );

    event SetBaseURI(
        string baseURI,
        address addedBy
    );

    event UpdateMetadata(
        uint tokenId,
        string newHash,
        address updatedBy
    );

    constructor(uint _mintSupplyCount) ERC721("Drone", "TB2") {
        mintSupplyCount = _mintSupplyCount;
    }

    modifier tokenExists(uint _tokenId) {
        require(_exists(_tokenId), "This token does not exist.");
    _;
    }

     modifier isListed(uint256 _tokenId) {
        Listing memory listing = listings[address(this)][_tokenId];
        require (listing.price > 0 ,"This Token is not listed yet");
        _;
    }

    /**
     * @dev tokenURI is used to get TokenUri link.
     *
     * @param _tokenId - ID of Token
     *
     * @return string .
     */

    function tokenURI(uint _tokenId) 
    override
    public 
    view 
    returns (string memory) 
    {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(baseUri,tokenMetadataHashs[_tokenId]));      
    }

    /**
     * @dev setBaseUri is used to set BaseURI.
     * Requirement:
     * - This function can only called by owner of contract
     *
     * @param _baseUri - New baseURI
     * Emits a {UpdatedBaseURI} event.
     */

    function setBaseUri(string memory _baseUri) 
    external onlyOwner {
        baseUri = _baseUri;
        emit SetBaseURI(_baseUri, msg.sender);
    }

    /**
     * @dev updateMetadataHash is used to update the metadata of a token.
     * Requirement:
     * - This function can only called by owner of the token

     * @param _tokenId - Token Id 
     * @param _tokenMetadataHash - New Metadata
     * Emits a {UpdateMetadata} event.
     */

    function updateMetadataHash(
        uint _tokenId, 
        string calldata _tokenMetadataHash) 
        tokenExists(_tokenId) 
        external {
        require(_msgSender() == ownerOf(_tokenId), "You are not the owner of this token.");
        require(HashToTokenIds[_tokenMetadataHash] == 0, "This hash has already been assigned.");
        tokenMetadataHashs[_tokenId] = _tokenMetadataHash;
        HashToTokenIds[_tokenMetadataHash] = _tokenId;
        emit UpdateMetadata(_tokenId,_tokenMetadataHash,msg.sender);
    }

    /**
     * @dev setMintEnabled is used to start minitng  of a tokens.
     * Requirement:
     * - This function can only called by owner of the Contract

     * @param _enabled - Token Id 
     */
    
    function setMintEnabled(bool _enabled) 
    external 
    onlyOwner {
        mintEnabled = _enabled;
    }
    
    /**
     * @dev addWhitelistedAddress is used to add address in whitelist mapping.
     * Requirement:
     * - This function can only called by owner of contract
     *
     * @param _whitelistAddress - New whitelist address
     * Emits a {AddedWhitelistAddress} event.
     */

    function whitelistUser(address _whitelistAddress) 
    public 
    onlyOwner {
        require(!mintEnabled, "Whitelist is not available");
        require(!whitelist[_whitelistAddress], "Your address is already whitelisted");
        whitelistAddressCount++;
        whitelist[_whitelistAddress] = true;
        emit AddedWhitelistAddress(_whitelistAddress, msg.sender);
    }

    /**
     * @dev removeWhitelistedAddress is used to remove address from whitelist mapping.
     * Requirement:
     * - This function can only called by owner of contract
     *
     * @param _whitelistAddress - Remove whitelist address
     * Emits a {RemovedWhitelistAddress} event.
     */
    
    function removeWhitelistUser(address _whitelistAddress) 
    public 
    onlyOwner {
        require(!mintEnabled, "Whitelist is not available");
        require(whitelistAddressCount > 0, "The Whitelist is empty");
        whitelist[_whitelistAddress] = false;
        whitelistAddressCount--;
        emit RemovedWhitelistAddress(_whitelistAddress, msg.sender);
    }

    /**
     * @dev mint is used to create a new token.
     * Requirement:     

     * @param _tokenMetadataHash - token metadata 
     */

    function mint(string memory _tokenMetadataHash) 
    external 
    nonReentrant {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        require(tokenId >= 0 && tokenId <= mintSupplyCount, "Invalid token id.");
        require(mintEnabled, "Minting unavailable");
        require(totalMinted < mintSupplyCount, "All tokens minted");
        require(bytes(_tokenMetadataHash).length > 0, "No hash or address provided");
        require(whitelist[msg.sender] == true ,"This address is not WhiteListed");

        tokenMetadataHashs[tokenId] = _tokenMetadataHash;
        HashToTokenIds[_tokenMetadataHash] = tokenId;
        addressMintCount[_msgSender()]++;
        totalMinted++;

        _safeMint(_msgSender(), tokenId);
    }

    /**
     * @dev listToken is used to list a new token.
     * Requirement:
     * - This function can only called by owner of the token
     *
     * @param _tokenId - Token Id 
     * @param _price - Price of the Token
     * Emits a {TokenListed} event when player address is new.
     */

    function listToken(
        uint256 _tokenId,
        uint256 _price) 
        external 
    {
        Listing memory listing = listings[address(this)][_tokenId];
        require (listing.price <= 0,"Token is already listed");
        require(ownerOf(_tokenId) == msg.sender, "you are not owner of this token"); 
        require(_price > 0 ,"The price must be above zero");
        listings[address(this)][_tokenId] = Listing(_price, msg.sender);
        emit TokenListed(msg.sender, address(this), _tokenId, _price);
    }

    /**
     * @dev getTokenListing is used to get information of listing token.
     *
     * @param _tokenId - ID of Token
     *
     * @return listing Tuple.
     */

    function getTokenListing(uint256 _tokenId)
    external 
    view 
    returns (Listing memory)
    {
        return listings[address(this)][_tokenId];
    }

    /**
     * @dev cancelTokenListing is used to remove token from listng.
     * Requirement:
     * - This function can only called by owner of the token
     *
     * @param _tokenId - Token Id 
     * Emits a {CancelTokenList} event when player address is new.
     */

    function cancelTokenListing(uint256 _tokenId) 
    external
    isListed(_tokenId)
    {
        require(ownerOf(_tokenId) == msg.sender, "you are not owner of this token"); 
        delete (listings[address(this)][_tokenId]);
        emit CancelTokenList(msg.sender, address(this), _tokenId);
    }

    /**
     * @dev buyToken is used to buy token which user has listed.
     * Requirement:
     * - This function can only called by anyone who wants to purchase token
     *
     * @param _tokenId - Token Id 
     * Emits a {TokenBought} event when player address is new.
     */

    function buyToken(uint256 _tokenId)  
    payable 
    external
    isListed( _tokenId)      
    {
        Listing memory listedItem = listings[address(this)][_tokenId];
        require (msg.value >= listedItem.price , "You cant buy at lower price");

         delete (listings[address(this)][_tokenId]);
        _safeTransfer(listedItem.seller, msg.sender, _tokenId ,"");
        emit TokenBought(msg.sender, address(this), _tokenId, listedItem.price);
    }

    /**
     * @dev updateTokenListing is used to update the price of a token.
     * Requirement:
     * - This function can only called by owner of the token

     * @param _tokenId - Token Id 
     * @param _newPrice - Price of the Token
     * Emits a {TokenListed} event when player address is new.
     */

    function updateTokenListing(
        uint256 _tokenId,
        uint256 _newPrice) 
    external
    isListed( _tokenId)
    nonReentrant
    {
        require(ownerOf(_tokenId) == msg.sender, "you are not owner of this token"); 
        require(_newPrice > 0,"New price must be above than 0");
        listings[address(this)][_tokenId].price = _newPrice;
        emit TokenListed(msg.sender, address(this), _tokenId, _newPrice);
    }              
}
