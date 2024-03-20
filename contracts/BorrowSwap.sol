// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
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
    function repay(
        address _pool,
        int _amount,
        address _for
    ) external returns (int);
    function redeemUnderlying(
        uint _nftID,
        int amount,
        address _receiver
    ) external returns (int);
}

interface IComet {
    function supplyTo(address dst, address asset, uint amount) external;
    function withdrawTo(address to, address asset, uint amount) external;
    function withdrawFrom(
        address src,
        address to,
        address asset,
        uint amount
    ) external;
    function balanceOf(address account) external view returns (uint256);
    function collateralBalanceOf(
        address account,
        address asset
    ) external view returns (uint128);
    function allow(address manager, bool isAllowed_) external;
    function hasPermission(
        address owner,
        address manager
    ) external view returns (bool);
    function transfer(address dst, uint amount) external returns (bool);
    function transferAsset(address dst, address asset, uint amount) external;
}

contract BorrowSwap {
    ISwapRouter public constant swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address constant WETH9 = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    IUnilendV2Core public constant unilendCore =
        IUnilendV2Core(0x17dad892347803551CeEE2D377d010034df64347);
    IComet public constant cometAddress =
        IComet(0xF25212E676D1F7F89Cd72fFEe66158f541246445);
    address public immutable controller;

    event Borrowed(
        address indexed tokenAddress,
        address indexed user,
        int256 amount,
        uint256 time
    );

    struct BorrowSwapParams {
        address _pool;
        address _tokenIn;
        address _tokenOUt;
        address _borrowToken;
        uint256 _collateral_amount;
        int256 _amount;
    }
    // make constructor values hardcode and use init function
    constructor() {
        controller = msg.sender;
    }

    modifier onlyController() {
        require(controller == msg.sender, "Not Controller");
        _;
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
        TransferHelper.safeTransferFrom(
            _tokenIn,
            msg.sender,
            address(this),
            _collateral_amount
        );
        // approve lending protocol
        TransferHelper.safeApprove(
            _tokenIn,
            address(unilendCore),
            _collateral_amount
        );
        // borrowing from lending protocol
        unilendCore.borrow(
            _pool,
            _amount,
            _collateral_amount,
            payable(msg.sender)
        );

        if (_amount < 0) _amount = -_amount;

        // check assets on user address
        require(
            IERC20(_borrowToken).balanceOf(msg.sender) >= uint256(_amount),
            "borrowed failed"
        );

        emit Borrowed(_borrowToken, msg.sender, _amount, block.timestamp);
        // get borrow asset from user for swaping
        TransferHelper.safeTransferFrom(
            _borrowToken,
            msg.sender,
            address(this),
            uint256(_amount)
        );
        // swap borrowed asset for tokenOut
        exactInputSwap(
            _borrowToken,
            _tokenOUt,
            msg.sender,
            uint256(_amount),
            3000,
            10000
        );
    }

    function compBorrow(
        address _supplyAsset,
        address _borrowAsset,
        address _tokenOut,
        uint _supplyAmount,
        uint _borrowAmount,
        address _user
    ) external {
        // TransferHelper.safeTransferFrom(_supplyAsset, msg.sender, address(this), _supplyAmount);
        console.log(
            IERC20(_supplyAsset).balanceOf(address(this)),
            "balance of supply"
        );
        TransferHelper.safeApprove(
            _supplyAsset,
            address(cometAddress),
            _supplyAmount
        );

        //  Supply an asset that this contract holds to Compound III

        // IERC20(_supplyAsset).approve(address(cometAddress), _supplyAmount);
        cometAddress.supplyTo(address(this), _supplyAsset, _supplyAmount);
        // require(cometAddress.collateralBalanceOf(msg.sender,0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619) > 0,"user supply failed");
        //  Borrow as asset from Comopound III
        cometAddress.withdrawTo(address(this), _borrowAsset, _borrowAmount);

        // swap borrowed asset for tokenOut
        exactInputSwap(
            _borrowAsset,
            _tokenOut,
            _user,
            uint256(_borrowAmount),
            3000,
            10000
        );
    }

    function repayBorrow(
        address _pool,
        address _tokenIn,
        address _borrowedToken,
        int256 _amount,
        uint256 _nftID
    ) external {
        // take token to swap from user
        TransferHelper.safeTransferFrom(
            _tokenIn,
            msg.sender,
            address(this),
            uint(_amount)
        );
        // swap for borrowed token
        if (_borrowedToken != _tokenIn) {
            exctOutputSwap(
                _tokenIn,
                _borrowedToken,
                msg.sender,
                uint256(_amount),
                3000,
                10000
            );
        }
        // reapay borrowed token
        unilendCore.repay(_pool, _amount, msg.sender);
        // redeem lend tokens to user
        unilendCore.redeemUnderlying(_nftID, _amount, msg.sender);
    }

    function exactInputSwap(
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

    function exctOutputSwap(
        address tokenIn,
        address tokenOut,
        address _user,
        uint256 _amountIn,
        uint24 swapFee0,
        uint24 swapFee1
    ) internal {
        TransferHelper.safeApprove(tokenIn, address(swapRouter), _amountIn);

        ISwapRouter.ExactOutputParams memory params = ISwapRouter
            .ExactOutputParams({
                path: abi.encodePacked(
                    tokenIn,
                    swapFee0,
                    WETH9,
                    swapFee1,
                    tokenOut
                ),
                recipient: _user,
                deadline: block.timestamp,
                amountOut: _amountIn,
                amountInMaximum: 0
            });
        swapRouter.exactOutput(params);

        console.log("swapped", IERC20(tokenOut).balanceOf(_user));
    }
}
