// SPDX-License-Identifier: MIT

// FIXME: Too much code in this now

pragma solidity >=0.6.6;

//import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import '../interfaces/ICairoFactory.sol';
import '../interfaces/ICairoRouter.sol';
import '../libraries/TransferHelper.sol';
import '../libraries/CairoLibrary.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IWETH.sol';
import 'hardhat/console.sol';

interface ISwapMining {
    function swap(address account, address input, address output, uint256 amount) external returns (bool);
}

contract CairoRouter is ICairoRouter {
    using SafeMath for uint;

    address public override factory;
    address[] public factories;
    uint[] public fees;
    mapping(address => uint) public tokenMinAmount;

    address public override WETH;
    address public swapMining;
    address private _owner;

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }


    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'CairoRouter');
        _;
    }
    

    function setSwapMining(address _swapMininng) public onlyOwner {
        swapMining = _swapMininng;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == tx.origin, "Ownable: caller is not the owner");
        _;
    }

    function initialize(address _factory, uint _fee, address _WETH) external initializer {
        _owner = tx.origin;
        factory = _factory;
        WETH = _WETH;
        factories.push(_factory);
        fees.push(_fee);
    }

    function setFactoryAndFee(uint _id, address _factory, uint _fee) external onlyOwner {
        require(_id > 0, "index 0 cannot be set");
        if (_id < factories.length) {
            factories[_id] = _factory;
            fees[_id] = _fee;
        } else {
            require(_id == factories.length, "illegal idx");
            factories.push(_factory);
            fees.push(_fee);
        }
    }

    function delFactoryAndFee(uint _id) external onlyOwner {
        require(_id > 0, "index 0 cannot be set");
        if (_id == factories.length - 1) {
            factories.pop();
            fees.pop();
        } else {
            factories[_id] = address(0);
            fees[_id] = 0;
        }
    }

    function setTokenMinAmount(address _token, uint _amount) external onlyOwner {
        tokenMinAmount[_token] = _amount;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // ADD LIQUIDITY

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (ICairoFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            ICairoFactory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = CairoLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = CairoLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'CairoRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = CairoLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'CairoRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = CairoLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = ICairoPair(pair).mint(to);
    }
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = CairoLibrary.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = ICairoPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = CairoLibrary.pairFor(factory, tokenA, tokenB);

        ICairoPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        console.log("SWAP Removed liquidity");
        (uint amount0, uint amount1) = ICairoPair(pair).burn(to);
        (address token0,) = CairoLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'CairoRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'CairoRouter: INSUFFICIENT_B_AMOUNT');
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = CairoLibrary.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? type(uint).max : liquidity;
        ICairoPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = CairoLibrary.pairFor(factory, token, WETH);
        uint value = approveMax ? type(uint).max : liquidity;
        ICairoPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

     // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pair = CairoLibrary.pairFor(factory, token, WETH);
        uint value = approveMax ? type(uint).max : liquidity;
        ICairoPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address[] memory usedFactories, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = CairoLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            if (swapMining != address(0) && usedFactories[i] == factory) {
                ISwapMining(swapMining).swap(msg.sender, input, output, amountOut);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? CairoLibrary.pairFor(usedFactories[i + 2], output, path[i + 2]) : _to;
            ICairoPair(CairoLibrary.pairFor(usedFactories[i + 1], input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        uint[] memory minAmounts = new uint[](path.length);
        for (uint i = 0; i < path.length; i ++) {
            minAmounts[i] = tokenMinAmount[path[i]];
        }
        address[] memory usedFactories;
        (amounts, usedFactories) = CairoLibrary.getAggregationAmountsOut(factories, fees, minAmounts, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'CairoRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, CairoLibrary.pairFor(usedFactories[0], path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, usedFactories, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        uint[] memory minAmounts = new uint[](path.length);
        for (uint i = 0; i < path.length; i ++) {
            minAmounts[i] = tokenMinAmount[path[i]];
        }
        address[] memory usedFactories;
        (amounts, usedFactories) = CairoLibrary.getAggregationAmountsIn(factories, fees, minAmounts, amountOut, path);
        require(amounts[0] <= amountInMax, 'CairoRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, CairoLibrary.pairFor(usedFactories[0], path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, usedFactories, to);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        uint[] memory minAmounts = new uint[](path.length);
        for (uint i = 0; i < path.length; i ++) {
            minAmounts[i] = tokenMinAmount[path[i]];
        }
        address[] memory usedFactories;
        require(path[0] == WETH, 'CairoRouter: INVALID_PATH');
        (amounts, usedFactories) = CairoLibrary.getAggregationAmountsOut(factories, fees, minAmounts, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'CairoRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(CairoLibrary.pairFor(usedFactories[0], path[0], path[1]), amounts[0]));
        _swap(amounts, path, usedFactories, to);
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        uint[] memory minAmounts = new uint[](path.length);
        for (uint i = 0; i < path.length; i ++) {
            minAmounts[i] = tokenMinAmount[path[i]];
        }
        address[] memory usedFactories;
        require(path[path.length - 1] == WETH, 'CairoRouter: INVALID_PATH');
        (amounts, usedFactories) = CairoLibrary.getAggregationAmountsIn(factories, fees, minAmounts, amountOut, path);
        require(amounts[0] <= amountInMax, 'CairoRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, CairoLibrary.pairFor(usedFactories[0], path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, usedFactories, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        uint[] memory minAmounts = new uint[](path.length);
        for (uint i = 0; i < path.length; i ++) {
            minAmounts[i] = tokenMinAmount[path[i]];
        }
        address[] memory usedFactories;
        require(path[path.length - 1] == WETH, 'CairoRouter: INVALID_PATH');
        (amounts, usedFactories) = CairoLibrary.getAggregationAmountsOut(factories, fees, minAmounts, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'CairoRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, CairoLibrary.pairFor(usedFactories[0], path[0], path[1]), amounts[0]
        );
        _swap(amounts, usedFactories, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        uint[] memory minAmounts = new uint[](path.length);
        for (uint i = 0; i < path.length; i ++) {
            minAmounts[i] = tokenMinAmount[path[i]];
        }
        address[] memory usedFactories;
        require(path[0] == WETH, 'CairoRouter: INVALID_PATH');
        (amounts, usedFactories) = CairoLibrary.getAggregationAmountsIn(factories, fees, minAmounts, amountOut, path);
        require(amounts[0] <= msg.value, 'CairoRouter: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(CairoLibrary.pairFor(usedFactories[0], path[0], path[1]), amounts[0]));
        _swap(amounts, usedFactories, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    function getReserve(ICairoPair pair, address token0, address token1) internal view returns(uint reserve0, uint reserve1, address token) {
        (token,) = CairoLibrary.sortTokens(token0, token1);
        (uint _reserve0, uint _reserve1,) = pair.getReserves();
        (reserve0, reserve1) = token0 == token ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address[] memory pairs, uint[] memory usedFees, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (uint reserveInput, uint reserveOutput, address token0) = getReserve(ICairoPair(pairs[i + 1]), input, output);
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            amountInput = IERC20(input).balanceOf(address(pairs[i + 1])).sub(reserveInput);
            amountOutput = CairoLibrary.getAmountOutWithFee(amountInput, reserveInput, reserveOutput, usedFees[i + 1]);
            }
            if (swapMining != address(0) && ICairoPair(pairs[i + 1]).factory() == factory) {
                ISwapMining(swapMining).swap(msg.sender, input, output, amountOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? pairs[i + 2] : _to;
            ICairoPair(pairs[i + 1]).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function getPairs(address[] calldata path) internal view returns (address[] memory pairs, uint[] memory usedFees) {
        uint[] memory minAmounts = new uint[](path.length);
        for (uint i = 0; i < path.length; i ++) {
            minAmounts[i] = tokenMinAmount[path[i]];
        }
        for (uint i = 0; i < path.length - 1; i ++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = CairoLibrary.sortTokens(input, output);
            uint j = 0;
            for (; j < factories.length; j ++) {
                ICairoPair pair = ICairoPair(CairoLibrary.pairFor(factories[j], path[i], path[i + 1]));
                (uint reserve0, uint reserve1,) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                if (reserveInput >= minAmounts[i] && reserveOutput >= minAmounts[i + 1]) {
                    pairs[i + 1] = address(pair);
                    usedFees[i + 1] = fees[j];
                    break;
                }
            }
            if (j == factories.length) {
                pairs[i + 1] = CairoLibrary.pairFor(factories[0], path[i], path[i + 1]); 
                usedFees[i + 1] = fees[0];
            }
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        address[] memory pairs = new address[](path.length);
        uint[] memory usedFees = new uint[](path.length);
        (pairs, usedFees) = getPairs(path);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairs[1], amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, pairs, usedFees,  to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'CairoRouter'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == WETH, 'CairoRouter');
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        address[] memory pairs = new address[](path.length);
        uint[] memory usedFees = new uint[](path.length);
        (pairs, usedFees) = getPairs(path);
        assert(IWETH(WETH).transfer(pairs[1], amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, pairs, usedFees, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'CairoRouter'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'CairoRouter: INVALID_PATH');
        address[] memory pairs = new address[](path.length);
        uint[] memory usedFees = new uint[](path.length);
        (pairs, usedFees) = getPairs(path);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairs[1], amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, pairs, usedFees, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'CairoRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return CairoLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return CairoLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return CairoLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        uint[] memory minAmounts = new uint[](path.length);
        for (uint i = 0; i < path.length; i ++) {
            minAmounts[i] = tokenMinAmount[path[i]];
        }
        (amounts, ) = CairoLibrary.getAggregationAmountsOut(factories, fees, minAmounts, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        uint[] memory minAmounts = new uint[](path.length);
        for (uint i = 0; i < path.length; i ++) {
            minAmounts[i] = tokenMinAmount[path[i]];
        }
        (amounts, ) = CairoLibrary.getAggregationAmountsIn(factories, fees, minAmounts, amountOut, path);
    }
}
