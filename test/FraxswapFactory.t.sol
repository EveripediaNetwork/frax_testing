// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import {Test} from "forge-std/Test.sol";
import {FraxswapFactory} from "../src/core/FraxswapFactory.sol";
import {FraxswapPair} from "../src/core/FraxswapPair.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {FraxswapRouterLibrary} from "../src/periphery/libraries/FraxswapRouterLibrary.sol";

contract TestFraxswapFactory is Test {
    FraxswapFactory public factory;
    MockERC20 public token0;
    MockERC20 public token1;
    MockERC20 public token2;
    MockERC20 public token3;
    address public me;

    function setUp() public {
        factory = new FraxswapFactory(vm.addr(1));

        token0 = new MockERC20("FraxswapToken0", "UT0", 18);
        token1 = new MockERC20("FraxswapToken1", "UT1", 18);
        token2 = new MockERC20("FraxswapToken2", "UT2", 18);
        token3 = new MockERC20("FraxswapToken3", "UT3", 18);
        me = vm.addr(1);
    }

    function testCreatePair() public {
        address tokenPair = factory.createPair(
            address(token0),
            address(token1)
        );

        (address _token0, address _token1) = FraxswapRouterLibrary.sortTokens(
            address(token0),
            address(token1)
        );

        assertEq(factory.allPairsLength(), 1);
        assertEq(factory.allPairs(0), tokenPair);
        assertEq(FraxswapPair(tokenPair).token0(), _token0);
        assertEq(FraxswapPair(tokenPair).token1(), _token1);
    }

    function testCreatePairMultipleTokens() public {
        address tokenPair0 = factory.createPair(
            address(token0),
            address(token1)
        );
        address tokenPair1 = factory.createPair(
            address(token2),
            address(token3)
        );

        (address _token0, address _token1) = FraxswapRouterLibrary.sortTokens(
            address(token0),
            address(token1)
        );
        (address _token2, address _token3) = FraxswapRouterLibrary.sortTokens(
            address(token2),
            address(token3)
        );

        assertEq(factory.allPairsLength(), 2);
        assertEq(factory.allPairs(0), tokenPair0);
        assertEq(factory.allPairs(1), tokenPair1);
        assertEq(FraxswapPair(tokenPair0).token0(), _token0);
        assertEq(FraxswapPair(tokenPair0).token1(), _token1);
        assertEq(FraxswapPair(tokenPair1).token0(), _token2);
        assertEq(FraxswapPair(tokenPair1).token1(), _token3);
    }

    function testCreatePairChained() public {
        address tokenPair0 = factory.createPair(
            address(token0),
            address(token1)
        );
        address tokenPair1 = factory.createPair(
            address(token1),
            address(token2)
        );
        address tokenPair2 = factory.createPair(
            address(token2),
            address(token3)
        );

        assertEq(factory.allPairsLength(), 3);
        assertEq(factory.allPairs(0), tokenPair0);
        assertEq(factory.allPairs(1), tokenPair1);
        assertEq(factory.allPairs(2), tokenPair2);
    }

    function testCannotCreatePairIdenticalTokens() public {
        vm.expectRevert("IDENTICAL_ADDRESSES");
        factory.createPair(address(token0), address(token0));
    }

    function testCannotCreatePairInvalidToken() public {
        vm.expectRevert("ZERO_ADDRESS");
        factory.createPair(address(0), address(token1));

        vm.expectRevert("ZERO_ADDRESS");
        factory.createPair(address(token0), address(0));
    }

    function testCannotCreatePairDuplicatePair() public {
        factory.createPair(address(token0), address(token1));
        vm.expectRevert("PAIR_EXISTS");
        factory.createPair(address(token0), address(token1));
    }

    function testSetFeeTo() public {
        vm.prank(me);
        factory.setFeeTo(vm.addr(2));
    }

    function testSetToFeeByForbiddenAddr() public {
        vm.startPrank(vm.addr(3));
        vm.expectRevert();
        factory.setFeeTo(me);
    }
}
