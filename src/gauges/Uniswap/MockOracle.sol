// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ===================== ComboOracle_UniV2_UniV3 ======================
// ====================================================================
// Aggregates prices for SLP, UniV2, and UniV3 style LP tokens

// Frax Finance: https://github.com/FraxFinance

// Primary Author(s)
// Travis Moore: https://github.com/FortisFortuna

// Reviewer(s) / Contributor(s)
// Jason Huan: https://github.com/jasonhuan
// Sam Kazemian: https://github.com/samkazemian

/// Other imports may be needed if using real-time price feeds - CURRENTLY HARDCODED FOR TESTING!
// import "./AggregatorV3Interface.sol";
// import "./IPricePerShareOptions.sol";
// import "../Staking/Owned.sol";
// import '../Math/HomoraMath.sol';
// UniV2 / SLP
// import "../Uniswap/Interfaces/IUniswapV2Pair.sol";
// import "../Uniswap/Interfaces/IUniswapV2Router02.sol";
// UniV3
// import "../Uniswap_V3/IUniswapV3Factory.sol";
// import "../Uniswap_V3/libraries/TickMath.sol";
// import "../Uniswap_V3/libraries/LiquidityAmounts.sol";
// import "../Uniswap_V3/IUniswapV3Pool.sol";
// import "../Uniswap_V3/ISwapRouter.sol";

// Active Imports
import "lib/forge-std/src/console.sol";
import "src/gauges/Uniswap/Interfaces/INonFungiblePositionManager.sol";
import "src/gauges/Utils/MockERC20.sol";

// import "../Oracle/ComboOracle.sol"; // Added at bottom of file, can be modified for testing use or call on-chain.


contract ComboOracle_UniV2_UniV3 { // is Owned {
    // using SafeMath for unt256;
    // using HomoraMath for uint256;
    
    /* ========== STATE VARIABLES ========== */
    
    // Core addresses
    // address timelock_address;
    // address public frax__address = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    // address public fxs__address = 0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0;

    // Oracle info
    ComboOracle public combo_oracle; // = ComboOracle(0x878f2059435a19C79c20318ee57657bF4543B6d4);

    // UniV2 / SLP
    // IUniswapV2Router02 public router;

    // UniV3
    // IUniswapV3Factory public univ3_factory;
    // INonfungiblePositionManager public univ3_positions;
    IUniswapV3Factory public univ3_factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    INonfungiblePositionManager public univ3_positions = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    // ISwapRouter public univ3_router;

    // Precision
    uint256 public PRECISE_PRICE_PRECISION = 1e18;
    uint256 public PRICE_PRECISION = 1e6;
    uint256 public PRICE_MISSING_MULTIPLIER = 1e12;

    /* ========== STRUCTS ========== */

    // ------------ UniV3 ------------

    struct UniV3NFTBasicInfo {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 token0_decimals; 
        uint256 token1_decimals; 
        uint256 lowest_decimals; 
    }

    struct UniV3NFTValueInfo {
        uint256 token0_value;
        uint256 token1_value;
        uint256 total_value;
        string token0_symbol;
        string token1_symbol;
        uint256 liquidity_price;
    }
    
    /* ========== CONSTRUCTOR ========== */

    constructor (
    ) { // Owned(msg.sender) {

        // Core addresses
        // frax_address = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
        // fxs_address = 0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0;

        // Oracle info
        combo_oracle = ComboOracle(0x878f2059435a19C79c20318ee57657bF4543B6d4);//0x2AD064cEBA948A2B062ba9AfF91c98B9F0a1f608);//_starting_addresses[2]);

        // UniV2 / SLP
        // router = IUniswapV2Router02(_starting_addresses[3]);

        // UniV3
        univ3_factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        univ3_positions = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
        // univ3_router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    }

    /* ========== MODIFIERS ========== */

    // modifier onlyByOwnGov() {
    //     require(msg.sender == owner || msg.sender == timelock_address, "You are not an owner or the governance timelock");
    //     _;
    // }

    /* ========== VIEWS ========== */
    function getUniV3NFTBasicInfo(uint256 token_id) public view returns (UniV3NFTBasicInfo memory) {
        // Get the position information
        (
            ,                   // [0]
            ,                   // [1]
            address token0,     // [2]
            address token1,     // [3]
            uint24 fee,         // [4]
            int24 tickLower,    // [5]
            int24 tickUpper,    // [6]
            uint128 liquidity,  // [7]
            ,                   // [8]
            ,                   // [9]
            ,                   // [10]
                                // [11]
        ) = univ3_positions.positions(token_id);

        // Get decimals
        uint256 tkn0_dec = 18; // ERC20(token0).decimals(); FRAX has 18
        uint256 tkn1_dec = 6; // ERC20(token1).decimals(); USDC has 6

        return UniV3NFTBasicInfo(
            token0, // [0]
            token1, // [1]
            fee, // [2]
            tickLower, // [3]
            tickUpper, // [4]
            liquidity, // [5]
            tkn0_dec,  // [6]
            tkn1_dec,  // [7]
            (tkn0_dec < tkn1_dec) ? tkn0_dec : tkn1_dec // [8]
        );
    }

    // Get stats about a particular UniV3 NFT
    function getUniV3NFTValueInfo(uint256 token_id) public view returns (UniV3NFTValueInfo memory) {
        UniV3NFTBasicInfo memory lp_basic_info = getUniV3NFTBasicInfo(token_id);

        // Get pool price info
        uint160 sqrtPriceX96;

        {
            address fraxusdcpool = address(0xc63B0708E2F7e69CB8A1df0e1389A98C35A76D52);
            // address pool_address = univ3_factory.getPool(lp_basic_info.token0, lp_basic_info.token1, lp_basic_info.fee);
            IUniswapV3Pool the_pool = IUniswapV3Pool(fraxusdcpool);
            (sqrtPriceX96, , , , , , ) = the_pool.slot0();
        }

        // Tick math
        uint256 token0_val_usd = 0;
        uint256 token1_val_usd = 0; 
        {
            // Get the amount of each underlying token in each NFT
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(lp_basic_info.tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(lp_basic_info.tickUpper);

            // Get amount of each token for 0.1% liquidity movement in each direction (1 per mille)
            uint256 liq_pricing_divisor = (10 ** lp_basic_info.lowest_decimals);
            (uint256 token0_1pm_amt, uint256 token1_1pm_amt) = LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, uint128(lp_basic_info.liquidity / liq_pricing_divisor));
            // Get missing decimals
            uint256 token0_miss_dec_mult = 10 ** (uint(18) - lp_basic_info.token0_decimals);
            uint256 token1_miss_dec_mult = 10 ** (uint(18) - lp_basic_info.token1_decimals);

            // Get token prices
            // Will revert if ComboOracle doesn't have a price for both token0 and token1
            console2.log("getToken0", address(lp_basic_info.token0));
            /// @notice this is a hardcoded price for FRAX on Aug 15 2022 @ 14:15 Pacific
            /// @dev this combo_oracle call seems to fail because it isn't passing in the correct address
            (uint256 token0_precise_price) = 1000549490000000000;// combo_oracle.getTokenPrice(lp_basic_info.token0);
            console2.log("HARDCODED token0_precise_price", token0_precise_price);
            console2.log("getToken1", address(lp_basic_info.token1));
            /// @notice this is a hardcoded price for USDC on Aug 15 2022 @ 14:15 Pacific
            (uint256 token1_precise_price) = 999894240000000000;//combo_oracle.getTokenPrice(lp_basic_info.token1);
            console2.log("HARDCODED token1_precise_price", token1_precise_price);

            // Get the value of each portion
            // Multiply by liq_pricing_divisor as well
            token0_val_usd = (token0_1pm_amt * liq_pricing_divisor * token0_precise_price * token0_miss_dec_mult) / PRECISE_PRICE_PRECISION;
            token1_val_usd = (token1_1pm_amt * liq_pricing_divisor * token1_precise_price * token1_miss_dec_mult) / PRECISE_PRICE_PRECISION;
            console2.log("token0_val_usd", token0_val_usd);
            console2.log("token1_val_usd", token1_val_usd);

        }

        // Return the total value of the UniV3 NFT
        uint256 nft_ttl_val = (token0_val_usd + token1_val_usd);
        uint valToReturn = (uint256(lp_basic_info.liquidity) * PRECISE_PRICE_PRECISION) / nft_ttl_val;

        // Return
        return UniV3NFTValueInfo(
            token0_val_usd,
            token1_val_usd,
            nft_ttl_val,
            "FRAX", // ERC20(lp_basic_info.token0).symbol(), /// HARD CODED FOR TESTING ONLY
            "USDC", // ERC20(lp_basic_info.token1).symbol(), /// HARD CODED FOR TESTING ONLY
            // (uint256(lp_basic_info.liquidity) * PRECISE_PRICE_PRECISION) / nft_ttl_val
            valToReturn
        );
    }

    /* ========== RESTRICTED GOVERNANCE FUNCTIONS ========== */

    // function setTimelock(address _timelock_address) external onlyByOwnGov {
    //     timelock_address = _timelock_address;
    // }

    // function setComboOracle(address _combo_oracle) external onlyByOwnGov {
    //     combo_oracle = ComboOracle(_combo_oracle);
    // }

    // function setUniV2Addrs(address _router) external onlyByOwnGov {
    //     // UniV2 / SLP
    //     router = IUniswapV2Router02(_router);
    // }

    // function setUniV3Addrs(address _factory, address _positions_nft_manager, address _router) external onlyByOwnGov {
    //     // UniV3
    //     univ3_factory = IUniswapV3Factory(_factory);
    //     univ3_positions = INonfungiblePositionManager(_positions_nft_manager);
    //     univ3_router = ISwapRouter(_router);
    // }
}


/// INTERFACES FOR UNISWAP V3 ///

interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);
}

interface IUniswapV3Pool {
    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}


/// @title Math library for computing sqrt prices from ticks and vice versa
/// @notice Computes sqrt price for ticks of size 1.0001, i.e. sqrt(1.0001^tick) as fixed point Q64.96 numbers. Supports
/// prices between 2**-128 and 2**128
library TickMath {
    /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
    int24 internal constant MAX_TICK = -MIN_TICK;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /// @notice Calculates sqrt(1.0001^tick) * 2^96
    /// @dev Throws if |tick| > max tick
    /// @param tick The input tick for the above formula
    /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the ratio of the two assets (token1/token0)
    /// at the given tick
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
        require(int256(absTick) <= int256(MAX_TICK), 'T');

        uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;

        // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
        // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
        // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
        sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }

    /// @notice Calculates the greatest tick value such that getRatioAtTick(tick) <= ratio
    /// @dev Throws in case sqrtPriceX96 < MIN_SQRT_RATIO, as MIN_SQRT_RATIO is the lowest value getRatioAtTick may
    /// ever return.
    /// @param sqrtPriceX96 The sqrt ratio for which to compute the tick as a Q64.96
    /// @return tick The greatest tick for which the ratio is less than or equal to the input ratio

    /// @dev This assembly math is NOT safe-memory labeled & may cause stack too deep errors with Foundry unless re-labeled! ////////// NOTICE!

    function getTickAtSqrtRatio(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
        // second inequality must be < because the price can never reach the price at the max tick
        require(sqrtPriceX96 >= MIN_SQRT_RATIO && sqrtPriceX96 < MAX_SQRT_RATIO, 'R');
        uint256 ratio = uint256(sqrtPriceX96) << 32;

        uint256 r = ratio;
        uint256 msb = 0;

        assembly {
            let f := shl(7, gt(r, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(6, gt(r, 0xFFFFFFFFFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(5, gt(r, 0xFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(4, gt(r, 0xFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(3, gt(r, 0xFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(2, gt(r, 0xF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(1, gt(r, 0x3))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := gt(r, 0x1)
            msb := or(msb, f)
        }

        if (msb >= 128) r = ratio >> (msb - 127);
        else r = ratio << (127 - msb);

        int256 log_2 = (int256(msb) - 128) << 64;

        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(63, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(62, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(61, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(60, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(59, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(58, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(57, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(56, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(55, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(54, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(53, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(52, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(51, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(50, f))
        }

        int256 log_sqrt10001 = log_2 * 255738958999603826347141; // 128.128 number

        int24 tickLow = int24((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128);
        int24 tickHi = int24((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128);

        tick = tickLow == tickHi ? tickLow : getSqrtRatioAtTick(tickHi) <= sqrtPriceX96 ? tickHi : tickLow;
    }
}

library LiquidityAmounts {
    /// @notice Downcasts uint256 to uint128
    /// @param x The uint258 to be downcasted
    /// @return y The passed value, downcasted to uint128
    function toUint128(uint256 x) private pure returns (uint128 y) {
        require((y = uint128(x)) == x);
    }

    /// @notice Computes the amount of liquidity received for a given amount of token0 and price range
    /// @dev Calculates amount0 * (sqrt(upper) * sqrt(lower)) / (sqrt(upper) - sqrt(lower))
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param amount0 The amount0 being sent in
    /// @return liquidity The amount of returned liquidity
    function getLiquidityForAmount0(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        uint256 intermediate = FullMath.mulDiv(sqrtRatioAX96, sqrtRatioBX96, FixedPoint96.Q96);
        return toUint128(FullMath.mulDiv(amount0, intermediate, sqrtRatioBX96 - sqrtRatioAX96));
    }

    /// @notice Computes the amount of liquidity received for a given amount of token1 and price range
    /// @dev Calculates amount1 / (sqrt(upper) - sqrt(lower)).
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param amount1 The amount1 being sent in
    /// @return liquidity The amount of returned liquidity
    function getLiquidityForAmount1(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        return toUint128(FullMath.mulDiv(amount1, FixedPoint96.Q96, sqrtRatioBX96 - sqrtRatioAX96));
    }

    /// @notice Computes the maximum amount of liquidity received for a given amount of token0, token1, the current
    /// pool prices and the prices at the tick boundaries
    /// @param sqrtRatioX96 A sqrt price representing the current pool prices
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param amount0 The amount of token0 being sent in
    /// @param amount1 The amount of token1 being sent in
    /// @return liquidity The maximum amount of liquidity received
    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            liquidity = getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0);
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            uint128 liquidity0 = getLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0);
            uint128 liquidity1 = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1);

            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        } else {
            liquidity = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1);
        }
    }

    /// @notice Computes the amount of token0 for a given amount of liquidity and a price range
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param liquidity The liquidity being valued
    /// @return amount0 The amount of token0
    function getAmount0ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return
            FullMath.mulDiv(
                uint256(liquidity) << FixedPoint96.RESOLUTION,
                sqrtRatioBX96 - sqrtRatioAX96,
                sqrtRatioBX96
            ) / sqrtRatioAX96;
    }

    /// @notice Computes the amount of token1 for a given amount of liquidity and a price range
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param liquidity The liquidity being valued
    /// @return amount1 The amount of token1
    function getAmount1ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
    }

    /// @notice Computes the token0 and token1 value for a given amount of liquidity, the current
    /// pool prices and the prices at the tick boundaries
    /// @param sqrtRatioX96 A sqrt price representing the current pool prices
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param liquidity The liquidity being valued
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            amount0 = getAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            amount0 = getAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity);
            amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity);
        } else {
            amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        }
    }
}
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = a * b
        // Compute the product mod 2**256 and mod 2**256 - 1
        // then use the Chinese Remainder Theorem to reconstruct
        // the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2**256 + prod0
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division
        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        // Make sure the result is less than 2**256.
        // Also prevents denominator == 0
        require(denominator > prod1);

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0]
        // Compute remainder using mulmod
        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        // Subtract 256 bit number from 512 bit number
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator
        // Compute largest power of two divisor of denominator.
        // Always >= 1.
        uint256 twos = (type(uint256).max - denominator + 1) & denominator;
        // Divide denominator by power of two
        assembly {
            denominator := div(denominator, twos)
        }

        // Divide [prod1 prod0] by the factors of two
        assembly {
            prod0 := div(prod0, twos)
        }
        // Shift in bits from prod1 into prod0. For this we need
        // to flip `twos` such that it is 2**256 / twos.
        // If twos is zero, then it becomes one
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        // Invert denominator mod 2**256
        // Now that denominator is an odd number, it has an inverse
        // modulo 2**256 such that denominator * inv = 1 mod 2**256.
        // Compute the inverse by starting with a seed that is correct
        // correct for four bits. That is, denominator * inv = 1 mod 2**4
        uint256 inv = (3 * denominator) ^ 2;
        // Now use Newton-Raphson iteration to improve the precision.
        // Thanks to Hensel's lifting lemma, this also works in modular
        // arithmetic, doubling the correct bits in each step.
        inv *= 2 - denominator * inv; // inverse mod 2**8
        inv *= 2 - denominator * inv; // inverse mod 2**16
        inv *= 2 - denominator * inv; // inverse mod 2**32
        inv *= 2 - denominator * inv; // inverse mod 2**64
        inv *= 2 - denominator * inv; // inverse mod 2**128
        inv *= 2 - denominator * inv; // inverse mod 2**256

        // Because the division is now exact we can divide by multiplying
        // with the modular inverse of denominator. This will give us the
        // correct result modulo 2**256. Since the precoditions guarantee
        // that the outcome is less than 2**256, this is the final result.
        // We don't need to compute the high bits of the result and prod1
        // is no longer required.
        result = prod0 * inv;
        return result;
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }
}
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}


////////// Other Interfaces & Contracts Needed for On-Chain Price Feed Integration //////////

// interface ISwapRouter is IUniswapV3SwapCallback {
//     struct ExactInputSingleParams {
//         address tokenIn;
//         address tokenOut;
//         uint24 fee;
//         address recipient;
//         uint256 deadline;
//         uint256 amountIn;
//         uint256 amountOutMinimum;
//         uint160 sqrtPriceLimitX96;
//     }

//     /// @notice Swaps `amountIn` of one token for as much as possible of another token
//     /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
//     /// @return amountOut The amount of the received token
//     function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

//     struct ExactInputParams {
//         bytes path;
//         address recipient;
//         uint256 deadline;
//         uint256 amountIn;
//         uint256 amountOutMinimum;
//     }

//     /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
//     /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
//     /// @return amountOut The amount of the received token
//     function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

//     struct ExactOutputSingleParams {
//         address tokenIn;
//         address tokenOut;
//         uint24 fee;
//         address recipient;
//         uint256 deadline;
//         uint256 amountOut;
//         uint256 amountInMaximum;
//         uint160 sqrtPriceLimitX96;
//     }

//     /// @notice Swaps as little as possible of one token for `amountOut` of another token
//     /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
//     /// @return amountIn The amount of the input token
//     function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

//     struct ExactOutputParams {
//         bytes path;
//         address recipient;
//         uint256 deadline;
//         uint256 amountOut;
//         uint256 amountInMaximum;
//     }

//     /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
//     /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
//     /// @return amountIn The amount of the input token
//     function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
// }

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// =========================== ComboOracle ============================
// ====================================================================
// Aggregates prices for various tokens
// Also has improvements from https://github.com/AlphaFinanceLab/alpha-homora-v2-contract/blob/master/contracts/oracle/ChainlinkAdapterOracle.sol

// Frax Finance: https://github.com/FraxFinance

// Primary Author(s)
// Travis Moore: https://github.com/FortisFortuna

// Reviewer(s) / Contributor(s)
// Jason Huan: https://github.com/jasonhuan
// Sam Kazemian: https://github.com/samkazemian

// import "./AggregatorV3Interface.sol";
// import "./IPricePerShareOptions.sol";
// import "../ERC20/ERC20.sol";
// import "../Staking/Owned.sol";



interface AggregatorV3Interface {

  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
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

interface IPricePerShareOptions {
    // Compound-style [Comp, Cream, Rari, Scream]
    // Multiplied by 1e18
    function exchangeRateStored() external view returns (uint256);

    // Curve-style [Curve, Convex, NOT StakeDAO]
    // In 1e18
    function get_virtual_price() external view returns (uint256);

    // SaddleD4Pool (SwapFlashLoan)
    function getVirtualPrice() external view returns (uint256);

    // StakeDAO
    function getPricePerFullShare() external view returns (uint256);

    // Yearn Vault
    function pricePerShare() external view returns (uint256);
}
interface ComboOracle {
    struct TokenInfoConstructorArgs {
        address token_address;
        address agg_addr_for_underlying; 
        uint256 agg_other_side; // 0: USD, 1: ETH
        address underlying_tkn_address; // Will be address(0) for simple tokens. Otherwise, the aUSDC, yvUSDC address, etc
        address pps_override_address;
        bytes4 pps_call_selector; // eg bytes4(keccak256("pricePerShare()"));
        uint256 pps_decimals;
    }

    struct TokenInfo {
        address token_address;
        string symbol;
        address agg_addr_for_underlying; 
        uint256 agg_other_side; // 0: USD, 1: ETH
        uint256 agg_decimals;
        address underlying_tkn_address; // Will be address(0) for simple tokens. Otherwise, the aUSDC, yvUSDC address, etc
        address pps_override_address;
        bytes4 pps_call_selector; // eg bytes4(keccak256("pricePerShare()"));
        uint256 pps_decimals;
        int256 ctkn_undrly_missing_decs;
    }
    function allTokenAddresses() external view returns (address[] memory);
    function allTokenInfos() external view returns (TokenInfo[] memory);
    function getETHPrice() external view returns (uint256);
    function getETHPricePrecise() external view returns (uint256);
    function getTokenPrice(address token_address) external view returns (uint256 precise_price, uint256 short_price, uint256 eth_price);
    
}

//     contract ComboOracle { //is Owned { /// TODO This could be modified to return mock values, rather than relying on hardcoding in the values in the logic above.

//         /* ========== STATE VARIABLES ========== */
        
//         address timelock_address;
//         address address_to_consult;
//         AggregatorV3Interface private priceFeedETHUSD = AggregatorV3Interface(address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419));
//         ERC20 private WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
//         string public native_token_symbol = "ETH";

//         uint256 public PRECISE_PRICE_PRECISION = 1e18;
//         uint256 public PRICE_PRECISION = 1e6;
//         uint256 public PRICE_MISSING_MULTIPLIER = 1e12;

//         address[] public all_token_addresses;
//         mapping(address => TokenInfo) public token_info; // token address => info
//         mapping(address => bool) public has_info; // token address => has info

//         // Price mappings
//         uint public maxDelayTime = 90000; // 25 hrs. Mapping for max delay time

//         bool public setupRan;

//         /* ========== STRUCTS ========== */

//         struct TokenInfoConstructorArgs {
//             address token_address;
//             address agg_addr_for_underlying; 
//             uint256 agg_other_side; // 0: USD, 1: ETH
//             address underlying_tkn_address; // Will be address(0) for simple tokens. Otherwise, the aUSDC, yvUSDC address, etc
//             address pps_override_address;
//             bytes4 pps_call_selector; // eg bytes4(keccak256("pricePerShare()"));
//             uint256 pps_decimals;
//         }

//         struct TokenInfo {
//             address token_address;
//             string symbol;
//             address agg_addr_for_underlying; 
//             uint256 agg_other_side; // 0: USD, 1: ETH
//             uint256 agg_decimals;
//             address underlying_tkn_address; // Will be address(0) for simple tokens. Otherwise, the aUSDC, yvUSDC address, etc
//             address pps_override_address;
//             bytes4 pps_call_selector; // eg bytes4(keccak256("pricePerShare()"));
//             uint256 pps_decimals;
//             int256 ctkn_undrly_missing_decs;
//         }

//         /* ========== CONSTRUCTOR ========== */

//         // constructor (
//         //     //address _owner_address,
//         //     // address _eth_usd_chainlink_address,
//         //     // address _weth_address,
//         //     // string memory _native_token_symbol,
//         //     // string memory _weth_token_symbol
//         // ) {

//         //     // Instantiate the instances
//         //     priceFeedETHUSD = AggregatorV3Interface(address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419));//_eth_usd_chainlink_address);
//         //     WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); //_weth_address);

//         //     // Handle native ETH
//         //     all_token_addresses.push(address(0));
//         //     native_token_symbol = "ETH";
//         //     token_info[address(0)] = TokenInfo(
//         //         address(0),
//         //         "ETH",
//         //         address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419),
//         //         0,
//         //         8,
//         //         address(0),
//         //         address(0),
//         //         bytes4(0),
//         //         0,
//         //         0
//         //     );
//         //     has_info[address(0)] = true;

//         //     // Handle WETH/USD
//         //     all_token_addresses.push(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
//         //     token_info[0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2] = TokenInfo(
//         //         0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
//         //         "WETH",
//         //         address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419),
//         //         0,
//         //         8,
//         //         address(0),
//         //         address(0),
//         //         bytes4(0),
//         //         0,
//         //         0
//         //     );
//         //     has_info[0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2] = true;
//         // }
//         function setthisuponce() public {
//             // Instantiate the instances
//             priceFeedETHUSD = AggregatorV3Interface(address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419));//_eth_usd_chainlink_address);
//             WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); //_weth_address);

//             // Handle native ETH
//             all_token_addresses.push(address(0));
//             native_token_symbol = "ETH";
//             token_info[address(0)] = TokenInfo(
//                 address(0),
//                 "ETH",
//                 address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419),
//                 0,
//                 8,
//                 address(0),
//                 address(0),
//                 bytes4(0),
//                 0,
//                 0
//             );
//             has_info[address(0)] = true;

//             // Handle WETH/USD
//             all_token_addresses.push(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
//             token_info[0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2] = TokenInfo(
//                 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
//                 "WETH",
//                 address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419),
//                 0,
//                 8,
//                 address(0),
//                 address(0),
//                 bytes4(0),
//                 0,
//                 0
//             );
//             has_info[0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2] = true;
//             setupRan = true;
//         }
//         /* ========== MODIFIERS ========== */

//         // modifier onlyByOwnGov() {
//         //     require(msg.sender == owner || msg.sender == timelock_address, "You are not an owner or the governance timelock");
//         //     _;
//         // }

//         /* ========== VIEWS ========== */

//         function allTokenAddresses() public view returns (address[] memory) {
//             return all_token_addresses;
//         }

//         function allTokenInfos() public view returns (TokenInfo[] memory) {
//             TokenInfo[] memory return_data = new TokenInfo[](all_token_addresses.length);
//             for (uint i = 0; i < all_token_addresses.length; i++){ 
//                 return_data[i] = token_info[all_token_addresses[i]];
//             }
//             return return_data;
//         }

//         // E6
//         function getETHPrice() public returns (uint256) {
//             if (setupRan = false) {
//                 setthisuponce();
//             }
//             (uint80 roundID, int price, , uint256 updatedAt, uint80 answeredInRound) = priceFeedETHUSD.latestRoundData();
//             require(price >= 0 && (updatedAt >= block.timestamp - maxDelayTime) && answeredInRound >= roundID, "Invalid chainlink price");

//             return (uint256(price) * (PRICE_PRECISION)) / (1e8); // ETH/USD is 8 decimals on Chainlink
//         }

//         // E18
//         function getETHPricePrecise() public returns (uint256) {
//             if (setupRan = false) {
//                 setthisuponce();
//             }
            
//             /// PULLED FROM EACAggregatorProxy 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
//             //   roundId   uint80 :  92233720368547789388
//             //   answer   int256 :  190155000000
//             //   startedAt   uint256 :  1660596956
//             //   updatedAt   uint256 :  1660596956
//             //   answeredInRound   uint80 :  92233720368547789388
//             // uint80 roundID = 92233720368547789388;
//             // int price = 190155000000;
//             // uint updatedAt = 1660596956;
//             // uint80 answeredInRound = 92233720368547789388;
//             (uint80 roundID, int price, , uint256 updatedAt, uint80 answeredInRound) = priceFeedETHUSD.latestRoundData();
//             require(price >= 0 && (updatedAt >= block.timestamp - maxDelayTime) && answeredInRound >= roundID, "Invalid chainlink price");

//             return (uint256(price) * (PRECISE_PRICE_PRECISION)) / (1e8); // ETH/USD is 8 decimals on Chainlink
//         }

//         function getTokenPrice(address token_address) public returns (uint256 precise_price, uint256 short_price, uint256 eth_price) {
//             if (setupRan = false) {
//                 setthisuponce();
//             }
//             // Get the token info
//             TokenInfo memory thisTokenInfo = token_info[token_address];

//             // Get the price for the underlying token
//             /// PULLED FROM EACAggregatorProxy 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
//             //   roundId   uint80 :  92233720368547789388
//             //   answer   int256 :  190155000000
//             //   startedAt   uint256 :  1660596956
//             //   updatedAt   uint256 :  1660596956
//             //   answeredInRound   uint80 :  92233720368547789388
//             // uint80 roundID = 92233720368547789388;
//             // int price = 190155000000;
//             // uint updatedAt = 1660596956;
//             // uint80 answeredInRound = 92233720368547789388;
//             // (uint80 roundID, int price, , uint256 updatedAt, uint80 answeredInRound) = priceFeedETHUSD.latestRoundData();
//             (uint80 roundID, int price, , uint256 updatedAt, uint80 answeredInRound) = AggregatorV3Interface(thisTokenInfo.agg_addr_for_underlying).latestRoundData();
//             require(price >= 0 && (updatedAt >= block.timestamp - maxDelayTime) && answeredInRound >= roundID, "Invalid chainlink price");
            
//             uint256 agg_price = uint256(price);

//             // Convert to USD, if not already
//             if (thisTokenInfo.agg_other_side == 1) agg_price = (agg_price * getETHPricePrecise()) / PRECISE_PRICE_PRECISION;

//             // cToken balance * pps = amt of underlying in native decimals
//             uint256 price_per_share = 1;
//             if (thisTokenInfo.underlying_tkn_address != address(0)){
//                 address pps_address_to_use = thisTokenInfo.token_address;
//                 if (thisTokenInfo.pps_override_address != address(0)) pps_address_to_use = thisTokenInfo.pps_override_address;
//                 (bool success, bytes memory data) = (pps_address_to_use).staticcall(abi.encodeWithSelector(thisTokenInfo.pps_call_selector));
//                 require(success, 'Oracle Failed');

//                 price_per_share = abi.decode(data, (uint256));
//             }

//             // E18
//             uint256 pps_multiplier = (uint256(10) ** (thisTokenInfo.pps_decimals));

//             // Handle difference in decimals()
//             if (thisTokenInfo.ctkn_undrly_missing_decs < 0){
//                 uint256 ctkn_undr_miss_dec_mult = (10 ** uint256(-1 * thisTokenInfo.ctkn_undrly_missing_decs));
//                 precise_price = (agg_price * PRECISE_PRICE_PRECISION * price_per_share) / (ctkn_undr_miss_dec_mult * pps_multiplier * (uint256(10) ** (thisTokenInfo.agg_decimals)));
//             }
//             else {
//                 uint256 ctkn_undr_miss_dec_mult = (10 ** uint256(thisTokenInfo.ctkn_undrly_missing_decs));
//                 precise_price = (agg_price * PRECISE_PRICE_PRECISION * price_per_share * ctkn_undr_miss_dec_mult) / (pps_multiplier * (uint256(10) ** (thisTokenInfo.agg_decimals)));
//             }
            
//             // E6
//             short_price = precise_price / PRICE_MISSING_MULTIPLIER;

//             // ETH Price
//             eth_price = (precise_price * PRECISE_PRICE_PRECISION) / getETHPricePrecise();
//         }

//         // Return token price in ETH, multiplied by 2**112
//         function getETHPx112(address token_address) external returns (uint256) {
//             if (token_address == address(WETH) || token_address == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) return uint(2 ** 112);
//             require(maxDelayTime != 0, 'Max delay time not set');

//             // Get the ETH Price PRECISE_PRICE_PRECISION
//             ( , , uint256 eth_price) = getTokenPrice(token_address);
            
//             // Get the decimals
//             uint decimals = uint(ERC20(token_address).decimals());

//             // Scale to 2*112
//             // Also divide by the token decimals (needed for the math. Nothing to do with missing decimals or anything)
//             return (eth_price * (2 ** 112)) / (10 ** decimals);
//         }

//         /* ========== RESTRICTED GOVERNANCE FUNCTIONS ========== */

//         // function setTimelock(address _timelock_address) external {
//         //     timelock_address = _timelock_address;
//         // }

//         // function setMaxDelayTime(uint _maxDelayTime) external {
//         //     maxDelayTime = _maxDelayTime;
//         // }

//         function batchSetOracleInfoDirect(TokenInfoConstructorArgs[] memory _initial_token_infos) external {
//             // Batch set token info
//             for (uint256 i = 0; i < _initial_token_infos.length; i++){ 
//                 TokenInfoConstructorArgs memory this_token_info = _initial_token_infos[i];
//                 _setTokenInfo(
//                     this_token_info.token_address, 
//                     this_token_info.agg_addr_for_underlying, 
//                     this_token_info.agg_other_side, 
//                     this_token_info.underlying_tkn_address, 
//                     this_token_info.pps_override_address,
//                     this_token_info.pps_call_selector, 
//                     this_token_info.pps_decimals
//                 );
//             }
//         }

//         // Sets oracle info for a token 
//         // Chainlink Addresses
//         // https://docs.chain.link/docs/ethereum-addresses/

//         // exchangeRateStored: 0x182df0f5
//         // getPricePerFullShare: 0x77c7b8fc
//         // get_virtual_price: 0xbb7b8b80
//         // getVirtualPrice: 0xe25aa5fa
//         // pricePerShare: 0x99530b06

//         // Function signature encoder
//         //     web3_data.eth.abi.encodeFunctionSignature({
//         //     name: 'getVirtualPrice',
//         //     type: 'function',
//         //     inputs: []
//         // })
//         //     web3_data.eth.abi.encodeFunctionSignature({
//         //     name: 'myMethod',
//         //     type: 'function',
//         //     inputs: [{
//         //         type: 'uint256',
//         //         name: 'myNumber'
//         //     }]
//         // })

//         // To burn something, for example, type this on app.frax.finance's JS console
//         // https://web3js.readthedocs.io/en/v1.2.11/web3-eth-abi.html#encodefunctioncall
//         // web3_data.eth.abi.encodeFunctionCall({
//         //     name: 'burn',
//         //     type: 'function',
//         //     inputs: [{
//         //         type: 'uint256',
//         //         name: 'myNumber'
//         //     }]
//         // }, ['100940878321208298244715']);

//         function _setTokenInfo(
//             address token_address, 
//             address agg_addr_for_underlying, 
//             uint256 agg_other_side, // 0: USD, 1: ETH
//             address underlying_tkn_address,
//             address pps_override_address,
//             bytes4 pps_call_selector,
//             uint256 pps_decimals
//         ) internal {
//             // require(token_address != address(0), "Cannot add zero address");

//             // See if there are any missing decimals between a cToken and the underlying
//             int256 ctkn_undrly_missing_decs = 0;
//             if (underlying_tkn_address != address(0)){
//                 uint256 cToken_decs = ERC20(token_address).decimals();
//                 uint256 underlying_decs = ERC20(underlying_tkn_address).decimals();

//                 ctkn_undrly_missing_decs = int256(cToken_decs) - int256(underlying_decs);
//             }

//             // Add the token address to the array if it doesn't already exist
//             bool token_exists = false;
//             for (uint i = 0; i < all_token_addresses.length; i++){ 
//                 if (all_token_addresses[i] == token_address) {
//                     token_exists = true;
//                     break;
//                 }
//             }
//             if (!token_exists) all_token_addresses.push(token_address);

//             uint256 agg_decs = uint256(AggregatorV3Interface(agg_addr_for_underlying).decimals());

//             string memory name_to_use;
//             if (token_address == address(0)) {
//                 name_to_use = native_token_symbol;
//             }
//             else {
//                 name_to_use = ERC20(token_address).name();
//             }

//             // Add the token to the mapping
//             token_info[token_address] = TokenInfo(
//                 token_address,
//                 ERC20(token_address).name(),
//                 agg_addr_for_underlying,
//                 agg_other_side,
//                 agg_decs,
//                 underlying_tkn_address,
//                 pps_override_address,
//                 pps_call_selector,
//                 pps_decimals,
//                 ctkn_undrly_missing_decs
//             );
//             has_info[token_address] = true;
//         }

//         function setTokenInfo(
//             address token_address, 
//             address agg_addr_for_underlying, 
//             uint256 agg_other_side,
//             address underlying_tkn_address,
//             address pps_override_address,
//             bytes4 pps_call_selector,
//             uint256 pps_decimals
//         ) public {
//             _setTokenInfo(token_address, agg_addr_for_underlying, agg_other_side, underlying_tkn_address, pps_override_address, pps_call_selector, pps_decimals);
//         }

//     }
// contract Owned {
//     address public owner;
//     address public nominatedOwner;

//     constructor (address _owner) public {
//         require(_owner != address(0), "Owner address cannot be 0");
//         owner = _owner;
//         emit OwnerChanged(address(0), _owner);
//     }

//     function nominateNewOwner(address _owner) external onlyOwner {
//         nominatedOwner = _owner;
//         emit OwnerNominated(_owner);
//     }

//     function acceptOwnership() external {
//         require(msg.sender == nominatedOwner, "You must be nominated before you can accept ownership");
//         emit OwnerChanged(owner, nominatedOwner);
//         owner = nominatedOwner;
//         nominatedOwner = address(0);
//     }

//     modifier onlyOwner {
//         require(msg.sender == owner, "Only the contract owner may perform this action");
//         _;
//     }

//     event OwnerNominated(address newOwner);
//     event OwnerChanged(address oldOwner, address newOwner);
// }
