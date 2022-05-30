// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import {Test, stdError, console} from "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {FraxswapFactory} from "../src/core/FraxswapFactory.sol";
import {FraxswapRouter} from "../src/periphery/FraxswapRouter.sol";
import {FraxswapRouterLibrary} from "../src/periphery/libraries/FraxswapRouterLibrary.sol";
import {FraxswapPair} from "../src/core/FraxswapPair.sol";

contract TestFraxswapRouter is Test {

    FraxswapFactory public factory;
    FraxswapRouter public router;

    MockERC20 public token0;
    MockERC20 public token1;

    function setUp() public {
        factory = new FraxswapFactory(vm.addr(1));
        router = new FraxswapRouter(address(factory), vm.addr(2));

        token0 = new MockERC20("UnifapToken0", "UT0", 18);
        token1 = new MockERC20("UnifapToken1", "UT1", 18);

        token0.mint(address(this), 10 ether);
        token1.mint(address(this), 10 ether);
    }

    function testAddLiquidityPairFor() public {
        token0.approve(address(router), 1 ether);
        token1.approve(address(router), 1 ether);

        (address _token0, address _token1) = FraxswapRouterLibrary.sortTokens(
            address(token0),
            address(token1)
        );
        address pair = FraxswapRouterLibrary.pairFor(
            address(factory),
            _token0,
            _token1
        );

        (, , uint256 liquidity) = router.addLiquidity(
            address(token0),
            address(token1),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp + 1
        );

        assertEq(liquidity, 1 ether - FraxswapPair(pair).MINIMUM_LIQUIDITY());
        assertEq(factory.getPair(address(token0), address(token1)), pair);
    }

    function testAddLiquidityNoPair() public {
        token0.approve(address(router), 1 ether);
        token1.approve(address(router), 1 ether);

        (address _token0, address _token1) = FraxswapRouterLibrary.sortTokens(
            address(token0),
            address(token1)
        );

        address pair = FraxswapRouterLibrary.pairFor(
            address(factory),
            _token0,
            _token1
        );

        (uint256 amount0, uint256 amount1, uint256 liquidity) = router
        .addLiquidity(
            address(token0),
            address(token1),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp + 1
        );

        assertEq(amount0, 1 ether);
        assertEq(amount1, 1 ether);
        assertEq(liquidity, 1 ether - FraxswapPair(pair).MINIMUM_LIQUIDITY());

        assertEq(factory.getPair(address(token0), address(token1)), pair);
        assertEq(FraxswapPair(pair).token0(), address(token0));
        assertEq(FraxswapPair(pair).token1(), address(token1));

        (uint256 reserve0, uint256 reserve1, ) = FraxswapPair(pair)
        .getReserves();
        assertEq(reserve0, 1 ether);
        assertEq(reserve1, 1 ether);
        assertEq(token0.balanceOf(address(pair)), 1 ether);
        assertEq(token1.balanceOf(address(pair)), 1 ether);
        assertEq(token0.balanceOf(address(this)), 9 ether);
        assertEq(token1.balanceOf(address(this)), 9 ether);
    }

    function testAddLiquidityInsufficientAmountB() public {
        token0.approve(address(router), 4 ether);
        token1.approve(address(router), 8 ether);

        router.addLiquidity(
            address(token0),
            address(token1),
            4 ether,
            8 ether,
            4 ether,
            8 ether,
            address(this),
            block.timestamp + 1
        );

        token0.approve(address(router), 1 ether);
        token1.approve(address(router), 2 ether);

        vm.expectRevert("FraxswapV1Router: INSUFFICIENT_B_AMOUNT");
        router.addLiquidity(
            address(token0),
            address(token1),
            1 ether,
            2 ether,
            1 ether,
            2.3 ether,
            address(this),
            block.timestamp + 1
        );
    }

    function testAddLiquidityAmountBDesiredHigh() public {
        token0.approve(address(router), 4 ether);
        token1.approve(address(router), 8 ether);

        router.addLiquidity(
            address(token0),
            address(token1),
            4 ether,
            8 ether,
            4 ether,
            8 ether,
            address(this),
            block.timestamp + 1
        );

        token0.approve(address(router), 1 ether);
        token1.approve(address(router), 2 ether);

        (uint256 amount0, uint256 amount1, ) = router.addLiquidity(
            address(token0),
            address(token1),
            1 ether,
            2.3 ether,
            1 ether,
            2 ether,
            address(this),
            block.timestamp + 1
        );

        assertEq(amount0, 1 ether);
        assertEq(amount1, 2 ether);
    }

    function testAddLiquidityAmountBDesiredLow() public {
        token0.approve(address(router), 4 ether);
        token1.approve(address(router), 8 ether);

        router.addLiquidity(
            address(token0),
            address(token1),
            4 ether,
            8 ether,
            4 ether,
            8 ether,
            address(this),
            block.timestamp + 1
        );

        token0.approve(address(router), 1 ether);
        token1.approve(address(router), 2 ether);

        (uint256 amount0, uint256 amount1, ) = router.addLiquidity(
            address(token0),
            address(token1),
            1 ether,
            1.5 ether,
            0.75 ether,
            2 ether,
            address(this),
            block.timestamp + 1
        );

        assertEq(amount0, 0.75 ether);
        assertEq(amount1, 1.5 ether);
    }

    function testAddLiquidityInsufficientAmountA() public {
        token0.approve(address(router), 4 ether);
        token1.approve(address(router), 8 ether);

        router.addLiquidity(
            address(token0),
            address(token1),
            4 ether,
            8 ether,
            4 ether,
            8 ether,
            address(this),
            block.timestamp + 1
        );

        token0.approve(address(router), 1 ether);
        token1.approve(address(router), 2 ether);

        vm.expectRevert("FraxswapV1Router: INSUFFICIENT_A_AMOUNT");
        router.addLiquidity(
            address(token0),
            address(token1),
            1 ether,
            1.5 ether,
            1 ether,
            2 ether,
            address(this),
            block.timestamp + 1
        );
    }

    function testCannotAddLiquidity() public {
        token0.approve(address(router), 1 ether);
        token1.approve(address(router), 1 ether);

        vm.warp(2);
        vm.expectRevert("FraxswapV1Router: EXPIRED");
        router.addLiquidity(
            address(token0),
            address(token1),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            1
        );
    }

    function testRemoveLiquidity() public {
        uint initial_burn = 1000;
        token0.approve(address(router), 1 ether);
        token1.approve(address(router), 1 ether);

        (uint256 amount0, uint256 amount1, uint256 liquidity) = router
        .addLiquidity(
            address(token0),
            address(token1),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp + 1
        );

        address pair = factory.getPair(address(token0), address(token1));
        assertEq(ERC20(pair).balanceOf(address(this)), liquidity);
        ERC20(pair).approve(address(router), 1 ether);

        router.removeLiquidity(
            address(token0),
            address(token1),
            liquidity,
            amount0 - initial_burn,
            amount1 - initial_burn,
            address(this),
            block.timestamp + 1
        );
    }
}
