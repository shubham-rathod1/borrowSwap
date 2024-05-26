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

contract BorrowSwap is ReentrancyGuard {
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
    address public immutable controller;

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
        controller = msg.sender;
    }

    modifier onlyController() {
        require(controller == msg.sender, "Not Controller");
        _;
    }

    function uniBorrow(
        address _pool,
        address _supplyAsset,
        address _tokenOut,
        uint256 _collateral_amount,
        int256 _amount,
        address _user,
        uint24[] memory _route
    ) external nonReentrant {
        address token0 = IUnilendPool(_pool).token0();
        address token1 = IUnilendPool(_pool).token1();
        address borrowToken;
        address recipient = address(this);

        if (_amount < 0) {
            borrowToken = token0;
        } else {
            borrowToken = token1;
        }
        if (borrowToken == _tokenOut) {
            recipient = _user;
        }
        TransferHelper.safeApprove(
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

            exactInputSwap(
                borrowToken,
                _tokenOut,
                _user,
                IERC20(borrowToken).balanceOf(address(this)),
                _route
            );
        }
    }

    function compBorrow(
        address _supplyAsset,
        address _borrowAsset,
        address _tokenOut,
        uint _supplyAmount,
        uint _borrowAmount,
        address _user,
        uint24[] memory _route
    ) external nonReentrant {
        TransferHelper.safeApprove(
            _supplyAsset,
            address(cometAddress),
            _supplyAmount
        );
        address recipient = address(this);
        cometAddress.supplyTo(recipient, _supplyAsset, _supplyAmount);
        if (_borrowAsset == _tokenOut) {
            recipient = _user;
        }
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

    function compRepay(
        address _borrowedToken,
        address _tokenIn,
        uint256 _repayAmount,
        uint24[] memory _route
    ) external nonReentrant {
        if (_borrowedToken != _tokenIn) {
            exactInputSwap(
                _tokenIn,
                _borrowedToken,
                address(this),
                uint256(_repayAmount),
                _route
            );
        }
        TransferHelper.safeApprove(
            _borrowedToken,
            address(cometAddress),
            type(uint256).max
        );

        cometAddress.supplyTo(
            address(this),
            _borrowedToken,
            IERC20(_borrowedToken).balanceOf(address(this))
        );
    }

    function compRedeem(
        address _user,
        address _collateralToken,
        uint256 _collateralAmount,
        address _tokenOut,
        uint24[] memory _route
    ) external nonReentrant {
        address recipient = address(this);
        if (_collateralToken == _tokenOut) {
            recipient = _user;
        }
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

    function uniRepay(
        address _pool,
        address _tokenIn,
        address _user,
        address _borrowAddress,
        uint256 _repayAmount,
        uint24[] memory _route
    ) external nonReentrant {
        int repayAmount;
        uint amountOut;

        PoolData memory poolData = getPoolData(
            _pool,
            address(this),
            address(unilendPosition)
        );

        // swap for borrowed token
        if (_borrowAddress != _tokenIn) {
            amountOut = exactInputSwap(
                _tokenIn,
                _borrowAddress,
                address(this),
                uint256(_repayAmount),
                _route
            );
        } else {
            amountOut = _repayAmount;
        }

        TransferHelper.safeApprove(
            _borrowAddress,
            address(unilendCore),
            type(uint256).max
        );

        if (_borrowAddress == poolData.token0) {
            if (repayAmount > int(poolData.borrowBalance0)) {
                repayAmount = -type(int).max;
            } else {
                repayAmount = -int(amountOut);
            }
            // repayAmount = -int(amountOut);
        } else {
            if (repayAmount > int(poolData.borrowBalance1)) {
                repayAmount = type(int).max;
            } else {
                repayAmount = int(amountOut);
            }
        }

        unilendCore.repay(_pool, repayAmount, address(this));

        if (IERC20(_borrowAddress).balanceOf(address(this)) > 0) {
            TransferHelper.safeTransfer(
                _borrowAddress,
                _user,
                IERC20(_borrowAddress).balanceOf(address(this))
            );
        }
    }

    function uniRedeem(
        address _pool,
        address _user,
        int _amount,
        address _tokenOut,
        uint24[] memory _route
    ) external nonReentrant {
        PoolData memory poolData = getPoolData(
            _pool,
            address(this),
            address(unilendPosition)
        );
        uint borrowBalance0 = poolData.borrowBalance0;
        uint borrowBalance1 = poolData.borrowBalance1;

        uint nftID = unilendPosition.getNftId(_pool, address(this));

        require(nftID != 0, "No Position Found");
        address redeemToken;
        address recipient = address(this);
        if (redeemToken == _tokenOut) {
            recipient = _user;
        }

        if (_amount < 0) {
            redeemToken = poolData.token0;
            if (borrowBalance1 > 0) {
                unilendCore.redeemUnderlying(_pool, _amount, recipient);
                // emit Log(1, borrowBalance1, 0);
            } else {
                unilendCore.redeem(_pool, _amount, recipient);
                // emit Log(0, 1, borrowBalance1);
            }
        } else {
            redeemToken = poolData.token1;
            if (borrowBalance0 > 0) {
                unilendCore.redeemUnderlying(_pool, _amount, recipient);
                // emit Log(0, borrowBalance0, 1);
            } else {
                unilendCore.redeem(_pool, _amount, recipient);
                // emit Log(1, 1, borrowBalance0);
            }
        }

        // if swap is not skipped send redeem value to user

        if (redeemToken != _tokenOut) {
            // if (_repayAmount < 0) repayAmount = -_repayAmount;
            exactInputSwap(
                redeemToken,
                _tokenOut,
                _user,
                IERC20(redeemToken).balanceOf(address(this)),
                _route
            );
        }
    }

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
        poolData.token0 = data._token0;
    }

    function exactInputSwap(
        address tokenIn,
        address tokenOut,
        address _user,
        uint256 _amountIn,
        uint24[] memory _route
    )
        internal
        returns (
            // bytes calldata route
            uint256 amountOut
        )
    {
        TransferHelper.safeApprove(tokenIn, address(swapRouter), _amountIn);
        bytes memory path;
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
}
