// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
interface ILogic {
    function compBorrow(
        address _supplyAsset,
        address _borrowAsset,
        address _tokenOut,
        uint _supplyAmount,
        uint _borrowAmount,
        address user,
        uint24[] memory _route
    ) external;
    function uniBorrow(
        address _pool,
        address _supplyAsset,
        address _tokenOUt,
        uint256 _collateral_amount,
        int256 _amount,
        address _user,
        uint24[] memory _route
    ) external;
    function uniRepay(
        address _pool,
        address _tokenIn,
        address _user,
        address _borrowAddress,
        uint256 _repayAmount,
        uint24[] memory _route
    ) external;

    function uniRedeem(
        address _pool,
        address _user,
        int _amount,
        address _tokenOut,
        uint24[] memory _route
    ) external;

    function compRepay(
        address _borrowedToken,
        address _tokenIn,
        uint256 _repayAmount,
        uint24[] memory _route
    ) external;

    function compRedeem(
        address _user,
        address _collateralToken,
        uint256 _collateralAmount,
        address _tokenOut,
        uint24[] memory _route
    ) external;
}

struct UniBorrow {
    address _pool;
    address _supplyAsset;
    address _tokenOUt;
    uint256 _collateral_amount;
    int256 _amount;
    address _user;
    uint24[] _route;
}

struct UniRepay {
    address _pool;
    address _tokenIn;
    address _user;
    address _borrowAddress;
    uint256 _repayAmount;
    uint24[] _route;
}

struct UniRedeem {
    address _pool;
    address _user;
    int _amount;
    address _tokenOut;
    uint24[] _route;
}

struct CompBorrow {
    address _supplyAsset;
    address _borrowAsset;
    address _tokenOut;
    uint _supplyAmount;
    uint _borrowAmount;
    address _user;
    uint24[] _route;
}

struct CompRepay {
    address _borrowedToken;
    address _tokenIn;
    uint256 _repayAmount;
    uint24[] _route;
}

struct CompRedeem {
    address _user;
    address _collateralToken;
    uint256 _collateralAmount;
    address _tokenOut;
    uint24[] _route;
}

contract Controller {
    address public immutable logicAddress;
    mapping(address => address) public proxyAddress;

    event AccountCreated(address indexed user, address indexed proxyAddress);

    constructor(address _logicAddress) {
        require(_logicAddress != address(0), "zero address provided");
        logicAddress = _logicAddress;
    }

    function createAccount() private returns (address contractAddress) {
        require(
            proxyAddress[msg.sender] == address(0),
            "Account already exists"
        );
        bytes20 targetBytes = bytes20(logicAddress); // Convert logicAddress to bytes20 for use in assembly block

        assembly {
            let clone := mload(0x40) // Create a new memory pointer
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            ) // Store the initialization code
            mstore(add(clone, 0x14), targetBytes) // Set the logic contract address in the initialization code
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            ) // Store the address of DELEGATE_CALL
            contractAddress := create(0, clone, 0x37) // Deploy the contract
            if iszero(contractAddress) {
                revert(0, 0)
            } // Check creation status
        }
        proxyAddress[msg.sender] = contractAddress;
        emit AccountCreated(msg.sender, contractAddress);
        return contractAddress;
    }

    function compoundBorrow(CompBorrow memory params) external {
        if (proxyAddress[msg.sender] == address(0)) {
            createAccount();
        }
        // safe transfer from user to logic contract
        address contractAddress = proxyAddress[msg.sender];

        TransferHelper.safeTransferFrom(
            params._supplyAsset,
            msg.sender,
            contractAddress,
            params._supplyAmount
        );
        ILogic(contractAddress).compBorrow(
            params._supplyAsset,
            params._borrowAsset,
            params._tokenOut,
            params._supplyAmount,
            params._borrowAmount,
            params._user,
            params._route
        );
    }

    function uniBorrow(UniBorrow memory params) external {
        if (proxyAddress[msg.sender] == address(0)) {
            createAccount();
        }
        address contractAddress = proxyAddress[msg.sender];
        TransferHelper.safeTransferFrom(
            params._supplyAsset,
            msg.sender,
            contractAddress,
            params._collateral_amount
        );
        ILogic(contractAddress).uniBorrow(
            params._pool,
            params._supplyAsset,
            params._tokenOUt,
            params._collateral_amount,
            params._amount,
            params._user,
            params._route
        );
    }

    function uniRedeem(UniRedeem memory params) external {
        address contractAddress = proxyAddress[msg.sender];
        require(contractAddress != address(0), "No position available!");

        ILogic(contractAddress).uniRedeem(
            params._pool,
            params._user,
            params._amount,
            params._tokenOut,
            params._route
        );
    }

    function uniRepay(UniRepay memory params) external {
        address contractAddress = proxyAddress[msg.sender];
        require(contractAddress != address(0), "No borrow position available!");

        TransferHelper.safeTransferFrom(
            params._tokenIn,
            msg.sender,
            contractAddress,
            uint256(params._repayAmount)
        );
        ILogic(contractAddress).uniRepay(
            params._pool,
            params._tokenIn,
            params._user,
            params._borrowAddress,
            params._repayAmount,
            params._route
        );
    }

    function compRepay(CompRepay memory params) external {
        address contractAddress = proxyAddress[msg.sender];
        require(contractAddress != address(0), "No borrow position available!");

        TransferHelper.safeTransferFrom(
            params._tokenIn,
            msg.sender,
            contractAddress,
            params._repayAmount
        );

        ILogic(contractAddress).compRepay(
            params._borrowedToken,
            params._tokenIn,
            params._repayAmount,
            params._route
        );
    }

    function compRedeem(CompRedeem memory params) external {
        address contractAddress = proxyAddress[msg.sender];
        require(contractAddress != address(0), "No borrow position available!");

        ILogic(contractAddress).compRedeem(
            params._user,
            params._collateralToken,
            params._collateralAmount,
            params._tokenOut,
            params._route
        );
    }
}
