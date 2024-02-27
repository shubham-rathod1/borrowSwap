// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract Swap {
    ISwapRouter public immutable swapRouter;
    address immutable WETH9;
    constructor(ISwapRouter _swapRouter, address _WETH9) {
        swapRouter = _swapRouter;
        WETH9 = _WETH9;
    }

    function _swapToken(
        address tokenIn,
        address tokenOut,
        address _user,
        uint256 _amountIn,
        uint24 swapFee0,
        uint24 swapFee1
    ) external {
        TransferHelper.safeApprove(tokenIn, address(swapRouter), _amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: abi.encodePacked(
                    tokenIn,
                    swapFee0,
                    WETH9,
                    swapFee1,
                    tokenOut
                ),
                recipient: _user,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: 0
            });
        swapRouter.exactInput(params);

        console.log("swapped", IERC20(tokenOut).balanceOf(_user));
    }
}
