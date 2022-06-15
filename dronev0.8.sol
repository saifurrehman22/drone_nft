// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract DroneContract is ERC721Enumerable, ERC2981, Ownable, ReentrancyGuard 
{
    uint public droneId;
    uint public mintSupplyLimit;
    bool public mintEnabled;
    string public baseUri;

    address[] public whitelistedAddresses;

    struct Drones{
        uint256 price;
        address ownerAddress;
        bool listedOnSale;
        string metadataHash;
    }

    struct ReturnDroneInfo{
        uint256 droneID;
        string metadataHash;
        bool isAdminDrone;
    }

    mapping(uint256 => Drones) public drones;

    error PriceNotMatched(
        uint256 droneId, 
        uint256 price
    );
    error PriceMustBeAboveZero();
    error NotOwnerOfDrone();
    error InvalidMetadataHash();
    error InvaliddroneId();
    error MintingDisabled();
    error NotwhitelistedAdmin();
    error DroneMintSupplyReached();
    error DroneNotExist();
    error OwnerCannotBuyHisOwnDrone();
    error OwnerTransferredTokenExternally();
    error PlayerHoldZeroDrone();
    error NewLimitShouldBeGreaterThanExisting(uint256 existingLimit, uint256 newLimit);

    event UpdatedDroneStatusForSale(
        uint256 droneId,
        address ownerAddress,
        uint256 price
    );

    event UpdatedDroneStatusToNotForSale(
        uint256 droneId,
        address ownerAddress
    );

    event DroneBought(
        uint256 droneId,
        address buyer,
        uint256 price
    );  

    event UpdatedDronePrice(
        uint256 droneId,
        address ownerAddress,
        uint256 price
    );

    event AddedWhitelistAdmin(
        address whitelistedAddress,
        address updatedBy
    );

    event RemovedWhitelistAdmin(
        address whitelistedAddress,
        address updatedBy
    );

    event SetBaseURI(
        string baseURI,
        address addedBy
    );

    event UpdateMetadata(
        uint droneId,
        string newHash,
        address updatedBy
    );

    event MintStatusUpdated(
        bool status,
        address updatedBy
    );

    event DroneMinted(
        uint droneId,
        address ownerAddress,
        string metadataHash
    );

    event DroneRevertedFromSale(
        uint droneId,
        address lastOwnerAddress,
        address newOwnerAddress,
        bool saleStatus
    );

    event MintLimitUpdated(
        uint256 newLimit,
        address updatedBy
    );

    constructor(
        uint _mintSupplyLimit,
        uint96 _royaltyFeesInBips) ERC721("Drones", "TB2") {

        mintSupplyLimit = _mintSupplyLimit;
        mintEnabled = true;
        setRoyaltyInfo(owner(), _royaltyFeesInBips);
        baseUri = "https://gateway.pinata.cloud/ipfs/";

        emit SetBaseURI(baseUri, msg.sender);
    }

    modifier droneExists(uint _droneId) {
        require(_exists(_droneId), "This drone does not exist.");
    _;
    }

    modifier isListedForSale(uint256 _droneId) {
        require (drones[_droneId].listedOnSale ,"This drone is not listed yet");
        _;
    }

    modifier onlyOwnerOfDrone(uint256 _droneId) {
        if (ownerOf(_droneId) != msg.sender) {
            revert NotOwnerOfDrone();
        }
        _;
    }

    modifier notOwnerOfDrone(uint256 _droneId) {
        if (ownerOf(_droneId) == msg.sender) {
            revert OwnerCannotBuyHisOwnDrone();
        }
        _;
    }

    modifier onlyWhitelistedAddress() {
        if (!isWhitelisted(msg.sender)) {
            revert NotwhitelistedAdmin();
        }
        _;
    }

    /**
     * @dev tokenURI is used to get tokenURI link.
     *
     * @param _tokenId - ID of drone
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
            revert DroneNotExist();
        }
        return string(abi.encodePacked(baseUri, drones[_tokenId].metadataHash));      
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
        
        emit SetBaseURI(baseUri, msg.sender);
    }

    /**
     * @dev updateMetadataHash is used to update the metadata of a drone.
     * Requirement:
     * - This function can only called by owner of the drone

     * @param _droneId - drone Id 
     * @param _droneMetadataHash - New Metadata
     * Emits a {UpdateMetadata} event.
     */
    function updateMetadataHash(
        uint _droneId, 
        string calldata _droneMetadataHash) 
        droneExists(_droneId) 
        onlyOwner
        external {

        drones[_droneId].metadataHash = _droneMetadataHash;

        emit UpdateMetadata(_droneId,_droneMetadataHash,msg.sender);
    }

    /**
     * @dev updateMintStatus is used to update miintng status.
     * Requirement:
     * - This function can only called by owner of the Contract

     * @param _status - status of drone Id 
     */
    
    function updateMintStatus(bool _status) 
    external 
    onlyOwner {
        mintEnabled = _status;

        emit MintStatusUpdated(_status, msg.sender);
    }
    
    /**
     * @dev updateMintLimit is used to update minting limit.
     * Requirement:
     * - This function can only called by owner of the Contract

     * @param newLimit - new Limit of minting 
     */
    
    function updateMintLimit(uint256 newLimit) 
    external 
    onlyOwner {
        if(newLimit <= mintSupplyLimit) 
            revert NewLimitShouldBeGreaterThanExisting(mintSupplyLimit, newLimit);

        mintSupplyLimit = newLimit;

        emit MintLimitUpdated(mintSupplyLimit, msg.sender);
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

        if(drones[tokenId].listedOnSale && from == drones[tokenId].ownerAddress) {
            drones[tokenId].listedOnSale = false;
            drones[tokenId].ownerAddress = to;
        } else {
            drones[tokenId].ownerAddress = to;
        }

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override(ERC721, IERC721) {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

        if(drones[tokenId].listedOnSale && from == drones[tokenId].ownerAddress) {
            drones[tokenId].listedOnSale = false;
            drones[tokenId].ownerAddress = to;
        } else {
            drones[tokenId].ownerAddress = to;
        }

        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev mintDrone is used to create a new drone.
     * Requirement:     

     * @param _droneMetadataHash - drone metadata 
     */

    function mintDrone(string memory _droneMetadataHash) 
    external 
    nonReentrant
    onlyWhitelistedAddress 
    {
        droneId++;
        if (bytes(_droneMetadataHash).length != 46) {
            revert InvalidMetadataHash();
        }

        if (!mintEnabled) {
            revert MintingDisabled();
        }
        if (totalSupply() >= mintSupplyLimit) {
            revert DroneMintSupplyReached();
        }

        drones[droneId] = Drones(0, msg.sender, false, _droneMetadataHash);

        emit DroneMinted(droneId, msg.sender, _droneMetadataHash);

        _safeMint(msg.sender, droneId);
    }

    /**
     * @dev updateDroneToSale is used to list a new drone.
     * Requirement:
     * - This function can only called by owner of the drone
     *
     * @param _droneId - drone Id 
     * @param _price - Price of the drone
     * Emits a {UpdatedDroneStatusForSale} event when player address is new.
     */

    function updateDroneToSale(
        uint256 _droneId,
        uint256 _price) 
        external
        onlyOwnerOfDrone(_droneId) 
    {
        if (_price <= 0) {
            revert PriceMustBeAboveZero();
        }        
        drones[_droneId].listedOnSale = true;
        drones[_droneId].price = _price;

        emit UpdatedDroneStatusForSale(_droneId, msg.sender, _price);
    }

    /**
     * @dev getDroneInfo is used to get information of listing drone.
     *
     * @param _droneId - ID of drone
     *
     * @return listing Tuple.
     */

    function getDroneInfo(uint256 _droneId)
    external 
    view 
    returns (Drones memory)
    {
        return drones[_droneId];
    }

    /**
     * @dev updateDroneStatusToNotForSale is used to remove drone from listng.
     * Requirement:
     * - This function can only called by owner of the drone
     *
     * @param _droneId - drone Id 
     * Emits a {UpdatedDroneStatusToNotForSale} event when player address is new.
     */

    function updateDroneStatusToNotForSale(uint256 _droneId) 
    external
    isListedForSale(_droneId)
    onlyOwnerOfDrone(_droneId)
    {
        drones[_droneId].listedOnSale = false;

        emit UpdatedDroneStatusToNotForSale(_droneId, msg.sender);
    }

    /**
     * @dev buyDrone is used to buy drone which user has listed.
     * Requirement:
     * - This function can only called by anyone who wants to purchase drone
     *
     * @param _droneId - drone Id 
     * Emits a {DroneBought} event when player address is new.
     */

    function buyDrone(uint256 _droneId)  
    payable 
    external
    isListedForSale(_droneId)    
    notOwnerOfDrone(_droneId)  
    {
        if(drones[_droneId].ownerAddress != ownerOf(_droneId)){
            revert OwnerTransferredTokenExternally();
        }
        if (msg.value != drones[_droneId].price) {
            revert PriceNotMatched(_droneId, drones[_droneId].price);
        }

        emit DroneBought(_droneId, msg.sender, drones[_droneId].price);

        _safeTransfer(drones[_droneId].ownerAddress, msg.sender, _droneId, "");

        drones[_droneId].ownerAddress = msg.sender;
        drones[_droneId].listedOnSale = false;
    }

    /**
     * @dev updateDronePrice is used to update the price of a drone.
     * Requirement:
     * - This function can only called by owner of the drone

     * @param _droneId - drone Id 
     * @param _newPrice - Price of the drone
     * Emits a {UpdatedDronePrice} event when player address is new.
     */

    function updateDronePrice(
        uint256 _droneId,
        uint256 _newPrice
        ) 
    external
    isListedForSale( _droneId)
    onlyOwnerOfDrone(_droneId)
    nonReentrant
    {
        if (_newPrice <= 0) {
            revert PriceMustBeAboveZero();
        }        
        drones[_droneId].price = _newPrice;
        emit UpdatedDronePrice(_droneId, msg.sender, _newPrice);
    }

    /**
     * @dev whitelistAdmin is used to whitelsit admin account.
     * Requirement:
     * - This function can only called by owner of the contract

     * @param _users - Admins to be whitelisted 
     * Emits a {AddedWhitelistAdmin} event when player address is new.
     */

    function whitelistAdmin(address[] calldata _users) public onlyOwner {
        
        for(uint256 i=0; i< _users.length; i++){
             address user = _users[i];
             whitelistedAddresses.push(user);
            emit AddedWhitelistAdmin(user, msg.sender);     

            }
    }

    /**
     * @dev removeWhitelistAdmin is used to whitelsit admin account.
     * Requirement:
     * - This function can only called by owner of the contract

     * @param _user - Accounts to be removed 
     * Emits a {RemovedWhitelistAdmin} event when player address is new.
     */

    function removeWhitelistAdmin(address _user) 
    external 
    onlyOwner {
        for (uint256 i; i<whitelistedAddresses.length; i++) {
            if (whitelistedAddresses[i] == _user) {
                whitelistedAddresses[i] = whitelistedAddresses[whitelistedAddresses.length - 1];
                whitelistedAddresses.pop();
                break;
            }
            emit RemovedWhitelistAdmin(_user,msg.sender);     
        }
    }

    /**
     * @dev getAllDrones is used to get information of all drones.
     */
 
    function getAllDrones() 
    external
    view 
    returns(Drones[] memory){
        Drones[] memory dronesList = new Drones[](totalSupply());

        for (uint i = 1; i <= totalSupply(); i++){
            dronesList[i-1] = drones[i];
        }
    return dronesList;
    }

    /**
     * @dev getDronesByAddress is used to get information of all drones.
     */
 
    function getDronesByAddress(address playerAddress) 
    external 
    view 
    returns(ReturnDroneInfo[] memory){

        ReturnDroneInfo [] memory droneInfo = new ReturnDroneInfo[](balanceOf(playerAddress));

        if(balanceOf(playerAddress) == 0)
            return droneInfo;

        uint256 droneIndex = 0;

        for (uint i = 1; i <= totalSupply(); i++){
            if(ownerOf(i) == playerAddress){
                droneInfo[droneIndex].droneID = i;
                droneInfo[droneIndex].metadataHash = string(abi.encodePacked(baseUri, drones[i].metadataHash));
                droneIndex++;
            }
        }
    return droneInfo;
    }

    function isWhitelisted(address _user) public view returns (bool) {
    for (uint i = 0; i < whitelistedAddresses.length; i++) {
      if (whitelistedAddresses[i] == _user) {
          return true;
        }
    }
    return false;
    }
    
    function getDronesboth(address playerAddress,bool isTrue) 
    external 
    view 
    returns(ReturnDroneInfo[] memory){
        
        ReturnDroneInfo [] memory droneInfo = new ReturnDroneInfo[](totalSupply());

        uint256 droneIndex = 0;

        if (isTrue == true){
            for (uint i = 1; i <= whitelistedAddresses.length; i++){           
                for (uint j=1; j <= totalSupply(); j++){
                    if(ownerOf(j) == whitelistedAddresses[i-1]){
                    droneInfo[droneIndex].droneID = j;
                    droneInfo[droneIndex].metadataHash = string(abi.encodePacked(baseUri, drones[j].metadataHash));
                    droneInfo[droneIndex].isAdminDrone = true;
                    droneIndex++;
                    }
                }
            }
            for (uint i = 1; i <= totalSupply(); i++){
                if(ownerOf(i) == playerAddress){
                    droneInfo[droneIndex].droneID = i;
                    droneInfo[droneIndex].metadataHash = string(abi.encodePacked(baseUri, drones[i].metadataHash));
                    droneInfo[droneIndex].isAdminDrone = false;
                    droneIndex++;
                }
            }
        }
        else {
            for (uint i = 1; i <= totalSupply(); i++){
                if(ownerOf(i) == playerAddress){
                    droneInfo[droneIndex].droneID = i;
                    droneInfo[droneIndex].metadataHash = string(abi.encodePacked(baseUri, drones[i].metadataHash));
                    droneInfo[droneIndex].isAdminDrone = false;
                    droneIndex++;
                }   
            }
        }
        return droneInfo;

    }

    function setRoyaltyInfo(
        address _receiver, 
        uint96 _royaltyFeesInBips) 
        public 
        onlyOwner {
        _setDefaultRoyalty(_receiver, _royaltyFeesInBips);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
