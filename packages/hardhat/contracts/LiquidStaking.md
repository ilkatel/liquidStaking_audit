So you want to use Liquid Staking?

There are some important things for you


## Settings and core structs
#### Public variables
```solidity
uint256   public    totalBalance; // total ASTR staked
uint256   public    claimPool; // claim pool amount
uint256   public    minStake; // minumum staking amount
uint256[] public    tfs; // staking timeframes
```

#### Global mappings
* ```address``` refers to user address
* ```uint256``` refers to stake/order ID
```solidity
mapping(address => mapping(uint256 => bool)) public isStakeOwner;
mapping(address => mapping(uint256 => bool)) public isOrderOwner;
```

####  Core Stake struct:
```solidity
struct      Stake {
    uint256 totalBalance; // ASTR balance
    uint256 liquidBalance; // nASTR balance
    uint256 claimable; // amount of nASTR available for claim immediately
    uint256 rate; // daily claimable nASTR amount

    uint256 startDate; // when staking started
    uint256 finDate; // when it can be redeemed
    uint256 lastUpdate; // last time balances updated
    }
```
* ```uint256``` refers to stake ID
```solidity
mapping(uint256 => Stake) public stakes;
```
#### Core Order struct and its fields
```solidity
struct      Order {
    bool    active; // is order active?
    address owner; // order owner
    uint256 stakeID; // order stake ID
	uint256 price; // order price
}
```
* ```uint256``` refers to order ID
```solidity
mapping(uint256 => Order) public orders;
```

## Events
#### Staking
```solidity
event Staked(address indexed who, uint256 stakeID, uint256 amount, uint256 timeframe);
event Claimed(address indexed who, uint256 stakeID, uint256 amount);
event Redeemed(address indexed who, uint256 stakeID, uint256 amount);
```
#### Orders
```solidity
event OrderChange(uint256 id, address indexed seller, bool state, uint256 price);
event OrderComplete(uint256 id, address indexed seller, address indexed buyer, uint256 price);
```

## Staking

#### stake
Creates new stake, ```msg.sender``` becomes the owner
* Parameter ```uint8 timeframe```: timeframe index from ```tfs[]```
* Returns ```uint256 id```: ID of new stake
* ```msg.value``` >= ```minStake```
```solidity
function stake(uint8 timeframe) external payable returns (uint256 id)
```
#### claim
Claims DNT from stake, issued via distributor
* Parameter ```uint256 id```: stake ID
* Parameter ```uint256 amount```: value to claim
* ```stakeOwner(id)```: caller should own stake
```solidity
function claim(uint256 id, uint256 amount) external stakeOwner(id) updateStake(id)
```
#### redeem
Exchange owned DNT to receive native token
* Parameter ```uint256 id```: stake ID
* Parameter ```uint256 amount```: amount to redeem
* ```stakeOwner(id)```: caller should own the stake
```solidity
function redeem(uint256 id, uint256 amount) external stakeOwner(id)
```
#### nowClaimable
Amount available for claiming right now
* Param ```uint256 id```: stake ID
```solidity
function nowClaimable(uint256 id) public view returns (uint256 amount)
```

## Orders
#### createOrder
Create sell order with particular stake and price
* Param ```uint256 id```: ID of stake to sell
* Param ```uint256 p```: order price
* Returns ```uint256 orderID```: ID of created order
* ```stakeOwner(id)```:  caller should own the stake
```solidity
function createOrder(uint256 id, uint256 p) external stakeOwner(id) returns (uint256 orderID)
```
#### cancelOrder
Cancel created order
* Param ```uint256 id```: order ID
* ```orderOwner(id)```: caller should own the order
```solidity
function cancelOrder(uint256 id) external orderOwner(id)
```
#### setPrice
Change order price
* Param ```uint256 id```: order ID
* Param ```uint256 p```: new price
* ```orderOwner(id)```: caller should own the order
```solidity
function setPrice(uint256 id, uint256 p) external orderOwner(id)
```
#### buyStake
Fullfill particular order to become the new owner of the sold stake.
* Param ```uint256 id```: order ID
* ```msg.value``` == ```orders[id].price```
```solidity
function buyStake(uint256 id) external payable
```