// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DroneContract is ERC721Enumerable, Ownable, ReentrancyGuard 
{

    uint public droneId;
    uint public mintSupplyLimit;
    bool public mintEnabled;
    string public baseUri;

    struct Drones{
        uint256 price;
        address ownerAddress;
        bool listedOnSale;
        string metadataHash;
    }
    
    mapping(uint256 => Drones) public drones;
    mapping (address => bool) public whitelistedAdminAddresses;

    error PriceNotMatched(
        uint256 droneId, 
        uint256 price
    );
    error PriceMustBeAboveZero();
    error NotOwnerOfDrone();
    error InvalidMetadataHash();
    error InvaliddroneId();
    error MintingDisabled();
    error NotWhitelistedAdmin();
    error DroneMintSupplyReached();
    error DroneNotExist();
    error OwnerCannotBuyHisOwnDrone();

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

    constructor(uint _mintSupplyLimit) ERC721("Drones", "TB2") {
        mintSupplyLimit = _mintSupplyLimit;
        mintEnabled = true;
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
        if (!whitelistedAdminAddresses[msg.sender]) {
            revert NotWhitelistedAdmin();
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
     * @dev mintDrone is used to create a new drone.
     * Requirement:     

     * @param _droneMetadataHash - drone metadata 
     */

    function mintDrone(string memory _droneMetadataHash) 
    external 
    nonReentrant
    onlyWhitelistedAddress {

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
        if (msg.value != drones[_droneId].price) {
            revert PriceNotMatched(_droneId, drones[_droneId].price);
        }

        emit DroneBought(_droneId, msg.sender, drones[_droneId].price);

        _safeTransfer(drones[_droneId].ownerAddress, msg.sender, _droneId ,"");

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
     * @dev addWhitelistAddress is used to whitelsit admin account.
     * Requirement:
     * - This function can only called by owner of the contract

     * @param _account - Account to be whitelisted 
     * Emits a {WhitelistAdmin} event when player address is new.
     */

    function addWhitelistAddress(address _account) 
    external 
    onlyOwner {
        whitelistedAdminAddresses[_account] = true;
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
        delete (whitelistedAdminAddresses[_account]);
        emit RemovedWhitelistAdmin(_account, msg.sender);
    }

    /**
     * @dev getAllDrones is used to get information of all drones.
     */
 
    function getAllDrones() 
    public 
    view 
    returns(Drones[] memory){
        Drones[] memory items = new Drones[](totalSupply());

        for (uint i = 1; i <= totalSupply(); i++){
            items[i-1] = drones[i];
        }

    return items;
    }
}
