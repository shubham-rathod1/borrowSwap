// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "hardhat/console.sol";

interface ILogic {
    function compBorrow(
        address _supplyAsset,
        address _borrowAsset,
        address _tokenOut,
        uint _supplyAmount,
        uint _borrowAmount,
        address user
    ) external;
    function InitBorrow(
        address _pool,
        address _supplyAsset,
        address _tokenOUt,
        address _borrowToken,
        uint256 _collateral_amount,
        int256 _amount,
        address _user
    ) external;
    function repayBorrow(
        address _pool,
        address _tokenIn,
        address _borrowedToken,
        address _user,
        uint256 _nftID,
        int256 _amountOut,
        int256 _repayAmount
    ) external returns (int256);

    function compRepay(
        address _borrowedToken,
        address _tokenIn,
        address _user,
        address _collateralToken,
        uint256 _collateralAmount,
        uint256 _repayAmount
    ) external;
}

contract Controller {
    address public logicAddress;
    mapping(address => address) public proxyAddress;

    constructor(address _logicAddress) {
        require(_logicAddress != address(0), "zero address");
        logicAddress = _logicAddress;
    }

    // call events here

    function createAccount() private returns (address contractAddress) {
        require(
            proxyAddress[msg.sender] == address(0),
            "proxyAddress created for this user"
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
        return contractAddress;
    }

    function compoundBorrow(
        address _supplyAsset,
        address _borrowAsset,
        address _tokenOut,
        uint _supplyAmount,
        uint _borrowAmount,
        address _user
    ) external {
        if (proxyAddress[msg.sender] == address(0)) {
            createAccount();
        }
        // safe transfer from user to logic contract
        address contractAddress = proxyAddress[msg.sender];
        console.log(contractAddress, "contract user address", msg.sender);
        TransferHelper.safeTransferFrom(
            _supplyAsset,
            msg.sender,
            contractAddress,
            _supplyAmount
        );
        console.log("safeTransfered to Logic Contract");
        ILogic(contractAddress).compBorrow(
            _supplyAsset,
            _borrowAsset,
            _tokenOut,
            _supplyAmount,
            _borrowAmount,
            _user
        );
    }

    function uniBorrow(
        address _pool,
        address _supplyAsset,
        address _tokenOUt,
        address _borrowToken,
        uint256 _collateral_amount,
        int256 _amount,
        address _user
    ) external {
        if (proxyAddress[msg.sender] == address(0)) {
            createAccount();
        }
        address contractAddress = proxyAddress[msg.sender];
        TransferHelper.safeTransferFrom(
            _supplyAsset,
            msg.sender,
            contractAddress,
            _collateral_amount
        );
        ILogic(contractAddress).InitBorrow(
            _pool,
            _supplyAsset,
            _tokenOUt,
            _borrowToken,
            _collateral_amount,
            _amount,
            _user
        );
    }

    function uniRepay(
        address _pool,
        address _tokenIn,
        address _borrowedToken,
        address _user,
        uint256 _nftID,
        int256 _amountOut,
        int256 _repayAmount
    ) external {
        if (proxyAddress[msg.sender] == address(0)) {
            createAccount();
        }
        address contractAddress = proxyAddress[msg.sender];
        TransferHelper.safeTransferFrom(
            _tokenIn,
            msg.sender,
            contractAddress,
            uint256(_repayAmount)
        );
        ILogic(contractAddress).repayBorrow(
            _pool,
            _tokenIn,
            _borrowedToken,
            _user,
            _nftID,
            _amountOut,
            _repayAmount
        );
    }
    function reapay(
        address _borrowedToken,
        address _tokenIn,
        address _user,
        address _collateralToken,
        uint256 _collateralAmount,
        uint256 _repayAmount
    ) external {
        // if (proxyAddress[msg.sender] == address(0)) {
        //     createAccount();
        // }
        address contractAddress = proxyAddress[msg.sender];
        // add require condition here for checking contract address;
        TransferHelper.safeTransferFrom(
            _tokenIn,
            msg.sender,
            contractAddress,
            _repayAmount
        );

        ILogic(contractAddress).compRepay(
            _borrowedToken,
            _tokenIn,
            _user,
            _collateralToken,
            _collateralAmount,
            _repayAmount
        );
    }
}
