// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error PriceNotMet(uint256 tokenId, uint256 price);
error PriceMustBeAboveZero();

contract Drone is ERC721Enumerable, Ownable, ReentrancyGuard 
{
    using SafeMath for uint256;
    using ECDSA for bytes32;
    uint tokenIdCounter;

    string public baseUri = "https://gateway.pinata.cloud/ipfs/";
    bool public mintEnabled;
    uint public totalMinted;
    uint public mintSupplyCount;
    
    mapping(uint256 => Listing) public listings;
    mapping(address => uint16) private addressMintCount;
    mapping(uint => string) public tokenMetadataHashs;
    mapping (address => bool) public whitelistAdmins;

    struct Listing {
        uint256 price;
        address seller;
        bool listed;
    }

    event TokenListed(
        address  seller,
        address  tokenAddress,
        uint256  tokenId,
        uint256 price);

    event CancelTokenList(
        address  seller,
        address  tokenAddress,
        uint256  tokenId);

    event TokenBought(
        address  buyer,
        address  tokenAddress,
        uint256  tokenId,
        uint256 price);  

    event UpdatedToken(
        address  seller,
        address  tokenAddress,
        uint256  tokenId,
        uint256 price);

    event WhitelistAdmin(
        address whitelistedAddress,
        address addedBy
    );

    event RemovedWhitelistAdmin(
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
        mintEnabled =false;
    }

    modifier tokenExists(uint _tokenId) {
        require(_exists(_tokenId), "This token does not exist.");
    _;
    }

     modifier isListed(uint256 _tokenId) {
        Listing memory listing = listings[_tokenId];
        require (listing.listed ,"This Token is not listed yet");
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
        require(msg.sender == ownerOf(_tokenId), "You are not the owner of this token.");
        tokenMetadataHashs[_tokenId] = _tokenMetadataHash;
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
     * @dev mint is used to create a new token.
     * Requirement:     

     * @param _tokenMetadataHash - token metadata 
     */

    function mint(string memory _tokenMetadataHash) 
    external 
    nonReentrant {
        uint256 tokenId = tokenIdCounter;
        tokenIdCounter++;
        require(bytes(_tokenMetadataHash).length == 46, "Invalid IPFS Hash");
        require(tokenId >= 0 && tokenId <= mintSupplyCount, "Invalid token id.");
        require(mintEnabled, "Minting unavailable");
        require(totalMinted < mintSupplyCount, "All tokens minted");
        require(bytes(_tokenMetadataHash).length > 0, "No hash or address provided");
        require (whitelistAdmins[msg.sender], "You dont have access to whitelist" );

        tokenMetadataHashs[tokenId] = _tokenMetadataHash;
        addressMintCount[msg.sender]++;
        totalMinted++;

        _safeMint(msg.sender, tokenId);
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
        if (_price <= 0) {
            revert PriceMustBeAboveZero();
        }        
        require(ownerOf(_tokenId) == msg.sender, "you are not owner of this token"); 
        require(_price > 0 ,"The price must be above zero");
        listings[_tokenId] = Listing(_price, msg.sender,true);
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
        return listings[_tokenId];
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
        delete (listings[_tokenId]);
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
    isListed(_tokenId)      
    {
        Listing memory listedItem = listings[_tokenId];
        if (msg.value < listedItem.price) {
            revert PriceNotMet(_tokenId, listedItem.price);
        }
         delete (listings[_tokenId]);
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
        if (_newPrice == 0) {
            revert PriceMustBeAboveZero();
        }        
        listings[_tokenId].price = _newPrice;
        emit UpdatedToken(msg.sender, address(this), _tokenId, _newPrice);
    }

    /**
     * @dev whitelistAdmin is used to whitelsit admin account.
     * Requirement:
     * - This function can only called by owner of the contract

     * @param _account - Account to be whitelisted 
     * Emits a {WhitelistAdmin} event when player address is new.
     */

    function whitelistAdmin(address _account) 
    external 
    onlyOwner {
        whitelistAdmins[_account] = true;
        emit WhitelistAdmin(_account, msg.sender);     
    }

    /**
     * @dev removeWhitelistAdmin is used to whitelsit admin account.
     * Requirement:
     * - This function can only called by owner of the contract

     * @param _account - Account to be whitelisted 
     * Emits a {RemovedWhitelistAdmin} event when player address is new.
     */

    function removeWhitelistAdmin(address _account) 
    external 
    onlyOwner {
        delete (whitelistAdmins[_account]);
        emit RemovedWhitelistAdmin(_account, msg.sender);
    }

    //Get Total Owner Address

    function GetTotalNft(address _address)
    public 
    view 
    returns (uint[] memory)
    {
        uint[] memory tokenIds = new uint[](totalSupply());
        for (uint256 i=0; i < totalSupply(); i++) {
        tokenIds[i] = balanceOf(_address);
        }
        return tokenIds;
    } 
}
