// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <=0.8.19;

contract JointBankAccount {
    event Deposit(
        address indexed user,
        uint256 indexed accountId,
        uint256 value,
        uint256 timestamp
    );
    event WithdrawRequested(
        address indexed user,
        uint256 indexed accountId,
        uint256 indexed withdrawId,
        uint256 amount,
        uint256 timestamp
    );
    event Withdraw(uint indexed withdrawId, uint timestamp);
    event AccountCreated(address[] owners, uint indexed id, uint timestamp);

    struct WithdrawRequest {
        address user;
        uint amount;
        uint approvals;
        mapping(address => bool) ownersApproved;
        bool approved;
        uint timestamp;
    }
    struct Account {
        address[] owners;
        uint256 balance;
        mapping(uint => WithdrawRequest) withdrawRequests;
    }

    mapping(uint => Account) accounts;
    mapping(address => uint[]) userAccounts;

    uint nextAccountId;
    uint nextWithdrawId;

    modifier accountOwner(uint accountId) {
        require(accountId < nextAccountId, "Account does not exist");
        bool isOwner = false;
        for (uint i = 0; i < accounts[accountId].owners.length; i++) {
            if (accounts[accountId].owners[i] == msg.sender) {
                isOwner = true;
                break;
            }
        }
        require(isOwner, "Must be an account owner");
        _;
    }

    modifier validOwners(address[] memory owners) {
        require(owners.length + 1 <= 4, "Maximum of 4 owners per account");
        for (uint i = 0; i < owners.length; i++) {
            for (uint j = i + 1; j < owners.length; j++) {
                if (owners[i] == owners[j]) {
                    revert("No duplicate owners");
                }
            }
        }
        _;
    }

    modifier sufficientBalance(uint accountId, uint amount) {
        require(
            accounts[accountId].balance >= amount,
            "Insufficient funds in account"
        );
        _;
    }

    modifier canApprove(uint accountId, uint withdrawId) {
        require(withdrawId < nextWithdrawId, "Withdrawal does not exist");
        require(
            !accounts[accountId].withdrawRequests[withdrawId].approved,
            "Withdrawal already approved"
        );
        require(
            accounts[accountId].withdrawRequests[withdrawId].user != msg.sender,
            "User cannot approve their own withdrawal"
        );
        require(
            accounts[accountId].withdrawRequests[withdrawId].user != address(0),
            "Withdrawal does not exist"
        );
        require(
            !accounts[accountId].withdrawRequests[withdrawId].ownersApproved[
                msg.sender
            ],
            "you have already approved this withdrawal"
        );
        _;
    }

    modifier canWithdraw(uint accountId, uint withdrawId) {
        require(
            accounts[accountId].withdrawRequests[withdrawId].user == msg.sender,
            "you did not create this withdrawal"
        );
        require(
            accounts[accountId].withdrawRequests[withdrawId].approved,
            "Withdrawal not approved"
        );
        _;
    }

    function deposit(uint accountId) external payable accountOwner(accountId) {
        require(msg.value > 0, "Deposit must be greater than 0");

        accounts[accountId].balance += msg.value;

        emit Deposit(msg.sender, accountId, msg.value, block.timestamp);
    }

    function createAccount(
        address[] calldata otherOwners
    ) external validOwners(otherOwners) {
        address[] memory owners = new address[](otherOwners.length + 1);
        owners[otherOwners.length] = msg.sender;

        uint id = nextAccountId;

        for (uint i; i < owners.length; i++) {
            if (i < owners.length - 1) {
                owners[i] = otherOwners[i];
            }

            if (userAccounts[owners[i]].length > 2) {
                revert("User can only have 3 accounts");
            }

            userAccounts[owners[i]].push(id);
        }

        accounts[id].owners = owners;
        nextAccountId++;
        emit AccountCreated(owners, id, block.timestamp);
    }

    function requestWithdraw(
        uint accountId,
        uint amount
    ) external accountOwner(accountId) sufficientBalance(accountId, amount) {
        require(amount > 0, "Withdrawal must be greater than 0");

        uint withdrawId = nextWithdrawId;
        WithdrawRequest storage request = accounts[accountId].withdrawRequests[
            withdrawId
        ];
        request.user = msg.sender;
        request.amount = amount;
        nextWithdrawId++;

        emit WithdrawRequested(
            msg.sender,
            accountId,
            withdrawId,
            amount,
            block.timestamp
        );
    }

    function approveWithdraw(
        uint accountId,
        uint withdrawId
    ) external accountOwner(accountId) canApprove(accountId, withdrawId) {
        WithdrawRequest storage request = accounts[accountId].withdrawRequests[
            withdrawId
        ];
        request.ownersApproved[msg.sender] = true;
        request.approvals++;

        if (request.approvals == accounts[accountId].owners.length - 1) {
            request.approved = true;
        }
    }

    function withdraw(
        uint accountId,
        uint withdrawId
    ) external accountOwner(accountId) canWithdraw(accountId, withdrawId) {
        WithdrawRequest storage withdrawRequest = accounts[accountId]
            .withdrawRequests[withdrawId];
        uint amount = withdrawRequest.amount;

        accounts[accountId].balance -= amount;
        delete accounts[accountId].withdrawRequests[withdrawId];

        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Failed to send Ether");

        emit Withdraw(withdrawId, block.timestamp);
    }

    function getBalance(uint accountId) public view returns (uint) {
        require(accountId < nextAccountId, "Account does not exist");
        return accounts[accountId].balance;
    }

    function getOwners(uint accountId) public view returns (address[] memory) {
        require(accountId < nextAccountId, "Account does not exist");
        return accounts[accountId].owners;
    }

    function getApprovals(
        uint accountId,
        uint withdrawId
    ) public view returns (uint) {
        require(accountId < nextAccountId, "Account does not exist");
        require(withdrawId < nextWithdrawId, "Withdrawal does not exist");
        return accounts[accountId].withdrawRequests[withdrawId].approvals;
    }

    function getAccounts() public view returns (uint[] memory) {
        return userAccounts[msg.sender];
    }
}
