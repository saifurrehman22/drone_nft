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
    string public baseURI;
    string public contractURI;
    address payable dronePaymentAddress;
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
    error OwnerCannotBuyHisOwnToken();
    error playerAddressShouldNotBeWhitelistedAddress();

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

    event SetbaseURI(
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
        address payable addAddrDronesPayment,
        string memory _contractURI
        ) ERC721("Drones", "TB2") {

        mintSupplyLimit = _mintSupplyLimit;
        mintEnabled = true;
        baseURI = "https://gateway.pinata.cloud/ipfs/";
        contractURI = _contractURI;
        dronePaymentAddress = addAddrDronesPayment;
        emit SetbaseURI(baseURI, msg.sender);
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

    function updateDronePaymentAddress(address payable _newAddress)
    external
    onlyOwner{
        dronePaymentAddress = _newAddress;
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
        return string(abi.encodePacked(baseURI, drones[_tokenId].metadataHash));      
    }

    /**
     * @dev setbaseURI is used to set baseURI.
     * Requirement:
     * - This function can only called by owner of contract
     *
     * @param _baseURI - New baseURI
     * Emits a {UpdatedbaseURI} event.
     */

    function setbaseURI(string memory _baseURI) 
    external onlyOwner {
        baseURI = _baseURI;
        
        emit SetbaseURI(baseURI, msg.sender);
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
     * @param _newLimit - new Limit of minting 
    */
    
    function updateMintLimit(uint256 _newLimit) 
    external 
    onlyOwner {
        if(_newLimit <= mintSupplyLimit) 
            revert NewLimitShouldBeGreaterThanExisting(mintSupplyLimit, _newLimit);

        mintSupplyLimit = _newLimit;

        emit MintLimitUpdated(mintSupplyLimit, msg.sender);
    }

    /**
     * @dev See {IERC721-transferFrom}.
    */

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public virtual override(ERC721, IERC721) {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "ERC721: caller is not token owner nor approved");

        if(drones[_tokenId].listedOnSale && _from == drones[_tokenId].ownerAddress) {
            drones[_tokenId].listedOnSale = false;
            drones[_tokenId].ownerAddress = _to;
        } else {
            drones[_tokenId].ownerAddress = _to;
        }
        _transfer(_from, _to, _tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
    */

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) public virtual override(ERC721, IERC721) {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "ERC721: caller is not token owner nor approved");

        if(drones[_tokenId].listedOnSale && _from == drones[_tokenId].ownerAddress) {
            drones[_tokenId].listedOnSale = false;
            drones[_tokenId].ownerAddress = _to;
        } else {
            drones[_tokenId].ownerAddress = _to;
        }
        _safeTransfer(_from, _to, _tokenId, _data);
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
     * - DronePrice - price of the drone that wants to purchase
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
        if(ownerOf(_droneId) == msg.sender){
            revert OwnerCannotBuyHisOwnToken();
        }

        dronePaymentAddress.transfer(msg.value);

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
     * @param _admin - Accounts to be removed 
     * Emits a {RemovedWhitelistAdmin} event when player address is new.
    */

    function removeWhitelistAdmin(address _admin) 
    external 
    onlyOwner {
        for (uint256 i; i<whitelistedAddresses.length; i++) {
            if (whitelistedAddresses[i] == _admin){
               whitelistedAddresses[i] = whitelistedAddresses[whitelistedAddresses.length - 1];
               whitelistedAddresses.pop();
               break;
            }
            emit RemovedWhitelistAdmin(_admin,msg.sender);
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
 
    function getDronesByAddress(address _playerAddress) 
    external 
    view 
    returns(ReturnDroneInfo[] memory){

        ReturnDroneInfo [] memory droneInfo = new ReturnDroneInfo[](balanceOf(_playerAddress));

        if(balanceOf(_playerAddress) == 0)
            return droneInfo;

        uint256 droneIndex = 0;

        for (uint i = 1; i <= totalSupply(); i++){
            if(ownerOf(i) == _playerAddress){
                droneInfo[droneIndex].droneID = i;
                droneInfo[droneIndex].metadataHash = string(abi.encodePacked(baseURI, drones[i].metadataHash));
                droneIndex++;
            }
        }
    return droneInfo;
    }

    /**
     * @dev isWhitelisted is used to check either admin is whitelisted or not.
     *
     * @param _admin - Address of admin
     * @return bool .
    */

    function isWhitelisted(address _admin) public view returns (bool) {
    for (uint i = 0; i < whitelistedAddresses.length; i++) {
      if (whitelistedAddresses[i] == _admin) {
          return true;
        }
    }
    return false;
    }
    
    /**
     * @dev getAdminAndPlayerDrones is used to get list of available drone player and admin.
     * Requirement:
     * - This function can only called by anyone who wants to see available drone
     *
     * @param _playerAddress - playerAddress address who wants to see his NFTs
     * @param _fetchWhitelistedDrones - bool pass true if wants to see your and admin NFTs
    */

    function getAdminAndPlayerDrones(address _playerAddress, bool _fetchWhitelistedDrones) 
    external 
    view 
    returns(ReturnDroneInfo[] memory, uint256){
        if(isWhitelisted(_playerAddress)){
            revert playerAddressShouldNotBeWhitelistedAddress();
        }
        ReturnDroneInfo [] memory droneInfo = new ReturnDroneInfo[](totalSupply());
        uint droneIndex;

        if(_fetchWhitelistedDrones){
            for (uint i = 0; i < whitelistedAddresses.length; i++){
                uint256 whitelistBalanceCheck = balanceOf(whitelistedAddresses[i]);

                if(whitelistBalanceCheck > 0) {
                    for (uint j = 0; j < whitelistBalanceCheck; j++){
                        uint256 tokenId = tokenOfOwnerByIndex(whitelistedAddresses[i], j);
                        droneInfo[droneIndex].droneID = tokenId;
                        droneInfo[droneIndex].metadataHash = string(abi.encodePacked(baseURI, drones[tokenId].metadataHash));
                        droneInfo[droneIndex].isAdminDrone = true;
                        droneIndex++; 
                    }
                }
            }
        }
        uint256 playerBalanceCheck = balanceOf(_playerAddress);

        if(playerBalanceCheck > 0) {
            for (uint k = 0; k < playerBalanceCheck; k++){
                uint256 tokenId = tokenOfOwnerByIndex(_playerAddress, k);
                droneInfo[droneIndex].droneID = tokenId;
                droneInfo[droneIndex].metadataHash = string(abi.encodePacked(baseURI, drones[tokenId].metadataHash));
                droneInfo[droneIndex].isAdminDrone = false;
                droneIndex++;                    
            }
        }
        return (droneInfo, whitelistedAddresses.length);
    }

    /**
     * @dev setContractURI is used to set contract level metadata.
     * Requirement:
     * - This function can only called by owner of contract
     *
     * @param _contractURI - New baseURI
     */

    function setContractURI(string calldata _contractURI) 
    public 
    onlyOwner {
        contractURI = _contractURI;
    }
}
