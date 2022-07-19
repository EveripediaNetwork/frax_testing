// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import {Test, stdError, console} from "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {FraxUnifiedFarm_ERC20, LockedStake} from "../../src/gauges/FraxUnifiedFarm_ERC20.sol";

contract TestFraxFraxUnifiedFarm_ERC20 is Test {

    FraxUnifiedFarm_ERC20 public farm;

    MockERC20 public reward0;
    MockERC20 public reward1;
    MockERC20 public lpNonFRAXToken;
    address[] _rewardTokens;
    address[] _rewardManagers;
    uint256[] _rewardRates;
    address[] _gaugeControllers;
    address[] _rewardDistributors;
    address veFXS = address(0xc8418aF6358FFddA74e09Ca9CC3Fe03Ca6aDC5b0);

    function setUp() public {
        reward0 = new MockERC20("RewardToken", "RW1", 18);
        reward1 = new MockERC20("RewardToken", "RW2", 18);
        lpNonFRAXToken = new MockERC20("StakingToken", "ST1", 18);

        _rewardTokens.push(address(reward0));
        _rewardTokens.push(address(reward1));

        _rewardManagers.push(address(this));
        _rewardManagers.push(address(this));

        vm.etch(veFXS, address(reward0).code); // mocking veFXS
    }

    function testFraxPerLPTokenSideA() public {
        address _stakingToken = address(new MockUniToken(address(lpNonFRAXToken), 1 ether, 0.2 ether, 0.8 ether, 0, true));
        _rewardRates.push(uint256(1000));
        _gaugeControllers.push(address(new MockGaugeController(0, 0, 0)));
        _rewardDistributors.push(address(new MockRewardDistributor(0, 0)));
        farm = new FraxUnifiedFarm_ERC20(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);
        assertEq(farm.fraxPerLPToken(), 0.8 ether);
    }

    function testFraxPerLPTokenSideB() public {
        address _stakingToken = address(new MockUniToken(address(0x853d955aCEf822Db058eb8505911ED77F175b99e), 1 ether, 0.8 ether, 0.2 ether, 0, true));
        _rewardRates.push(uint256(1000));
        _gaugeControllers.push(address(new MockGaugeController(0, 0, 0)));
        _rewardDistributors.push(address(new MockRewardDistributor(0, 0)));
        farm = new FraxUnifiedFarm_ERC20(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);
        assertEq(farm.fraxPerLPToken(), 0.8 ether);
        assertTrue(farm.isTokenManagerFor(address(this), address(reward0)));
    }

    function testIsTokenManagerFor() public {
        address _stakingToken = address(new MockUniToken(address(0x853d955aCEf822Db058eb8505911ED77F175b99e), 1 ether, 0.8 ether, 0.2 ether, 0, true));
        _rewardRates.push(uint256(1000));
        _gaugeControllers.push(address(new MockGaugeController(0, 0, 0)));
        _rewardDistributors.push(address(new MockRewardDistributor(0, 0)));
        farm = new FraxUnifiedFarm_ERC20(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);
        assertTrue(farm.isTokenManagerFor(address(this), address(reward0)));
        assertTrue(farm.isTokenManagerFor(address(this), address(reward1)));
        assertTrue(!farm.isTokenManagerFor(address(reward1), address(reward1)));

        // test basic getters
        address[] memory rewardTokens = farm.getAllRewardTokens();
        assertEq(rewardTokens[0], address(reward0));
        assertEq(rewardTokens[1], address(reward1));
        assertEq(0, farm.rewardRates(0));
    }

    function testDeposit() public {
        address _stakingToken = address(new MockUniToken(address(0x853d955aCEf822Db058eb8505911ED77F175b99e), 1 ether, 0.8 ether, 0.2 ether, 0, true));
        _rewardRates.push(uint256(0));
        _rewardRates.push(uint256(1000));
        _gaugeControllers.push(address(new MockGaugeController(0, 0, 0)));
        _gaugeControllers.push(address(0));
        _rewardDistributors.push(address(new MockRewardDistributor(0, 0)));
        farm = new FraxUnifiedFarm_ERC20(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);

        reward0.mint(address(farm), 1 ether);
        reward1.mint(address(farm), 1 ether);

        vm.mockCall(
            veFXS,
            abi.encodeWithSelector(MockUniToken.totalSupply.selector),
            abi.encode(1000)
        );

        vm.expectRevert("Minimum stake time not met");
        bytes32 kek = farm.stakeLocked(1000, 0.5 days);
        bytes32 kek2 = farm.stakeLocked(1000, 7 days);

        vm.expectRevert("Stake is still locked!");
        farm.withdrawLocked(kek2, address(this));

        skip(7 days);
        farm.withdrawLocked(kek2, address(this));
    }

    function testLockLonger() public {
        address _stakingToken = address(new MockUniToken(address(0x853d955aCEf822Db058eb8505911ED77F175b99e), 1 ether, 0.8 ether, 0.2 ether, 0, true));
        _rewardRates.push(uint256(0));
        _rewardRates.push(uint256(1000));
        _gaugeControllers.push(address(new MockGaugeController(0, 0, 0)));
        _gaugeControllers.push(address(0));
        _rewardDistributors.push(address(new MockRewardDistributor(0, 0)));
        farm = new FraxUnifiedFarm_ERC20(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);

        reward0.mint(address(farm), 1 ether);
        reward1.mint(address(farm), 1 ether);

        vm.mockCall(
            veFXS,
            abi.encodeWithSelector(MockUniToken.totalSupply.selector),
            abi.encode(1000)
        );


        bytes32 kek = farm.stakeLocked(1000, 7 days);

        vm.expectRevert("Must be in the future");
        farm.lockLonger(kek, block.timestamp);

        vm.expectRevert("Cannot shorten lock time");
        farm.lockLonger(kek, block.timestamp + 2 days);

        farm.lockLonger(kek, block.timestamp + 14 days);

        LockedStake[] memory stakes = farm.lockedStakesOf(address(this));
        assertEq(stakes[0].kek_id, kek);
    }

    function test3Users3Weeks1Claim() public {
        address _stakingToken = address(new MockUniToken(address(0x853d955aCEf822Db058eb8505911ED77F175b99e), 3 ether, 5 ether, 5 ether, 0, true));

        address sam = vm.addr(31337);
        address cesar = vm.addr(31338);
        address travis = vm.addr(31339);

        uint oneTokenPerDay = 11574074074074;
        _rewardRates.push(oneTokenPerDay);
        _gaugeControllers.push(address(0));
        _rewardDistributors.push(address(new MockRewardDistributor(0, 0)));
        _rewardTokens.pop(); // remove default test second token reward
        farm = new FraxUnifiedFarm_ERC20(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);

        reward0.mint(address(farm), 100 ether);

        vm.mockCall(
            veFXS,
            abi.encodeWithSelector(MockUniToken.totalSupply.selector),
            abi.encode(1000)
        );
        vm.prank(sam);
        farm.stakeLocked(2 ether, 7 days);
        vm.prank(cesar);
        farm.stakeLocked(1 ether, 7 days);
        vm.prank(travis);
        farm.stakeLocked(1 ether, 7 days);

        skip(7 days);
        vm.prank(sam);
        uint256[] memory rewards = farm.getReward(sam);
        assertGt(rewards[0], 3.499999 ether);
        assertLt(rewards[0], 3.5 ether);

        // 2x rewards (14 IQ per day)
        farm.setRewardVars(_rewardTokens[0], oneTokenPerDay * 2, address(0), _rewardDistributors[0]);
        skip(7 days);
        vm.prank(sam);
        rewards = farm.getReward(sam);
        assertGt(rewards[0], 6.93 ether);
        assertLt(rewards[0], 7 ether);

        vm.prank(travis);
        rewards = farm.getReward(travis);
        // 7 * 25/100 + 7*2 * 25/100 = 5.25
        assertGt(rewards[0], 5.28 ether);
        assertLt(rewards[0], 5.29 ether);

        // 10x rewards (70 IQ per day)
        farm.setRewardVars(_rewardTokens[0], oneTokenPerDay * 10, address(0), _rewardDistributors[0]);
        skip(7 days);

        vm.prank(cesar);
        rewards = farm.getReward(travis);
        // 7 * 25/100 + 7*2 * 25/100 + 7*10 * 25 /100 = 22.75
        assertGt(rewards[0], 23.23 ether);
        assertLt(rewards[0], 23.24 ether);
    }

    function testMaxBoostTime() public {
        address _stakingToken = address(new MockUniToken(address(0x853d955aCEf822Db058eb8505911ED77F175b99e), 3 ether, 5 ether, 5 ether, 0, true));

        address sam = vm.addr(31337);
        address cesar = vm.addr(31338);

        uint oneTokenPerDay = 11574074074074;
        _rewardRates.push(oneTokenPerDay);
        _gaugeControllers.push(address(0));
        _rewardDistributors.push(address(new MockRewardDistributor(0, 0)));
        _rewardTokens.pop(); // remove default test second token reward
        farm = new FraxUnifiedFarm_ERC20(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);

        reward0.mint(address(farm), 365 ether);

        vm.mockCall(
            veFXS,
            abi.encodeWithSelector(MockUniToken.totalSupply.selector),
            abi.encode(1000)
        );
        vm.prank(sam);
        farm.stakeLocked(2 ether, 7 days);
        vm.prank(cesar);
        farm.stakeLocked(1 ether, 365 days);

        skip(7 days);
        vm.prank(cesar);
        uint256[] memory rewards = farm.getReward(cesar);
        // 2.863 ether sam // 4.136 eth cesar
        assertGt(rewards[0], 4.13 ether);
        assertLt(rewards[0], 4.14 ether);
    }

    function testMaxBoostTimeAndVeFXS() public {
        address _stakingToken = address(new MockUniToken(address(0x853d955aCEf822Db058eb8505911ED77F175b99e), 3 ether, 5 ether, 5 ether, 0, true));

        address sam = vm.addr(31337);
        address cesar = vm.addr(31338);

        uint oneTokenPerDay = 11574074074074;
        _rewardRates.push(oneTokenPerDay);
        _gaugeControllers.push(address(0));
        _rewardDistributors.push(address(new MockRewardDistributor(0, 0)));
        _rewardTokens.pop(); // remove default test second token reward
        farm = new FraxUnifiedFarm_ERC20(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);

        reward0.mint(address(farm), 365 ether);

        vm.mockCall(
            veFXS,
            abi.encodeWithSelector(MockUniToken.totalSupply.selector),
            abi.encode(1 ether)
        );
        vm.mockCall(
            veFXS,
            abi.encodeWithSelector(MockUniToken.balanceOf.selector, cesar),
            abi.encode(1 ether)
        );
        vm.prank(sam);
        farm.stakeLocked(2 ether, 7 days);
        vm.prank(cesar);
        farm.stakeLocked(1 ether, 365 days);

        skip(7 days);
        vm.prank(cesar);
        uint256[] memory rewards = farm.getReward(cesar);
        // 2.054 ether sam // 4.9457 eth cesar
        assertGt(rewards[0], 4.9 ether);
        assertLt(rewards[0], 5 ether);
    }

    function testLockMultiplierAfterExpiration() public {
        address _stakingToken = address(new MockUniToken(address(0x853d955aCEf822Db058eb8505911ED77F175b99e), 3 ether, 5 ether, 5 ether, 0, true));

        address sam = vm.addr(31337);
        address cesar = vm.addr(31338);

        uint oneTokenPerDay = 11574074074074;
        _rewardRates.push(oneTokenPerDay);
        _gaugeControllers.push(address(0));
        _rewardDistributors.push(address(new MockRewardDistributor(0, 0)));
        _rewardTokens.pop(); // remove default test second token reward
        farm = new FraxUnifiedFarm_ERC20(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);

        reward0.mint(address(farm), 365 ether);

        vm.mockCall(
            veFXS,
            abi.encodeWithSelector(MockUniToken.totalSupply.selector),
            abi.encode(1 ether)
        );
        vm.prank(sam);
        farm.stakeLocked(1 ether, 7 days);
        vm.prank(cesar);
        farm.stakeLocked(1 ether, 14 days);

        skip(14 days);
        vm.prank(sam);
        uint256[] memory rewards = farm.getReward(sam);
        // 6.87 ether sam // 7.12 eth cesar
        assertGt(rewards[0], 6.87 ether);
        assertLt(rewards[0], 6.88 ether);
    }

    // TODO: test case ideas
    // test max boost time & veFXS
    // test max boost w proxy
    // test lock more w veFXS boost
    // test w gauge controller instead of set
}

contract MockUniToken {
    address _token0;
    uint256 _totalSupply;
    uint112 _reserve0;
    uint112 _reserve1;
    uint32 _blockTimestampLast;
    bool _successTransfer;

    constructor(address token0, uint256 totalSupply, uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast, bool successTransfer) {
        _token0 = token0;
        _totalSupply = totalSupply;
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
        _successTransfer = successTransfer;
    }

    function balanceOf(address to) external view returns (uint) {
        return _totalSupply;
    }

    function transfer(address to, uint value) external returns (bool) {
        return _successTransfer;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        return true;
    }

    function token0() external view returns (address) {
        return _token0;
    }

    function totalSupply() external view returns (uint) {
        return _totalSupply;
    }

    function getReserveAfterTwamm(uint256 blockTimestamp) external view returns (uint112 reserve0, uint112 reserve1, uint256 lastVirtualOrderTimestamp, uint112 _twammReserve0, uint112 _twammReserve1) {
        return (_reserve0, _reserve1, _blockTimestampLast, _reserve0, _reserve1);
    }
}

contract MockRewardDistributor {
    uint256 _weeks_elapsed;
    uint256 _reward_tally;

    constructor(uint256 weeks_elapsed, uint256 reward_tally) {
        _weeks_elapsed = weeks_elapsed;
        _reward_tally = reward_tally;
    }

    function distributeReward(address gauge_address) external returns (uint256 weeks_elapsed, uint256 reward_tally) {
        return (_weeks_elapsed, _reward_tally);
    }
}

contract MockGaugeController {
    uint256 _gauge_relative_weight_write;
    uint256 _global_emission_rate;
    uint256 _time_total;

    constructor(uint256 gauge_relative_weight_write, uint256 global_emission_rate, uint256 time_total) {
        _gauge_relative_weight_write = gauge_relative_weight_write;
        _global_emission_rate = global_emission_rate;
        _time_total = time_total;
    }

    function time_total() external view returns (uint256) {
        return _time_total;
    }

    function global_emission_rate() external view returns (uint256) {
        return _global_emission_rate;
    }

    function gauge_relative_weight_write(address, uint256) external returns (uint256) {
        return _gauge_relative_weight_write;
    }
}
