// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import {Test, stdError, console} from "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {FraxUnifiedFarm_ERC20_Fraxswap_FRAX_IQ} from "../../src/gauges/FraxUnifiedFarm_ERC20_Fraxswap_FRAX_IQ.sol";

contract TestFraxFarm is Test {

    FraxUnifiedFarm_ERC20_Fraxswap_FRAX_IQ public farm;

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
        farm = new FraxUnifiedFarm_ERC20_Fraxswap_FRAX_IQ(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);
        assertEq(farm.fraxPerLPToken(), 0.8 ether);
    }

    function testFraxPerLPTokenSideB() public {
        address _stakingToken = address(new MockUniToken(address(0x853d955aCEf822Db058eb8505911ED77F175b99e), 1 ether, 0.8 ether, 0.2 ether, 0, true));
        _rewardRates.push(uint256(1000));
        _gaugeControllers.push(address(new MockGaugeController(0, 0, 0)));
        _rewardDistributors.push(address(new MockRewardDistributor(0, 0)));
        farm = new FraxUnifiedFarm_ERC20_Fraxswap_FRAX_IQ(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);
        assertEq(farm.fraxPerLPToken(), 0.8 ether);
        assertTrue(farm.isTokenManagerFor(address(this), address(reward0)));
    }

    function testIsTokenManagerFor() public {
        address _stakingToken = address(new MockUniToken(address(0x853d955aCEf822Db058eb8505911ED77F175b99e), 1 ether, 0.8 ether, 0.2 ether, 0, true));
        _rewardRates.push(uint256(1000));
        _gaugeControllers.push(address(new MockGaugeController(0, 0, 0)));
        _rewardDistributors.push(address(new MockRewardDistributor(0, 0)));
        farm = new FraxUnifiedFarm_ERC20_Fraxswap_FRAX_IQ(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);
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
        farm = new FraxUnifiedFarm_ERC20_Fraxswap_FRAX_IQ(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);

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

        vm.warp(block.timestamp + 7 days);
        farm.withdrawLocked(kek2, address(this));
    }

    function testLockLonger() public {
        address _stakingToken = address(new MockUniToken(address(0x853d955aCEf822Db058eb8505911ED77F175b99e), 1 ether, 0.8 ether, 0.2 ether, 0, true));
        _rewardRates.push(uint256(0));
        _rewardRates.push(uint256(1000));
        _gaugeControllers.push(address(new MockGaugeController(0, 0, 0)));
        _gaugeControllers.push(address(0));
        _rewardDistributors.push(address(new MockRewardDistributor(0, 0)));
        farm = new FraxUnifiedFarm_ERC20_Fraxswap_FRAX_IQ(address(this), _rewardTokens, _rewardManagers, _rewardRates, _gaugeControllers, _rewardDistributors, _stakingToken);

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
    }
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

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        return (_reserve0, _reserve1, _blockTimestampLast);
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