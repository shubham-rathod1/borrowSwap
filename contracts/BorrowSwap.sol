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
    function redeem(
        address _pool,
        int _token_amount,
        address _receiver
    ) external returns (int);
    function getOraclePrice(
        address _token0,
        address _token1,
        uint _amount
    ) external view returns (uint);
    function redeemUnderlying(
        address _pool,
        int _amount,
        address _receiver
    ) external returns (int);
}
interface IUnilendV2Position {
    // struct nftPositionData {
    //     address token0;
    //     address token1;
    //     uint lendBalance0;
    //     uint borrowBalance0;
    //     uint lendBalance1;
    //     uint borrowBalance1;
    // }
    function getNftId(address _pool, address _user) external returns (uint);
    // function position(uint _nftID) external view returns (nftPositionData memory);
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

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract BorrowSwap {
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
    // address public OracleAddress;

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
    // make constructor values hardcode and use init function
    constructor() {
        controller = msg.sender;
    }

    modifier onlyController() {
        require(controller == msg.sender, "Not Controller");
        _;
    }

    // function setOracleAddress(address _oracleAddress) external {
    //     require(_oracleAddress != address(0), "Zero address");
    //     OracleAddress = _oracleAddress;
    // }

    function getLatestPrice(
        AggregatorV3Interface priceFeed
    ) public view returns (int price) {
        (
            ,
            /*uint80 roundID*/ price,
            /*uint startedAt*/
            /*uint timeStamp*/
            /*uint80 answeredInRound*/
            ,
            ,

        ) = priceFeed.latestRoundData();
    }

    function InitBorrow(
        address _pool,
        address _supplyAsset,
        address _tokenOUt,
        uint256 _collateral_amount,
        int256 _amount,
        address _user,
        uint24[] memory _route
    ) external {
        address token0 = IUnilendPool(_pool).token0();
        address token1 = IUnilendPool(_pool).token1();
        address borrowToken;

        if (_amount < 0) {
            borrowToken = token0;
        } else {
            borrowToken = token1;
        }

        // approve lending protocol
        TransferHelper.safeApprove(
            _supplyAsset,
            address(unilendCore),
            _collateral_amount
        );
        // borrowing from lending protocol
        unilendCore.borrow(
            _pool,
            _amount,
            _collateral_amount,
            payable(address(this))
        );

        if (_amount < 0) _amount = -_amount;

        // FeeStructure memory decoded = abi.decode(_route, (FeeStructure));

        // emit Log(decoded.fee0, decoded.fee1, 0);

        exactInputSwap(
            borrowToken,
            _tokenOUt,
            _user,
            IERC20(borrowToken).balanceOf(address(this)),
            _route
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
        cometAddress.supplyTo(address(this), _supplyAsset, _supplyAmount);
        //  Borrow as asset from Comopound III
        cometAddress.withdrawTo(address(this), _borrowAsset, _borrowAmount);
        // swap borrowed asset for tokenOut
        // exactInputSwap(
        //     _borrowAsset,
        //     _tokenOut,
        //     _user,
        //     uint256(_borrowAmount),
        //     3000,
        //     10000
        //     // 500,
        //     // 3000
        // );
    }

    function compRepay(
        address _borrowedToken,
        address _tokenIn,
        address _user,
        address _collateralToken,
        uint256 _collateralAmount,
        uint256 _repayAmount
    ) external {
        if (_borrowedToken != _tokenIn) {
            // if (_repayAmount < 0) repayAmount = -_repayAmount;
            // exactInputSwap(
            //     _tokenIn,
            //     _borrowedToken,
            //     address(this),
            //     uint256(_repayAmount),
            //     3000,
            //     10000
            // );
        }
        uint256 bal = IERC20(_borrowedToken).balanceOf(address(this));

        // emit Log(bal, address(0), "swapped bal on proxy");

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
        //  Borrow as asset from Comopound III
        cometAddress.withdrawTo(_user, _collateralToken, _collateralAmount);
    }

    function emptyFn() external pure returns (uint result) {
        result = 100;
    }

    function uniRepay(
        address _pool,
        address _tokenIn,
        address _user,
        address _borrowAddress,
        uint256 _repayAmount,
        uint24[] memory _route
    ) external {
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

        // emit Log(amountOut, 0, 0);

        TransferHelper.safeApprove(
            _borrowAddress,
            address(unilendCore),
            type(uint256).max
        );

        if (_borrowAddress == poolData.token0) {
            repayAmount = -int(amountOut);
        } else {
            repayAmount = int(amountOut);
        }

        unilendCore.repay(_pool, repayAmount, address(this));

        if (IERC20(_borrowAddress).balanceOf(address(this)) > 0) {
            TransferHelper.safeTransfer(
                _borrowAddress,
                _user,
                IERC20(_borrowAddress).balanceOf(address(this))
            );
        }

        // reapay borrowed token
        // uint256 nftID = unilendPosition.getNftId(_pool, _user);

        // require(nftID == 5, "id not 5");

        // int price0 = getLatestPrice(AggregatorV3Interface(_source0));
        // int price1 = getLatestPrice(AggregatorV3Interface(_source1));

        // CollateralData memory collateralData;

        // if (_borrowedToken == poolData.token0) {
        //     // collateralData.priceRatio = price0 / price1;
        //     collateralData.value = unilendCore.getOraclePrice(
        //         poolData.token0,
        //         poolData.token1,
        //         poolData.borrowBalance0
        //     );
        //     collateralData.collateral =
        //         (collateralData.value * 1e18) /
        //         (poolData.ltv * 1e18) /
        //         100;
        //     collateralData.reedemable =
        //         poolData.lendBalance1 -
        //         collateralData.collateral;
        // } else {
        //     collateralData.value = unilendCore.getOraclePrice(
        //         poolData.token1,
        //         poolData.token0,
        //         poolData.borrowBalance1
        //     );
        //     collateralData.collateral =
        //         (collateralData.value * 1e18) /
        //         (poolData.ltv * 1e18) /
        //         100;
        //     collateralData.reedemable =
        //         poolData.lendBalance1 -
        //         collateralData.collateral;
        // }
        // emit Log(
        //     uint(collateralData.collateral),
        //     uint(collateralData.reedemable),
        //     uint(collateralData.value)
        // );
        // return collateralData.reedemable;
        // unilendCore.redeem(nftID, type(uint).max, _user);
    }

    function redeem(
        address _pool,
        address _user,
        int _amount,
        address _tokenOut,
        uint24[] memory _route
    ) external {
        PoolData memory poolData = getPoolData(
            _pool,
            address(this),
            address(unilendPosition)
        );
        uint borrowBalance0 = poolData.borrowBalance0;
        uint borrowBalance1 = poolData.borrowBalance1;

        uint nftID = unilendPosition.getNftId(_pool, address(this));

        require(nftID != 0, "No Position Found");

        // max - redeem, partial - redeemUnderlying;
        if (_amount < 0) {
            if (borrowBalance1 > 0) {
                unilendCore.redeemUnderlying(_pool, _amount, address(this));
                // emit Log(1, borrowBalance1, 0);
            } else {
                unilendCore.redeem(_pool, _amount, address(this));
                // emit Log(0, 1, borrowBalance1);
            }
        } else {
            if (borrowBalance0 > 0) {
                unilendCore.redeemUnderlying(_pool, _amount, address(this));
                // emit Log(0, borrowBalance0, 1);
            } else {
                unilendCore.redeem(_pool, _amount, address(this));
                // emit Log(1, 1, borrowBalance0);
            }
        }

        // if (_borrowedToken != _tokenIn) {
        //     if (_repayAmount < 0) repayAmount = -_repayAmount;
        //     exactInputSwap(
        //         _tokenIn,
        //         _borrowedToken,
        //         _user,
        //         uint256(_repayAmount),
        //         _route
        //     );
        // }
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

    function exctOutputSwap(
        address tokenIn,
        address tokenOut,
        address _user,
        uint256 _amountIn,
        uint24 swapFee0,
        uint24 swapFee1
    ) internal {
        TransferHelper.safeApprove(
            tokenIn,
            address(swapRouter),
            type(uint256).max
        );

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
