// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;


// import "../../interfaces/INonfungiblePositionManager.sol";
// import '@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
// import '@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import "./MockFraxUnifiedFarmTemplate.sol";

import "./MockOracle.sol";


contract FraxFarmUniV3 is FraxUnifiedFarmTemplate, ComboOracle_UniV2_UniV3 {
    using SafeERC20 for IERC20;
    /* ========== STATE VARIABLES ========== */

    // Uniswap V3 related
    INonfungiblePositionManager private stakingTokenNFT = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88); // UniV3 uses an NFT
    int24 public uni_tick_lower;
    int24 public uni_tick_upper;
    uint24 public uni_required_fee;
    address public uni_token0;
    address public uni_token1;
    // Need to seed a starting token to use both as a basis for fraxPerLPToken
    // as well as getting ticks, etc
    uint256 public seed_token_id;

    // // Combo Oracle related
    // ComboOracle_UniV2_UniV3 private comboOracleUniV2UniV3 = ComboOracle_UniV2_UniV3(0x1cBE07F3b3bf3BDe44d363cecAecfe9a98EC2dff);

    // Stake tracking
    mapping(address => LockedNFT[]) public lockedNFTs;

    bool internal immutable frax_is_token0;
    // uint256 public _total_liquidity_locked;
    // mapping(address => uint256) _locked_liquidity;
    // address[] internal rewardTokens;

    /* ========== STRUCTS ========== */

    // Struct for the stake
    struct LockedNFT {
        uint256 token_id; // for Uniswap V3 LPs
        uint256 liquidity;
        uint256 start_timestamp;
        uint256 ending_timestamp;
        uint256 lock_multiplier; // 6 decimals of precision. 1x = 1000000
        int24 tick_lower;
        int24 tick_upper;
    }
    
    /* ========== CONSTRUCTOR ========== */

    constructor (
        uint256 _seed_token_id,
        address _owner,
        address[] memory _rewardTokens,
        address[] memory _rewardManagers,
        uint256[] memory _rewardRatesManual,
        address[] memory _gaugeControllers,
        address[] memory _rewardDistributors//,
        //address _stakingToken
    )
    FraxUnifiedFarmTemplate(_owner, _rewardTokens, _rewardManagers, _rewardRatesManual, _gaugeControllers, _rewardDistributors)
    {
        // Use the seed token as a template
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            ,
            ,
            ,
            ,

        ) = stakingTokenNFT.positions(_seed_token_id);

        // Set the UniV3 addresses
        uni_token0 = token0;
        uni_token1 = token1;

        frax_is_token0 = (token0 == frax_address);
        // Fee, Tick, and Liquidity related
        uni_required_fee = fee;
        uni_tick_lower = tickLower;
        uni_tick_upper = tickUpper;
        
        // Set the seed token id
        seed_token_id = _seed_token_id;

        // Infinite approve the two tokens to the Positions NFT Manager 
        // This saves gas
        IERC20(uni_token0).approve(address(stakingTokenNFT), type(uint256).max);
        IERC20(uni_token1).approve(address(stakingTokenNFT), type(uint256).max);
    }

    /* ============= VIEWS ============= */

    function fraxPerLPToken() public view override returns (uint256) {
        // Used the seeded main NFT token ID as a basis for this
        // Doing this + using fraxPerLPStored should save a lot of gas
        ComboOracle_UniV2_UniV3.UniV3NFTBasicInfo memory NFTBasicInfo = getUniV3NFTBasicInfo(seed_token_id);
        ComboOracle_UniV2_UniV3.UniV3NFTValueInfo memory NFTValueInfo = getUniV3NFTValueInfo(seed_token_id);

        if (frax_is_token0) {
            uint val = (NFTValueInfo.token0_value * MULTIPLIER_PRECISION) / NFTBasicInfo.liquidity;
            return val;
        }
        else {
            uint val = (NFTValueInfo.token1_value * MULTIPLIER_PRECISION) / NFTBasicInfo.liquidity;
            return val;
        }
    }
    // function getAllRewardTokens() external view returns (address[] memory) {
    //     return rewardTokens;
    // }
    // function earned(address account) external view returns(uint256){
    //     return 0;
    // }
    // function veFXSMultiplier(address account) external view returns(uint256){
    //     return 0;
    // }
    // function totalCombinedWeight() external view returns(uint256){
    //     return _total_liquidity_locked;
    // }
    // ------ LOCK RELATED ------

    // Return all of the locked NFT positions
    function lockedNFTsOf(address account) external view returns (LockedNFT[] memory) {
        return lockedNFTs[account];
    }

    // Returns the length of the locked NFTs for a given account
    function lockedNFTsOfLength(address account) external view returns (uint256) {
        return lockedNFTs[account].length;
    }

    function checkUniV3NFT(uint256 token_id, bool fail_if_false) internal view returns (bool is_valid, uint256 liquidity, int24 tick_lower, int24 tick_upper) {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint256 _liquidity,
            ,
            ,
            ,

        ) = stakingTokenNFT.positions(token_id);

        // Set initially
        is_valid = false;
        liquidity = _liquidity;

        // Do the checks
        if (
            (token0 == uni_token0) && 
            (token1 == uni_token1) && 
            (fee == uni_required_fee) && 
            (tickLower == uni_tick_lower) && 
            (tickUpper == uni_tick_upper)
        ) {
            is_valid = true;
        }
        else {
            // More detailed messages removed here to save space
            if (fail_if_false) {
                revert("Wrong token characteristics");
            }
        }
        return (is_valid, liquidity, tickLower, tickUpper);
    }

    function calcCurCombinedWeight(address account) public view override returns (
        uint256 old_combined_weight,
        uint256 new_vefxs_multiplier,
        uint256 new_combined_weight
    ) {
        // Get the old combined weight
        old_combined_weight = _combined_weights[account];

        // Get the veFXS multipliers
        // For the calculations, use the midpoint (analogous to midpoint Riemann sum)
        new_vefxs_multiplier = veFXSMultiplier(account);
        uint256 midpoint_vefxs_multiplier = (((new_vefxs_multiplier) + _vefxsMultiplierStored[account])) / 2; 

        // Loop through the locked stakes, first by getting the liquidity * lock_multiplier portion
        new_combined_weight = 0;
        for (uint256 i = 0; i < lockedNFTs[account].length; i++) {
            LockedNFT memory thisNFT = lockedNFTs[account][i];
            uint256 lock_multiplier = thisNFT.lock_multiplier;

            // If the lock period is over, drop the lock multiplier down to 1x for the weight calculations
            if (thisNFT.ending_timestamp <= block.timestamp){
                lock_multiplier = MULTIPLIER_PRECISION;
            }

            uint256 liquidity = thisNFT.liquidity;
            uint256 combined_boosted_amount = liquidity * (lock_multiplier + midpoint_vefxs_multiplier) / MULTIPLIER_PRECISION;
            new_combined_weight = new_combined_weight + combined_boosted_amount;
            }
        }

    /* =============== MUTATIVE FUNCTIONS =============== */

    // ------ STAKING ------

    function _getStake(address staker_address, uint256 token_id) internal view returns (LockedNFT memory locked_nft, uint256 arr_idx) {
        for (uint256 i = 0; i < lockedNFTs[staker_address].length; i++){ 
            if (token_id == lockedNFTs[staker_address][i].token_id){
                locked_nft = lockedNFTs[staker_address][i];
                arr_idx = i;
                break;
            }
        }
        require(locked_nft.token_id == token_id, "Stake not found");
        
    }

    // Add additional LPs to an existing locked stake
    // Make sure to do the 2 token approvals to the NFT Position Manager first on the UI
    // NOTE: If use_balof_override is true, make sure your calling transaction is atomic with the token
    // transfers in to prevent front running!
    function lockAdditional(
        uint256 token_id, 
        uint256 token0_amt, 
        uint256 token1_amt,
        uint256 token0_min_in, 
        uint256 token1_min_in,
        bool use_balof_override // Use balanceOf Override
    ) public {
        // Get the stake and its index
        (LockedNFT memory thisNFT, uint256 theArrayIndex) = _getStake(msg.sender, token_id);

        // Handle the tokens
        uint256 tk0_amt_to_use;
        uint256 tk1_amt_to_use;
        if (use_balof_override){
            // Get the token balances atomically sent to this farming contract
            tk0_amt_to_use = IERC20(uni_token0).balanceOf(address(this));
            tk1_amt_to_use = IERC20(uni_token1).balanceOf(address(this));
        }
        else {
            // Pull in the two tokens
            tk0_amt_to_use = token0_amt;
            tk1_amt_to_use = token1_amt;
            IERC20(uni_token0).safeTransferFrom(msg.sender, address(this), tk0_amt_to_use);
            IERC20(uni_token1).safeTransferFrom(msg.sender, address(this), tk1_amt_to_use);
        }

        // Calculate the increaseLiquidity parms
        INonfungiblePositionManager.IncreaseLiquidityParams memory inc_liq_params = INonfungiblePositionManager.IncreaseLiquidityParams(
            token_id,
            tk0_amt_to_use,
            tk1_amt_to_use,
            use_balof_override ? 0 : token0_min_in, // Ignore slippage if using balanceOf
            use_balof_override ? 0 : token1_min_in, // Ignore slippage if using balanceOf
            block.timestamp + 604800 // Expiration: 7 days from now
        );

        // Add the liquidity
        ( uint128 addl_liq, ,  ) = stakingTokenNFT.increaseLiquidity(inc_liq_params);

        // Checks
        require(addl_liq >= 0, "Must be nonzero");

        // Update the stake
        lockedNFTs[msg.sender][theArrayIndex] = LockedNFT(
            token_id,
            thisNFT.liquidity + addl_liq,
            thisNFT.start_timestamp,
            thisNFT.ending_timestamp,
            thisNFT.lock_multiplier,
            thisNFT.tick_lower,
            thisNFT.tick_upper
        );

        // Update liquidities
        _total_liquidity_locked += addl_liq;
        _locked_liquidity[msg.sender] += addl_liq;
        
    }

    // Two different stake functions are needed because of delegateCall and msg.sender issues (important for migration)
    function stakeLocked(uint256 token_id, uint256 secs) external {
        _stakeLocked(msg.sender, msg.sender, token_id, secs, block.timestamp);
    }

    // If this were not internal, and source_address had an infinite approve, this could be exploitable
    // (pull funds from source_address and stake for an arbitrary staker_address)
    function _stakeLocked(
        address staker_address,
        address source_address,
        uint256 token_id,
        uint256 secs,
        uint256 start_timestamp
    ) internal {
        require(stakingPaused == false, "Staking paused or in migration"); // || valid_migrators[msg.sender] == true, 
        require(secs >= lock_time_min, "Minimum stake time not met");
        require(secs <= lock_time_for_max_multiplier,"Trying to lock for too long");
        (, uint256 liquidity, int24 tick_lower, int24 tick_upper) = checkUniV3NFT(token_id, true); // Should throw if false

        {
            uint256 lock_multiplier = 1e18;//lockMultiplier(secs);
            lockedNFTs[staker_address].push(
                LockedNFT(
                    token_id,
                    liquidity,
                    start_timestamp,
                    start_timestamp + secs,
                    lock_multiplier,
                    tick_lower,
                    tick_upper
                )
            );
        }

        // Pull the tokens from the source_address
        stakingTokenNFT.safeTransferFrom(source_address, address(this), token_id);

        // Update liquidities
        _total_liquidity_locked += liquidity;
        _locked_liquidity[staker_address] += liquidity;
        // {
        //     address the_proxy = getProxyFor(staker_address);
        //     if (the_proxy != address(0)) proxy_lp_balances[the_proxy] += liquidity;
        // }

        // // Need to call again to make sure everything is correct
        // _updateRewardAndBalance(staker_address, false);

        emit LockNFT(staker_address, liquidity, token_id, secs, source_address);
    }

    // ------ WITHDRAWING ------

    // Two different withdrawLocked functions are needed because of delegateCall and msg.sender issues (important for migration)
    function withdrawLocked(uint256 token_id, address destination_address) external {
        // require(withdrawalsPaused == false, "Withdrawals paused");
        _withdrawLocked(msg.sender, destination_address, token_id);
    }

    // No withdrawer == msg.sender check needed since this is only internally callable and the checks are done in the wrapper
    // functions like migrator_withdraw_locked() and withdrawLocked()
    function _withdrawLocked(
        address staker_address,
        address destination_address,
        uint256 token_id
    ) internal {
        // Collect rewards first and then update the balances
        //_getReward(staker_address, destination_address);

        LockedNFT memory thisNFT;
        thisNFT.liquidity = 0;
        uint256 theArrayIndex;
        for (uint256 i = 0; i < lockedNFTs[staker_address].length; i++) {
            if (token_id == lockedNFTs[staker_address][i].token_id) {
                thisNFT = lockedNFTs[staker_address][i];
                theArrayIndex = i;
                break;
            }
        }
        require(thisNFT.token_id == token_id, "Token ID not found");
        require(block.timestamp >= thisNFT.ending_timestamp || stakesUnlocked == true, "Stake is still locked!"); // || valid_migrators[msg.sender] == true

        uint256 theLiquidity = thisNFT.liquidity;

        if (theLiquidity > 0) {
            // Update liquidities
            _total_liquidity_locked -= theLiquidity;
            _locked_liquidity[staker_address] -= theLiquidity;
            // {
            //     address the_proxy = getProxyFor(staker_address);
            //     if (the_proxy != address(0)) proxy_lp_balances[the_proxy] -= theLiquidity;
            // }

            // Remove the stake from the array
            delete lockedNFTs[staker_address][theArrayIndex];

            // Need to call again to make sure everything is correct
            // _updateRewardAndBalance(staker_address, false);

            // Give the tokens to the destination_address
            stakingTokenNFT.safeTransferFrom(address(this), destination_address, token_id);

            emit WithdrawLocked(staker_address, theLiquidity, token_id, destination_address);
        }
    }

    // function getReward(address destination_address) external returns (uint256[] memory){

    // }

    // function getReward(address destination_address, bool claim_extras) external returns (uint256[] memory){

    // }

    function _getRewardExtraLogic(address rewardee, address destination_address) internal override {
        // DO NOTHING FOR TESTING
        // Collect liquidity fees too
        // uint256 accumulated_token0 = 0;
        // uint256 accumulated_token1 = 0;
        // LockedNFT memory thisNFT;
        // for (uint256 i = 0; i < lockedNFTs[rewardee].length; i++) {
        //     thisNFT = lockedNFTs[rewardee][i];
            
        //     // Check for null entries
        //     if (thisNFT.token_id != 0){
        //         INonfungiblePositionManager.CollectParams memory collect_params = INonfungiblePositionManager.CollectParams(
        //             thisNFT.token_id,
        //             destination_address,
        //             type(uint128).max,
        //             type(uint128).max
        //         );
        //         stakingTokenNFT.collect(collect_params);
        //         (uint256 tok0_amt, uint256 tok1_amt) = stakingTokenNFT.collect(collect_params);
        //         accumulated_token0 += tok0_amt;
        //         accumulated_token1 += tok1_amt;
        //     }
        // }
    }

    // function proxyToggleStaker(address staker) external{}
    // function stakerSetVeFXSProxy(address proxy) external{}
    // function getProxyFor(address addr) external view returns (address){}
    // function toggleValidVeFXSProxy(address _proxy_addr) external {}

    // Needed to indicate that this contract is ERC721 compatible
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /* ========== EVENTS ========== */

    event LockNFT(address indexed user, uint256 liquidity, uint256 token_id, uint256 secs, address source_address);
    event WithdrawLocked(address indexed user, uint256 liquidity, uint256 token_id, address destination_address);
}