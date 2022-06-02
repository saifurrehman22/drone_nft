// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Drone1 is ERC721Enumerable, Ownable, ReentrancyGuard 
{
    error PriceNotMet(uint256 tokenId, uint256 price);
    error PriceMustBeAboveZero();
    error NotOwner();
    error InvalidMetadataHash();
    error InvalidTokenId();
    error MintDisable();
    error NotWhitelistedAdmin();
    error AllTokkensMinted();
    error TokenNotExit();

    uint tokenId;
    uint public totalMinted;
    uint public mintSupplyCount;
    string public baseUri;
    bool public mintEnabled;
    
    mapping(uint256 => Drone) public drones;
    mapping (address => bool) public whitelistAdmins;

    struct Drone {
        uint256 price;
        address seller;
        bool listedOnSale;
        string tokenMetadataHashs;
    }

    struct returnDrone {
        uint256 price;
        address seller;
    }

    event TokenListedForSale(
        uint256 tokenId,
        address seller,
        uint256 price);

    event CancelTokenForListing(
        uint256 tokenId,
        address seller);

    event TokenBought(
        uint256 tokenId,
        address buyer,
        uint256 price);  

    event UpdatedTokenOnSale(
        uint256 tokenId,
        address seller,
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
        baseUri = "https://gateway.pinata.cloud/ipfs/";
    }

    modifier tokenExists(uint _tokenId) {
        require(_exists(_tokenId), "This token does not exist.");
    _;
    }

    modifier isListed(uint256 _tokenId) {
        require (drones[_tokenId].listedOnSale ,"This Token is not listed yet");
        _;
    }

    modifier isOwner(uint256 _tokenId,address _spender) {
        address owner = ownerOf(_tokenId);
        if (_spender != owner) {
            revert NotOwner();
        }
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
        if (!_exists(_tokenId)) {
            revert TokenNotExit();
        }
        return string(abi.encodePacked(baseUri,drones[_tokenId].tokenMetadataHashs));      
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
        isOwner(_tokenId, msg.sender)
        external {
        drones[_tokenId]=Drone(drones[_tokenId].price,drones[_tokenId].seller,drones[_tokenId].listedOnSale,_tokenMetadataHash);
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
        uint256 _tokenId = tokenId;
        tokenId++;
        if (bytes(_tokenMetadataHash).length != 46) {
            revert InvalidMetadataHash();
        }
        if (_tokenId < 0 && _tokenId > mintSupplyCount) {
            revert InvalidTokenId();
        }
        if (!mintEnabled) {
            revert MintDisable();
        }
        if (totalMinted >= mintSupplyCount) {
            revert AllTokkensMinted();
        }
        if (!whitelistAdmins[msg.sender]) {
            revert NotWhitelistedAdmin();
        }

        drones[_tokenId]=Drone(drones[_tokenId].price,drones[_tokenId].seller,drones[_tokenId].listedOnSale,_tokenMetadataHash);
        totalMinted++;

        _safeMint(msg.sender, _tokenId);
    }

    /**
     * @dev listToken is used to list a new token.
     * Requirement:
     * - This function can only called by owner of the token
     *
     * @param _tokenId - Token Id 
     * @param _price - Price of the Token
     * Emits a {TokenListedForSale} event when player address is new.
     */

    function listToken(
        uint256 _tokenId,
        uint256 _price) 
        external
        isOwner(_tokenId, msg.sender) 
    {
        if (_price <= 0) {
            revert PriceMustBeAboveZero();
        }        
        drones[_tokenId] = Drone(_price,msg.sender,true,drones[_tokenId].tokenMetadataHashs);
        emit TokenListedForSale(_tokenId,msg.sender,_price);
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
    returns (Drone memory)
    {
        return drones[_tokenId];
    }

    /**
     * @dev cancelTokenListing is used to remove token from listng.
     * Requirement:
     * - This function can only called by owner of the token
     *
     * @param _tokenId - Token Id 
     * Emits a {CancelTokenForListing} event when player address is new.
     */

    function cancelTokenListing(uint256 _tokenId) 
    external
    isListed(_tokenId)
    isOwner(_tokenId, msg.sender)
    {
        delete (drones[_tokenId]);
        emit CancelTokenForListing(_tokenId,msg.sender);
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
        Drone memory listedItem = drones[_tokenId];
        if (msg.value < listedItem.price) {
            revert PriceNotMet(_tokenId, listedItem.price);
        }
         delete (drones[_tokenId]);
        _safeTransfer(listedItem.seller, msg.sender, _tokenId ,"");
        emit TokenBought(_tokenId,msg.sender,listedItem.price);
    }

    /**
     * @dev updateTokenListing is used to update the price of a token.
     * Requirement:
     * - This function can only called by owner of the token

     * @param _tokenId - Token Id 
     * @param _newPrice - Price of the Token
     * Emits a {UpdatedTokenOnSale} event when player address is new.
     */

    function updateTokenListing(
        uint256 _tokenId,
        uint256 _newPrice) 
    external
    isListed( _tokenId)
    isOwner(_tokenId, msg.sender)
    nonReentrant
    {
        if (_newPrice == 0) {
            revert PriceMustBeAboveZero();
        }        
        drones[_tokenId].price = _newPrice;
        emit UpdatedTokenOnSale(_tokenId,msg.sender,_newPrice);
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
 
    function getOwnedNfts() 
    public 
    view 
    returns(returnDrone[] memory){
        returnDrone[] memory items= new returnDrone[](totalSupply());
        for (uint i=0; i<totalSupply(); i++){
            items[i].seller=drones[i].seller;
            items[i].price=drones[i].price;
        }
    return items;
    }
}
