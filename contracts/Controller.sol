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
        console.log(contractAddress, "contract user address");
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
}
