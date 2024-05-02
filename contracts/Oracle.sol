// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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

contract PriceFeed {
    constructor() {}
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
}
