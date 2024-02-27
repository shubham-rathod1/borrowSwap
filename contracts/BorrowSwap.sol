// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface IUnilendV2Core {
    function borrow(
        address _pool,
        int _amount,
        uint _collateral_amount,
        address payable _recipient
    ) external;
}

contract BorrowSwap {
    ISwapRouter public immutable swapRouter;
    address immutable WETH9;
    IUnilendV2Core public immutable unilendCore;

    event Borrowed(address indexed tokenAddress, address indexed user, int256 amount, uint256 time);

    struct BorrowSwapParams {
        address _pool;
        address _tokenIn;
        address _tokenOUt;
        address _borrowToken;
        uint256 _collateral_amount;
        int256 _amount;
    }

    constructor(ISwapRouter _swapRouter, address _WETH9, IUnilendV2Core _unilendCore) {
        swapRouter = _swapRouter;
        WETH9 = _WETH9;
        unilendCore = _unilendCore;
    }

    function InitBorrow(
        address _pool,
        address _tokenIn,
        address _tokenOUt,
        address _borrowToken,
        uint256 _collateral_amount,
        int256 _amount
    ) external {
        // get asset from user
        TransferHelper.safeTransferFrom(_tokenIn, msg.sender, address(this), _collateral_amount);
        // approve lending protocol
        TransferHelper.safeApprove(_tokenIn, address(unilendCore), _collateral_amount);
        // borrowing from lending protocol
        unilendCore.borrow(_pool, _amount, _collateral_amount, payable(msg.sender));

        // check assets on user address
        require(
            IERC20(_borrowToken).balanceOf(msg.sender) >= uint256(_amount),
            "borrowed failed"
        );

        emit Borrowed(_borrowToken,msg.sender,_amount,block.timestamp);
        // get borrow asset from user for swaping
        TransferHelper.safeTransferFrom(_borrowToken, msg.sender, address(this), uint256(_amount));
        // swap borrowed asset for tokenOut
        swapToken(_borrowToken,_tokenOUt,msg.sender,uint256(_amount),3000,10000);

    }

     function swapToken(
        address tokenIn,
        address tokenOut,
        address _user,
        uint256 _amountIn,
        uint24 swapFee0,
        uint24 swapFee1
    ) internal {
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
