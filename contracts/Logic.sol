// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
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
    function redeem(
        address _pool,
        int _token_amount,
        address _receiver
    ) external returns (int);
    function redeemUnderlying(
        address _pool,
        int _amount,
        address _receiver
    ) external returns (int);
}
interface IUnilendV2Position {
    function getNftId(address _pool, address _user) external returns (uint);
}

interface IUnilendPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUnilendHelper {
    struct outDataFull {
        uint _token0Liquidity;
        uint _token1Liquidity;
        uint _totalLendShare0;
        uint _totalLendShare1;
        uint _totalBorrowShare0;
        uint _totalBorrowShare1;
        uint _totalBorrow0;
        uint _totalBorrow1;
        uint _interest0;
        uint _interest1;
        uint _lendShare0;
        uint _borrowShare0;
        uint _lendShare1;
        uint _borrowShare1;
        uint _lendBalance0;
        uint _borrowBalance0;
        uint _lendBalance1;
        uint _borrowBalance1;
        uint _healthFactor0;
        uint _healthFactor1;
    }

    struct outData {
        uint ltv;
        uint lb;
        uint rf;
        uint _token0Liquidity;
        uint _token1Liquidity;
        address _core;
        address _token0;
        address _token1;
        string _symbol0;
        string _symbol1;
        uint _decimals0;
        uint _decimals1;
    }

    function getPoolFullData(
        address _position,
        address _pool,
        address _user
    ) external view returns (outDataFull memory);

    function getPoolData(address _pool) external view returns (outData memory);
}

interface IComet {
    function supplyTo(address dst, address asset, uint amount) external;
    function withdrawTo(address to, address asset, uint amount) external;
}

contract Logic is ReentrancyGuard {
    ISwapRouter public constant swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address constant WETH9 = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    IUnilendV2Core public constant unilendCore =
        IUnilendV2Core(0x17dad892347803551CeEE2D377d010034df64347);
    IUnilendV2Position public constant unilendPosition =
        IUnilendV2Position(0x77B6569F0dbC4F265a575a84540c2A0Cae116a90);
    IComet public constant cometAddress =
        IComet(0xF25212E676D1F7F89Cd72fFEe66158f541246445);
    IUnilendHelper public constant helper =
        IUnilendHelper(0x4F57c40D3dAA7BF2EC970Dd157B1268982158720);
    // address public immutable controller;

    event Borrowed(
        address indexed tokenAddress,
        address indexed user,
        int256 amount,
        uint256 time
    );

    event Log(uint indexed value1, uint indexed value2, uint indexed value3);

    struct BorrowSwapParams {
        address _pool;
        address _tokenIn;
        address _tokenOUt;
        address _borrowToken;
        uint256 _collateral_amount;
        int256 _amount;
    }
    struct PoolData {
        address token0;
        address token1;
        uint borrowBalance0;
        uint borrowBalance1;
        uint lendBalance1;
        uint lendBalance0;
        uint256 ltv;
    }
    struct CollateralData {
        int priceRatio;
        uint reedemable;
        uint collateral;
        uint value;
    }
    struct FeeStructure {
        address tokenIn;
        uint swapFee0;
        address weth;
        uint swapFee1;
        address tokenOut;
    }
    constructor() {
        // controller = msg.sender;
    }

    // modifier onlyController() {
    //     require(controller == msg.sender, "Not Controller");
    //     _;
    // }

    /**
     * @notice Borrow tokens from Unilend and optionally swap them to another token.
     * @param _pool The Unilend pool address.
     * @param _supplyAsset The address of the asset to supply as collateral.
     * @param _tokenOut The address of the token to receive.
     * @param _collateral_amount The amount of collateral to supply.
     * @param _amount The amount to borrow (negative for token0, positive for token1).
     * @param _user The address of the user.
     * @param _route The Uniswap fee route.
     */

    function uniBorrow(
        address _pool,
        address _supplyAsset,
        address _tokenOut,
        uint256 _collateral_amount,
        int256 _amount,
        address _user,
        uint24[] calldata _route
    ) external nonReentrant {
        address token0 = IUnilendPool(_pool).token0();
        address token1 = IUnilendPool(_pool).token1();
        address borrowToken = _amount < 0 ? token0 : token1;
        address recipient = borrowToken == _tokenOut ? _user : address(this);

        safeApproveIfNeeded(
            _supplyAsset,
            address(unilendCore),
            _collateral_amount
        );

        unilendCore.borrow(
            _pool,
            _amount,
            _collateral_amount,
            payable(recipient)
        );

        if (borrowToken != _tokenOut) {
            if (_amount < 0) _amount = -_amount;
            exactInputSwap(borrowToken, _tokenOut, _user, uint(_amount), _route);
        }
    }

    /**
     * @notice Supply asset to Comet and borrow another asset, optionally swapping it.
     * @param _supplyAsset The address of the asset to supply.
     * @param _borrowAsset The address of the asset to borrow.
     * @param _tokenOut The address of the token to receive.
     * @param _supplyAmount The amount of the asset to supply.
     * @param _borrowAmount The amount of the asset to borrow.
     * @param _user The address of the user.
     * @param _route The Uniswap fee route.
     */

    function compBorrow(
        address _supplyAsset,
        address _borrowAsset,
        address _tokenOut,
        uint _supplyAmount,
        uint _borrowAmount,
        address _user,
        uint24[] calldata _route
    ) external nonReentrant {
        safeApproveIfNeeded(_supplyAsset, address(cometAddress), _supplyAmount);

        cometAddress.supplyTo(address(this), _supplyAsset, _supplyAmount);
        address recipient = _borrowAsset == _tokenOut ? _user : address(this);

        cometAddress.withdrawTo(recipient, _borrowAsset, _borrowAmount);

        // if output is same as borrow skip swap
        if (_borrowAsset != _tokenOut) {
            exactInputSwap(
                _borrowAsset,
                _tokenOut,
                _user,
                uint256(_borrowAmount),
                _route
            );
        }
    }

    /**
     * @notice Repay borrowed asset to Comet, optionally swapping it from another token.
     * @param _borrowedToken The address of the borrowed token.
     * @param _tokenIn The address of the token to swap from.
     * @param _repayAmount The amount to repay.
     * @param _route The Uniswap fee route.
     */

    function compRepay(
        address _borrowedToken,
        address _tokenIn,
        uint256 _repayAmount,
        uint24[] calldata _route
    ) external nonReentrant {
        uint amountOut = _borrowedToken != _tokenIn
            ? exactInputSwap(
                _tokenIn,
                _borrowedToken,
                address(this),
                uint256(_repayAmount),
                _route
            )
            : _repayAmount;

        safeApproveIfNeeded(_borrowedToken, address(cometAddress), amountOut);

        cometAddress.supplyTo(address(this), _borrowedToken, amountOut);
    }

    /**
     * @notice Redeem collateral from Comet, optionally swapping it to another token.
     * @param _user The address of the user.
     * @param _collateralToken The address of the collateral token.
     * @param _collateralAmount The amount of collateral to redeem.
     * @param _tokenOut The address of the token to receive.
     * @param _route The Uniswap fee route.
     */
    // to do: calculate the totak collateral to be redeemed here and do not use all account balance for redeem.
    function compRedeem(
        address _user,
        address _collateralToken,
        uint256 _collateralAmount,
        address _tokenOut,
        uint24[] calldata _route
    ) external nonReentrant {
        address recipient = _collateralToken == _tokenOut
            ? _user
            : address(this);
        cometAddress.withdrawTo(recipient, _collateralToken, _collateralAmount);
        if (_collateralToken != _tokenOut) {
            exactInputSwap(
                _collateralToken,
                _tokenOut,
                _user,
                IERC20(_collateralToken).balanceOf(address(this)),
                _route
            );
        }
    }

    /**
     * @notice Repay borrowed tokens to Unilend, optionally swapping them from another token.
     * @param _pool The Unilend pool address.
     * @param _tokenIn The address of the token to swap from.
     * @param _user The address of the user.
     * @param _borrowAddress The address of the borrowed token.
     * @param _repayAmount The amount to repay.
     * @param _route The Uniswap fee route.
     */

    function uniRepay(
        address _pool,
        address _tokenIn,
        address _user,
        address _borrowAddress,
        uint256 _repayAmount,
        uint24[] calldata _route
    ) external nonReentrant {
        int repayAmountInt;
        PoolData memory poolData = getPoolData(
            _pool,
            address(this),
            address(unilendPosition)
        );
        uint amountOut = _borrowAddress != _tokenIn
            ? exactInputSwap(
                _tokenIn,
                _borrowAddress,
                address(this),
                uint256(_repayAmount),
                _route
            )
            : _repayAmount;

        safeApproveIfNeeded(_borrowAddress, address(unilendCore), amountOut);

        if (_borrowAddress == poolData.token0) {
            repayAmountInt = amountOut >= poolData.borrowBalance0
                ? -type(int).max
                : -int(amountOut);
        } else {
            repayAmountInt = amountOut >= poolData.borrowBalance1
                ? type(int).max
                : int(amountOut);
        }

        unilendCore.repay(_pool, repayAmountInt, address(this));

        uint256 remainingBalance = IERC20(_borrowAddress).balanceOf(
            address(this)
        );
        if (remainingBalance > 0) {
            TransferHelper.safeTransfer(
                _borrowAddress,
                _user,
                remainingBalance
            );
        }
    }

    /**
     * @notice Redeem tokens from Unilend, optionally swapping them to another token.
     * @param _pool The Unilend pool address.
     * @param _user The address of the user.
     * @param _amount The amount to redeem (negative for token0, positive for token1).
     * @param _tokenOut The address of the token to receive.
     * @param _route The Uniswap fee route.
     */

    function uniRedeem(
        address _pool,
        address _user,
        int _amount,
        address _tokenOut,
        uint24[] calldata _route
    ) external nonReentrant {
        PoolData memory poolData = getPoolData(
            _pool,
            address(this),
            address(unilendPosition)
        );

        uint nftID = unilendPosition.getNftId(_pool, address(this));
        require(nftID != 0, "No Position Found");

        address redeemToken;
        address recipient = address(this);

        if (_amount < 0) {
            redeemToken = poolData.token0;
            recipient = redeemToken == _tokenOut ? _user : address(this);
            if (poolData.borrowBalance1 > 0) {
                unilendCore.redeemUnderlying(_pool, _amount, recipient);
            } else {
                unilendCore.redeem(_pool, _amount, recipient);
            }
        } else {
            redeemToken = poolData.token1;
            recipient = redeemToken == _tokenOut ? _user : address(this);
            if (poolData.borrowBalance0 > 0) {
                unilendCore.redeemUnderlying(_pool, _amount, recipient);
            } else {
                unilendCore.redeem(_pool, _amount, recipient);
            }
        }

        if (redeemToken != _tokenOut) {
            exactInputSwap(
                redeemToken,
                _tokenOut,
                _user,
                IERC20(redeemToken).balanceOf(address(this)),
                _route
            );
        }
    }

    /**
     * @notice Internal function to get pool data from Unilend.
     * @param _pool The Unilend pool address.
     * @param _user The address of the user.
     * @param _unilendPosition The address of the Unilend position contract.
     * @return poolData The pool data struct.
     */

    function getPoolData(
        address _pool,
        address _user,
        address _unilendPosition
    ) internal view returns (PoolData memory poolData) {
        IUnilendHelper.outData memory data = helper.getPoolData(_pool);

        IUnilendHelper.outDataFull memory fullData = helper.getPoolFullData(
            _unilendPosition,
            _pool,
            _user
        );

        poolData.token0 = data._token0;
        poolData.token1 = data._token1;
        poolData.ltv = data.ltv;
        poolData.borrowBalance0 = fullData._borrowBalance0;
        poolData.borrowBalance1 = fullData._borrowBalance1;
        poolData.lendBalance0 = fullData._lendBalance0;
        poolData.lendBalance1 = fullData._lendBalance1;
    }

    /**
     * @notice Internal function to execute a Uniswap exact input swap.
     * @param tokenIn The address of the token to swap from.
     * @param tokenOut The address of the token to swap to.
     * @param _user The address of the user to receive the output tokens.
     * @param _amountIn The amount of input tokens to swap.
     * @param _route The Uniswap fee route.
     * @return amountOut The amount of output tokens received.
     */

    function exactInputSwap(
        address tokenIn,
        address tokenOut,
        address _user,
        uint256 _amountIn,
            uint24[] calldata _route
    ) internal returns (uint256 amountOut) {
        TransferHelper.safeApprove(tokenIn, address(swapRouter), _amountIn);
        bytes memory path = buildSwapPath(tokenIn, tokenOut, _route);

        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: path,
                recipient: _user,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: 0
            });
        amountOut = swapRouter.exactInput(params);
    }

    function buildSwapPath(
        address tokenIn,
        address tokenOut,
        uint24[] calldata _route
    ) internal pure returns (bytes memory path) {
        if (_route.length > 1) {
            path = abi.encodePacked(
                tokenIn,
                _route[0],
                WETH9,
                _route[1],
                tokenOut
            );
        } else {
            path = abi.encodePacked(tokenIn, _route[0], tokenOut);
        }
    }

    function safeApproveIfNeeded(
        address token,
        address spender,
        uint256 amount
    ) internal {
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        if (allowance < amount) {
            TransferHelper.safeApprove(token, spender, type(uint256).max);
        }
    }
}
