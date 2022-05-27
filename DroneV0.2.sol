// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Drone is ERC721Enumerable, Ownable, ReentrancyGuard 
{
    using SafeMath for uint256;
    using ECDSA for bytes32;

    string public baseUri = "https://gateway.pinata.cloud/ipfs/";
    bool public mintEnabled = false;
    uint public totalMinted = 0;
    uint public mintSupplyCount;
    uint private ownerMintReserveCount;
    uint private ownerMintCount;
    uint private maxMintPerAddress;
    uint public whitelistAddressCount = 0;
    uint public whitelistMintCount = 0;
    uint private maxWhitelistCount = 0;


    event ItemListed(address indexed seller,address indexed nftAddress,uint256 indexed tokenId,uint256 price);
    event ItemCanceled(address indexed seller,address indexed nftAddress,uint256 indexed tokenId);
    event ItemBought(address indexed buyer,address indexed nftAddress,uint256 indexed tokenId,uint256 price);    
    
    mapping(address => mapping(uint256 => Listing)) private s_listings;
    mapping(address => uint16) private addressMintCount;
    mapping(address => bool) private whitelist;

    struct Listing {
        uint256 price;
        address seller;
    }

    struct MintData {
        uint _tokenId;
        string _tokenMetadataHash;
    }

    mapping(uint => string) public tokenMetadataHashs;
    mapping(string => uint) private HashToTokenIds;

    constructor(
        uint _mintSupplyCount,
        uint _ownerMintReserveCount,
        uint _maxWhitelistCount,
        uint _maxMintPerAddress) ERC721("Drone", "TB2") {

        require(_ownerMintReserveCount <= _mintSupplyCount);    
        require(_maxMintPerAddress <= _mintSupplyCount);    

        mintSupplyCount = _mintSupplyCount;
        ownerMintReserveCount = _ownerMintReserveCount;
        maxWhitelistCount = _maxWhitelistCount;
        maxMintPerAddress = _maxMintPerAddress;
    }

    modifier tokenExists(uint _tokenId) {
        require(_exists(_tokenId), "This token does not exist.");
    _;
    }

     modifier isNFTListed(uint256 tokenId) {
        Listing memory listing = s_listings[address(this)][tokenId];
        require (listing.price <= 0 ,"This Token is not listed yet");
        _;
    }

    function tokenURI(uint _tokenId) override public view returns (string memory) 
    {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");

        return string(abi.encodePacked(baseUri,tokenMetadataHashs[_tokenId]));      
    }
    
    function setBaseUri(string memory _baseUri) external onlyOwner {
        baseUri = _baseUri;
    }

    function updateMetadataHash(uint _tokenId, string calldata _tokenMetadataHash) tokenExists(_tokenId) external {
        require(_msgSender() == ownerOf(_tokenId), "You are not the owner of this token.");
        require(HashToTokenIds[_tokenMetadataHash] == 0, "This hash has already been assigned.");

        tokenMetadataHashs[_tokenId] = _tokenMetadataHash;
        HashToTokenIds[_tokenMetadataHash] = _tokenId;
    }
    
    function setMintEnabled(bool _enabled) external onlyOwner {
        mintEnabled = _enabled;
    }
    
    // Method to Add user into Whitelist
    function whitelistUser(address _user) public onlyOwner {
        require(!mintEnabled, "Whitelist is not available");
        require(!whitelist[_user], "Your address is already whitelisted");
        require(whitelistAddressCount < maxWhitelistCount, "Whitelist is full");

        whitelistAddressCount++;
        whitelist[_user] = true;
    }
    
    // Method to remove user into Whitelist
    function removeWhitelistUser(address _user) public onlyOwner {
        require(!mintEnabled, "Whitelist is not available");
        require(whitelistAddressCount > 0, "The Whitelist is empty");
        whitelist[_user] = false;
        whitelistAddressCount--;
    }

    // Security     
    function verifyOwnerSignature(bytes32 hash, bytes memory signature) private view returns(bool) {
        return hash.toEthSignedMessageHash().recover(signature) == owner();
    }

// bytes calldata _signature 

    function mintSingleLand(MintData calldata _mintData) external nonReentrant {
        //require(verifyOwnerSignature(keccak256(abi.encode(_mintData)), _signature), "Invalid Signature");
        require(_mintData._tokenId >= 0 && _mintData._tokenId <= mintSupplyCount, "Invalid token id.");
        require(mintEnabled, "Minting unavailable");
        require(totalMinted < mintSupplyCount, "All tokens minted");
        require(bytes(_mintData._tokenMetadataHash).length > 0, "No hash or address provided");
        require(whitelist[msg.sender] == true ,"This address is not WhiteListed");


        if (_msgSender() != owner()) {
        require(addressMintCount[_msgSender()] < maxMintPerAddress,"You cannot mint more.");
        require(totalMinted + (ownerMintReserveCount - ownerMintCount) < mintSupplyCount,"Available tokens minted");

        // remaining mints are enough to cover remaining whitelist.
        require(
            (
                whitelist[_msgSender()] ||
                (
                totalMinted +
                (ownerMintReserveCount - ownerMintCount) +
                ((whitelistAddressCount - whitelistMintCount) * 2)
                < mintSupplyCount
                )
            ),
            "Only whitelist tokens available"
            );
        } 
        else {
            require(ownerMintCount < ownerMintReserveCount, "Owner mint limit");
        }

        tokenMetadataHashs[_mintData._tokenId] = _mintData._tokenMetadataHash;
        HashToTokenIds[_mintData._tokenMetadataHash] = _mintData._tokenId;

        addressMintCount[_msgSender()]++;
        totalMinted++;

        if (whitelist[_msgSender()]) {
        whitelistMintCount++;
        }

        if (_msgSender() == owner()) {
            ownerMintCount++;
        }

        _safeMint(_msgSender(), _mintData._tokenId);
    }

// bytes calldata _signature 

    function mintmultipleLand( MintData[] calldata _mintData ) external nonReentrant {  
        for (uint i =0 ; i < _mintData.length ; i++)
        {  
            //require(verifyOwnerSignature(keccak256(abi.encodePacked(_mintData)), _signature), "Invalid Signature");
            require(_mintData[i]._tokenId >= 0 && _mintData[i]._tokenId <= mintSupplyCount, "Invalid token id.");
            require(mintEnabled, "Minting unavailable");
            require(totalMinted < mintSupplyCount, "All tokens minted");
            require(bytes(_mintData[i]._tokenMetadataHash).length > 0, "No hash or address provided");

            if (_msgSender() != owner()) {
                require(addressMintCount[_msgSender()] < maxMintPerAddress, "You cannot mint more.");
                require(totalMinted + (ownerMintReserveCount - ownerMintCount) < mintSupplyCount, "Available tokens minted");

                // make sure remaining mints are enough to cover remaining whitelist.
                require(
                        (
                            whitelist[_msgSender()] ||
                            (
                            totalMinted +
                            (ownerMintReserveCount - ownerMintCount) +
                            ((whitelistAddressCount - whitelistMintCount) * 2)
                            < mintSupplyCount
                            )
                        ),
                        "Only whitelist tokens available"
                );
            } 
            else {
                require(ownerMintCount < ownerMintReserveCount, "Owner mint limit");
            }

            tokenMetadataHashs[_mintData[i]._tokenId] = _mintData[i]._tokenMetadataHash;
            HashToTokenIds[_mintData[i]._tokenMetadataHash] = _mintData[i]._tokenId;
            
            addressMintCount[_msgSender()]++;
            totalMinted++;

            if (whitelist[_msgSender()]) {
            whitelistMintCount++;
            }

            if (_msgSender() == owner()) {
                ownerMintCount++;
            }

            _safeMint(_msgSender(), _mintData[i]._tokenId);
        }   
    }

    function putNFTonSale(uint256 _tokenId,uint256 price) external 
      //  notListed(nftAddress, tokenId, msg.sender)
    {
        require(ownerOf(_tokenId) == msg.sender, "you are not owner of this token"); 
        require(price > 0 ,"The price must be above zero");
        s_listings[address(this)][_tokenId] = Listing(price, msg.sender);
        emit ItemListed(msg.sender, address(this), _tokenId, price);
    }

    function getListing(uint256 tokenId)external view returns (Listing memory)
    {
        return s_listings[address(this)][tokenId];
    }

    function putNFTonNotForSale( uint256 _tokenId) external
      //   isNFTListed(_tokenId)
    {
        require(ownerOf(_tokenId) == msg.sender, "you are not owner of this token"); 
        delete (s_listings[address(this)][_tokenId]);
        emit ItemCanceled(msg.sender, address(this), _tokenId);
    }

    function buyItem( uint256 _tokenId)  payable external
       // isNFTListed( _tokenId)
        
    {
        Listing memory listedItem = s_listings[address(this)][_tokenId];
        require (msg.value >= listedItem.price , "You cant buy at lower price");

         delete (s_listings[address(this)][_tokenId]);
        _safeTransfer(listedItem.seller, msg.sender, _tokenId ,"");
        emit ItemBought(msg.sender, address(this), _tokenId, listedItem.price);
    }

    function updateListing(uint256 _tokenId,uint256 newPrice) external
     //   isNFTListed( _tokenId)
        nonReentrant
    {
        require(ownerOf(_tokenId) == msg.sender, "you are not owner of this token"); 
        require(newPrice == 0,"New price must be above than 0");

        s_listings[address(this)][_tokenId].price = newPrice;
        emit ItemListed(msg.sender, address(this), _tokenId, newPrice);
    }
    
            
/* 
For single mint

[1,"QmT757cQUpNSNaEyDYYv5No7GzRogF3bnTGYxRS98EMcwt"]
[2,"QmT757cQUpNSNaEyDYYv5No7GzRogF3bnTGYxRS98EMcwt"]


For multiple Mint

[[1,"QmT757cQUpNSNaEyDYYv5No7GzRogF3bnTGYxRS98EMcwt"],[2,"QmT757cQUpNSNaEyDYYv5No7GzRogF3bnTGYxRS98EMcwt"]]

*/
}







