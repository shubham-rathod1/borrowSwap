// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface IUnilendV2Core {
    function getOraclePrice(
        address _token0,
        address _token1,
        uint _amount
    ) external view returns (uint);
}
interface IUnilendV2Position {
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

contract Helper {
    address constant WETH9 = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    IUnilendV2Core public constant unilendCore =
        IUnilendV2Core(0x17dad892347803551CeEE2D377d010034df64347);
    IUnilendV2Position public constant unilendPosition =
        IUnilendV2Position(0x77B6569F0dbC4F265a575a84540c2A0Cae116a90);
    IComet public constant cometAddress =
        IComet(0xF25212E676D1F7F89Cd72fFEe66158f541246445);
    IUnilendHelper public constant helper =
        IUnilendHelper(0x4F57c40D3dAA7BF2EC970Dd157B1268982158720);

    event Log(uint indexed value1, uint indexed value2, uint indexed value3);

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
    // make constructor values hardcode and use init function
    constructor() {
       
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
}
