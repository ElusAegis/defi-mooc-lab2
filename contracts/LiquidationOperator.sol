//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "hardhat/console.sol";
import "./ICurveFi.sol";

// ----------------------INTERFACE------------------------------

// Aave
// https://docs.aave.com/developers/the-core-protocol/lendingpool/ilendingpool


library DataTypes {
  // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
  struct ReserveData {
    //stores the reserve configuration
    ReserveConfigurationMap configuration;
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    //tokens addresses
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint8 id;
  }

  struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: Reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60-63: reserved
    //bit 64-79: reserve factor
    uint256 data;
  }

  struct UserConfigurationMap {
    uint256 data;
  }

  enum InterestRateMode {NONE, STABLE, VARIABLE}
}

interface ILendingPool {
    /**
     * Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
     * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
     *   a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
     * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of theliquidation
     * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
     * @param user The address of the borrower getting liquidated
     * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
     * @param receiveAToken `true` if the liquidators wants to receive the collateral aTokens, `false` if he wants
     * to receive the underlying collateral asset directly
     **/
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;

    /**
     * Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralETH the total collateral in ETH of the user
     * @return totalDebtETH the total debt in ETH of the user
     * @return availableBorrowsETH the borrowing power left of the user
     * @return currentLiquidationThreshold the liquidation threshold of the user
     * @return ltv the loan to value of the user
     * @return healthFactor the current health factor of the user
     **/
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );


    function getUserConfiguration(address user)
        external
        view
        returns (
            DataTypes.UserConfigurationMap memory
        );


    function getReserveData(address asset)
        external
        view
        returns (
            DataTypes.ReserveData memory
        );

    function getReservesList() external view returns (address[] memory);

}

// UniswapV2

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IERC20.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/Pair-ERC-20
interface IERC20 {
    // Returns the account balance of another account with address _owner.
    function balanceOf(address owner) external view returns (uint256);

    /**
     * Allows _spender to withdraw from your account multiple times, up to the _value amount.
     * If this function is called again it overwrites the current allowance with _value.
     * Lets msg.sender set their allowance for a spender.
     **/
    function approve(address spender, uint256 value) external; // return type is deleted to be compatible with USDT

    /**
     * Transfers _value amount of tokens to address _to, and MUST fire the Transfer event.
     * The function SHOULD throw if the message caller’s account balance does not have enough tokens to spend.
     * Lets msg.sender send pool tokens to an address.
     **/
    function transfer(address to, uint256 value) external returns (bool);
}

// https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IWETH.sol
interface IWETH is IERC20 {
    // Convert the wrapped token back to Ether.
    function withdraw(uint) external;
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Callee.sol
// The flash loan liquidator we plan to implement this time should be a UniswapV2 Callee
interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external;
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Factory.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/factory
interface IUniswapV2Factory {
    // Returns the address of the pair for tokenA and tokenB, if it has been created, else address(0).
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/pair
interface IUniswapV2Pair {
    /**
     * Swaps tokens. For regular swaps, data.length must be 0.
     * Also see [Flash Swaps](https://docs.uniswap.org/protocol/V2/concepts/core-concepts/flash-swaps).
     **/
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata
    ) external;

    /**
     * Returns the reserves of token0 and token1 used to price trades and distribute liquidity.
     * See Pricing[https://docs.uniswap.org/protocol/V2/concepts/advanced-topics/pricing].
     * Also returns the block.timestamp (mod 2**32) of the last block during which an interaction occured for the pair.
     **/
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

// ----------------------IMPLEMENTATION------------------------------

contract LiquidationOperator is IUniswapV2Callee {

    struct BorrowingTokenAndBalance {
        address token;
        uint256 debt;
    }

    struct CollateralTokenAndBalance {
        address token;
        uint256 collateral;
    }

    uint8 public constant health_factor_decimals = 18;

    // TODO: define constants used in the contract including ERC-20 tokens, Uniswap Pairs, Aave lending pools, etc. */
    //    *** Your code here ***
    ILendingPool private LENDING_POOL = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    IUniswapV2Factory private SUSHI_FACTORY = IUniswapV2Factory(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);
    IUniswapV2Factory private UNISWAP_FACTORY = IUniswapV2Factory(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);

    IERC20 private A_WBTC = IERC20(0x9ff58f4fFB29fA2266Ab25e75e2A8b3503311656);
    IERC20 private USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 private USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IWETH private WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 private WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);


    address private TARGET = 0x59CE4a2AC5bC3f5F225439B2993b86B42f6d3e9F;

    BorrowingTokenAndBalance[] borrowingTokens;
    CollateralTokenAndBalance[] collateralTokens;

    address payable owner;
    // END TODO

    // some helper function, it is totally fine if you can finish the lab without using these function
    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // some helper function, it is totally fine if you can finish the lab without using these function
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    function isUsingAsCollateral(DataTypes.UserConfigurationMap memory config, uint256 reserveIndex)
        internal
        pure
        returns (bool) {
        require(reserveIndex < 128);
        return (config.data >> (reserveIndex * 2 + 1)) & 1 != 0;
    }

    function isBorrowing(DataTypes.UserConfigurationMap memory config, uint256 reserveIndex)
        internal
        pure
        returns (bool) {
        require(reserveIndex < 128);
        return (config.data >> (reserveIndex * 2)) & 1 != 0;
      }

    constructor() {
        // TODO: (optional) initialize your contract
        //   *** Your code here ***
        owner = payable (msg.sender);
        // END TODO
    }

    // TODO: add a `receive` function so that you can withdraw your WETH
     receive() external payable {
    }
    // END TODO

    // required by the testing script, entry for your liquidation call
    function operate() external {
        // TODO: implement your liquidation logic

        // 0. security checks and initializing variables
        //    *** Your code here ***
        (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = LENDING_POOL.getUserAccountData(TARGET);

        assert(healthFactor < 1 ether); // Position is possible to be liquidated


        // Iterate over all resevers and find ones the user is borrowing:
        address[] memory reserves = LENDING_POOL.getReservesList();
        DataTypes.UserConfigurationMap memory userConf = LENDING_POOL.getUserConfiguration(TARGET);



        // Only run for first 10 tokens, for each, check if the user used it as a collateral or as a borrowing asset
        // For each, add the amount the user has deposited as a collateral / borrowed
        for (uint i = 0; i < reserves.length && i < 10; i++) {
            if (isBorrowing(userConf, i)) {

                address reserveToken = reserves[i];
                DataTypes.ReserveData memory reserveData = LENDING_POOL.getReserveData(reserveToken);

                uint256 totalDebt = IERC20(reserveData.stableDebtTokenAddress).balanceOf(TARGET)
                    + IERC20(reserveData.variableDebtTokenAddress).balanceOf(TARGET);

                borrowingTokens.push(BorrowingTokenAndBalance ( reserveToken, totalDebt ));

                continue;

            }

            if (isUsingAsCollateral(userConf, i)) {

                address reserveToken = reserves[i];
                DataTypes.ReserveData memory reserveData = LENDING_POOL.getReserveData(reserveToken);

                uint256 totalCollateral = IERC20(reserveData.aTokenAddress).balanceOf(TARGET);


                collateralTokens.push(CollateralTokenAndBalance(reserveToken, totalCollateral));

                continue;
            }


            // Take pairs of collateral and debt, and attempt to liquidate them
            while (borrowingTokens.length != 0 && collateralTokens.length != 0) {

                CollateralTokenAndBalance storage currentCollateralTokenP = collateralTokens[collateralTokens.length - 1];
                BorrowingTokenAndBalance storage currentBorrowingTokenP = borrowingTokens[borrowingTokens.length - 1];


                // Check if there is an exchange pair registered:
                address swapEthToCollateralPair = SUSHI_FACTORY.getPair(currentCollateralTokenP.token, address(WETH));
                address swapEthToBorrowingPair = UNISWAP_FACTORY.getPair(currentBorrowingTokenP.token, address(WETH));

                // If exchange pair does not exist, then skip the token
                if (swapEthToCollateralPair ==  address(0)) {
                    collateralTokens.pop();
                    continue;
                }
                if (swapEthToBorrowingPair ==  address(0)) {
                    borrowingTokens.pop();
                    continue;
                }

                // TODO - check if the liquidity is sufficient in an exchange pair

                (
                    uint256 collateral_reserve0,
                    uint256 eth_reserve1_0,
                    uint32 _timestamp_0
                ) = IUniswapV2Pair(swapEthToCollateralPair).getReserves();
                uint256 ethCollateralBalance = getAmountOut(currentCollateralTokenP.collateral, collateral_reserve0, eth_reserve1_0);

                (
                    uint256 borrowing_reserve0,
                    uint256 eth_reserve1_1,
                    uint32 _timestamp_1
                ) = IUniswapV2Pair(swapEthToBorrowingPair).getReserves();
                uint256 ethBorrowingBalance = getAmountOut(currentBorrowingTokenP.debt, borrowing_reserve0, eth_reserve1_1);

                uint256 liquidAmountEth;
                if (ethCollateralBalance * currentLiquidationThreshold / 1000 >= ethBorrowingBalance * 1000 ) {
                    borrowingTokens.pop(); // We no longer can use this token as borrowing asset
                    liquidAmountEth = ethBorrowingBalance;
                    currentCollateralTokenP.collateral -= getAmountOut(liquidAmountEth, eth_reserve1_1, collateral_reserve0);
                } else {
                    collateralTokens.pop(); // We no longer can use this token as collateral asset
                    liquidAmountEth = ethCollateralBalance * currentLiquidationThreshold / 1000;
                    currentBorrowingTokenP.debt -= getAmountOut(liquidAmountEth, eth_reserve1_1, borrowing_reserve0);
                }


                singleOperation(swapEthToCollateralPair, swapEthToBorrowingPair, liquidAmountEth, currentCollateralTokenP.token, currentBorrowingTokenP.token);


            }
        }
    }

    // Single liquidation operation based on two exchange pairs and amount to be liquidated in Ethereum
    function singleOperation(address swapEthToCollateralPair, address swapEthToBorrowingPair, uint256 liquidAmountEth, address collateralToken, address borrowToken) internal {


        // 2. call flash swap to liquidate the target user
        (
            uint112 borrowing_reserve0,
            uint112 ETH_reserve1,
            uint32 _timestamp
        ) = IUniswapV2Pair(swapEthToBorrowingPair).getReserves();

        uint256 borrowedAssetNeeded = getAmountOut(liquidAmountEth, ETH_reserve1, borrowing_reserve0);


        bytes memory data = abi.encode(swapEthToCollateralPair, swapEthToBorrowingPair, liquidAmountEth, collateralToken, borrowToken);

        IUniswapV2Pair(swapEthToBorrowingPair).swap(borrowedAssetNeeded, 0, address(this), data);

        // based on https://etherscan.io/tx/0xac7df37a43fab1b130318bbb761861b8357650db2e2c6493b73d6da3d9581077
        // we know that the target user borrowed USDT with WBTC as collateral
        // we should borrow USDT, liquidate the target user and get the WBTC, then swap WBTC to repay uniswap
        // (please feel free to develop other workflows as long as they liquidate the target user successfully)


        // 3. Convert the profit into ETH and send back to sender
        //    *** Your code here ***

        // END TODO
    }

    // required by the swap
    function uniswapV2Call(
        address,
        uint256,
        uint256 amount1,
        bytes calldata data
    ) external override {

        address myAddress = address(this);
        (address swapEthToCollateralPair, address swapEthToBorrowingPair, uint256 liquidAmountEth, address collateralToken, address borrowToken) = abi.decode(data, (address, address, uint256, address, address));


        // 2.1 liquidate the target user
        uint256 borrowBalance = IERC20(borrowToken).balanceOf(myAddress);
        IERC20(borrowToken).approve(address(LENDING_POOL), borrowBalance);

        LENDING_POOL.liquidationCall(collateralToken, borrowToken, TARGET, borrowBalance, false);


        // 2.2 swap Collateral for other things or repay directly
        uint256 collateralBalance = IERC20(collateralToken).balanceOf(myAddress);
        IERC20(collateralToken).transfer(swapEthToCollateralPair, collateralBalance);

        (
            uint256 collateral_reserve0,
            uint256 eth_reserve1,
            uint32 _timestamp
        ) = IUniswapV2Pair(swapEthToCollateralPair).getReserves();
        uint256 amountEarned = getAmountOut(collateralBalance, collateral_reserve0, eth_reserve1);

        bytes memory empty_bytes;
        IUniswapV2Pair(swapEthToCollateralPair).swap(0, amountEarned, myAddress, empty_bytes);


        // 2.3 repay
        WETH.transfer(swapEthToBorrowingPair, liquidAmountEth);


        // 2.4 transfer profit
        uint256 profit = WETH.balanceOf(myAddress);
        WETH.withdraw(profit);

        owner.transfer(profit);
        
        // END TODO
    }
}
