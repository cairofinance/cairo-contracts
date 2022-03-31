// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

import './CairoPair.sol';
import '../libraries/CairoLibrary.sol';
import '../interfaces/ICairoRouter.sol';
import '../interfaces/ICairoFactory.sol';
import '../interfaces/ICairoPair.sol';
import '../libraries/SafeMath.sol';
import '../token/SafeBEP20.sol';
import 'hardhat/console.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '../libraries/Address.sol';

contract CairoFinanceFee is Ownable {
    using SafeMath for uint;
    using Address for address;

    address public constant hole = 0x000000000000000000000000000000000000dEaD;
    address public immutable Pyramid;
    address public immutable vault;
    ICairoRouter public immutable router;
    ICairoFactory public immutable factory;
    address public immutable WBNB;
    address public immutable CAIRO;
    address public immutable USDT;
    address public immutable receiver;
    address public caller;

    constructor(address Pyramid_, address vault_, ICairoRouter router_, ICairoFactory factory_, address WBNB_, address CAIRO_, address USDT_, address receiver_, address caller_) {
        Pyramid = Pyramid_; 
        vault = vault_;
        router = router_;
        factory = factory_;
        WBNB = WBNB_;
        CAIRO = CAIRO_;
        USDT = USDT_;
        receiver = receiver_;
        caller = caller_;
    }

    function setCaller(address newCaller_) external onlyOwner {
        require(newCaller_ != address(0), "caller is zero");
        caller = newCaller_;
    }

    function transferToVault(ICairoPair pair, uint balance) internal returns (uint balanceRemained) {
        uint balanceUsed = balance.div(3);
        balanceRemained = balance.sub(balanceUsed);
        SafeBEP20.safeTransfer(IBEP20(address(pair)), vault, balanceUsed);
    }

    function transferToPyramid(address token, uint balance) internal returns (uint balanceRemained) {
        uint balanceUsed = balance.div(2);
        balanceRemained = balance.sub(balanceUsed);
        SafeBEP20.safeTransfer(IBEP20(token), Pyramid, balanceUsed);
    }

    function doHardwork(address[] calldata pairs, uint minAmount) external {
        require(msg.sender == caller, "illegal caller");
        for (uint i = 0; i < pairs.length; i ++) {
            ICairoPair pair = ICairoPair(pairs[i]);
            if (pair.token0() != USDT && pair.token1() != USDT) {
                continue;
            }
            uint balance = pair.balanceOf(address(this));
            if (balance == 0) {
                continue;
            }
            if (balance < minAmount) {
                continue;
            }
            balance = transferToVault(pair, balance);
            address token = pair.token0() != USDT ? pair.token0() : pair.token1();
            pair.approve(address(router), balance);
            router.removeLiquidity(
                token,
                USDT,
                balance,
                0,
                0,
                address(this),
                block.timestamp
            );
            address[] memory path = new address[](2);
            path[0] = token;path[1] = USDT;
            balance = IBEP20(token).balanceOf(address(this));
            IBEP20(token).approve(address(router), balance);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                balance,
                0,
                path,
                address(this),
                block.timestamp
            );
        }
    }

    function destroyAll() external onlyOwner {
        uint balance = IBEP20(USDT).balanceOf(address(this));
        balance = transferToPyramid(USDT, balance);
        address[] memory path = new address[](2);
        path[0] = USDT;path[1] = CAIRO;
        balance = IBEP20(USDT).balanceOf(address(this));
        IBEP20(USDT).approve(address(router), balance);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            balance,
            0,
            path,
            address(this),
            block.timestamp
        );
        balance = IBEP20(CAIRO).balanceOf(address(this));
        SafeBEP20.safeTransfer(IBEP20(CAIRO), hole, balance);
    }

    function transferOut(address token, uint amount) external {
        IBEP20 bep20 = IBEP20(token);
        uint balance = bep20.balanceOf(address(this));
        if (balance < amount) {
            amount = balance;
        }
        SafeBEP20.safeTransfer(bep20, receiver, amount);
    }
}
