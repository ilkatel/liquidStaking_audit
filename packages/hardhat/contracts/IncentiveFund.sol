// TODO:
// - lock tokens for 6 years
// - linear unlocking
// - multisig withdrawal
// - add unlocking pool
// - add function for set initial settings (token address, totalAmount)
// - add reentrancy defence


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/*
 * @title ALGM token interface
 */
interface IALGM {
  function transfer(address _recepient, uint _amount) external returns (bool);
  function decimals() external view returns (uint8);
  function IncentiveDistrib() external view returns (uint32);
}

/*
 * @title    Incentive treasury contract
 * @notice   The treasury receives ALGM tokens for incentives 
 *           and locks them up for 6 years with a linear unlocking.
 *
 * Features:
 * - Tokens locks for specified period
 * - Linear unlock during the whole period
 * - Withdrawals are only allowed if there are enough votes from the owners
 */

contract IncentiveFund {

    // @notice    Multisig usage

    // Contract owners
    address[] public owners;
    // To find out if the address is owner
    mapping(address => bool) public isOwner;
    // Number of required votes for multisig
    uint public required;

    // Transaction structure for withdraw allowed tokens
    struct Transaction {
      address to;
      uint value;
      bool executed;
    }

    Transaction[] public transactions;

    // Shows if the transaction approved by owner address for transaction ID
    mapping(uint => mapping(address => bool)) public approved;

    // @notice    Time locking usage

    // Total amount minted by ALGM token
    uint public totalAmount;
    // Locking end time, starting from time of contract creation
    uint public endTime = block.timestamp + TIME_LOCK;
    // Lock duration
    uint public constant TIME_LOCK = 6 * 365 days;

    // Boolean for noReentran modifier
    bool internal reeLocked;

    // Interface of ALGM token
    IALGM tokenALGM;

    event CreateTransaction(uint indexed txId);
    event Approve(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner, uint indexed txId);
    event ExecuteTransaction(uint indexed txId);

    // @notice    Checks if the caller is one of the owners
    modifier onlyOwner() {
      require(isOwner[msg.sender], "Not an owner");
      _;
    }

    // @notice    Checks if the transaction exists 
    modifier txExists(uint _txId) {
      require(_txId < transactions.length, "Transaction not exists");
      _;
    }

    // @notice    Checks if the transaction is not approved 
    modifier notApproved(uint _txId) {
      require(!approved[_txId][msg.sender], "Transaction already approved");
      _;
    }

    // @notice    Checks if the transaction is not executed 
    modifier notExecuted(uint _txId) {
      require(!transactions[_txId].executed, "Transaction already executed");
      _;
    }

    // @notice    Prevents reentrancy
    modifier noReentrant() {
      require(!reeLocked, "No way");
      reeLocked = true;
      _;
      reeLocked = false;
    }

    // @notice      Contract constructor
    // @param       address[] _owners => Array with contract owners
    // @param       uint _required => Required number of votes for multisig
    constructor(address[] memory _owners, uint _required) {      
      require(_owners.length > 0, "Need more owners");
      require(
        _required > 0 && _required <= _owners.length,
        "Wrong number of required"
      );

      // Add owners to owners array and isOwner mapping
      for (uint i; i < _owners.length; i++) {
        address owner = _owners[i];
        require(owner != address(0), "Zero address");
        require(!isOwner[owner], "Owner already extists");

        isOwner[owner] = true;
        owners.push(owner);
      }

      // Set number of required votes for multisig
      required = _required;
    }

    // @notice    Sets token address and gets total tokens amount for current treasury
    // @param     address _token => address of ALGM token
    function initialSettings(address _token) public onlyOwner {
      tokenALGM = IALGM(_token);
      totalAmount = tokenALGM.IncentiveDistrib() * 10**tokenALGM.decimals();
    } 

    // @notice    Shows amount of unlocking tokens
    function availableAmount() public view returns (uint) {
      require(endTime >= block.timestamp, "error"); // <= rewrite error text
      return totalAmount / (endTime - block.timestamp);
    }

    // @notice    Creates transaction struct by one of the owners for multisig
    //            and checks if there are anough unlocked tokens
    // @param     address _to => address of recepient of transaction
    // @param     uint _tokenAmount => number of tokens to withdraw
    function createTransaction(address _to, uint _tokenAmount)
      external
      onlyOwner
    {
      require(_tokenAmount <= availableAmount(), "This number of tokens is not available");
      transactions.push(Transaction({
        to: _to,
        value: _tokenAmount,
        executed: false
      }));
      emit CreateTransaction(transactions.length - 1);
    }

    // @notice    Approve transaction by owners
    // @param     uint _txId => transaction ID
    function approveTransaction(uint _txId) 
      external 
      onlyOwner
      txExists(_txId) 
      notApproved(_txId) 
      notExecuted(_txId) 
    {
      approved[_txId][msg.sender] = true;
      emit Approve(msg.sender, _txId);
    }

    // @notice    Get number of approvals for transaction
    // @param     uint _txId => transaction ID
    function _getApprovalCount(uint _txId) private view returns (uint count) {
      for (uint i; i < owners.length; i++) {
        if (approved[_txId][owners[i]]) {
          count++;
        }
      }
    }

    // @notice    Checks number of approvals 
    //            and sends tokens to recepient 
    // @param     uint _txId => transaction ID
    function executeTransaction(uint _txId) 
      external 
      txExists(_txId) 
      notExecuted(_txId) 
      noReentrant
    {
      require(_getApprovalCount(_txId) >= required, "Need more approvals");
      Transaction storage transaction = transactions[_txId];

      transaction.executed = true;

      // Sending tokens to address
      tokenALGM.transfer(transaction.to, transaction.value);

      emit ExecuteTransaction(_txId);
    }

    // @notice    Allows owners to revoke approve
    // @param     uint _txId => transaction ID
    function revokeApprove(uint _txId) 
      external 
      onlyOwner 
      txExists(_txId) 
      notExecuted(_txId) 
    {
      require(approved[_txId][msg.sender], "Tx not approved");
      approved[_txId][msg.sender] = false;
      emit Revoke(msg.sender, _txId);
    }
    
    // @notice Reserve function for withdraw funds
    function withdraw() public onlyOwner {
      payable(msg.sender).transfer(address(this).balance);
    }

    // @notice Reserve function for receive funds
    receive() external payable {
    }

}
