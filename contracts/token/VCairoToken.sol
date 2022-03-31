// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/DecimalMath.sol";

contract vCAIROToken is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // ============ Storage(ERC20) ============

    string public name = "vCAIRO Membership Token";
    string public symbol = "vCAIRO";
    uint8 public decimals = 18;

    mapping(address => mapping(address => uint256)) internal _allowed;

    // ============ Storage ============

    address public _cairoToken;
    address public _cairoTeam;
    address public _cairoReserve;
    address public _cairoTreasury;
    bool public _canTransfer;
    address public constant hole = 0x000000000000000000000000000000000000dEaD;

    // staking reward parameters
    uint256 public _cairoPerBlock;
    uint256 public constant _superiorRatio = 10**17; // 0.1
    uint256 public constant _cairoRatio = 100; // 100
    uint256 public _cairoFeeBurnRatio = 30 * 10**16; //30%
    uint256 public _cairoFeeReserveRatio = 20 * 10**16; //20%
    uint256 public _feeRatio = 10 * 10**16; //10%;
    // accounting
    uint112 public alpha = 10**18; // 1
    uint112 public _totalBlockDistribution;
    uint32 public _lastRewardBlock;

    uint256 public _totalBlockReward;
    uint256 public _totalStakingPower;
    mapping(address => UserInfo) public userInfo;

    uint256 public _superiorMinCAIRO = 1000e18; //The superior must obtain the min CAIRO that should be pledged for invitation rewards

    struct UserInfo {
        uint128 stakingPower;
        uint128 superiorSP;
        address superior;
        uint256 credit;
        uint256 creditDebt;
    }

    // ============ Events ============

    event MintVCAIRO(
        address user,
        address superior,
        uint256 mintCAIRO,
        uint256 totalStakingPower
    );
    event RedeemVCAIRO(
        address user,
        uint256 receiveCAIRO,
        uint256 burnCAIRO,
        uint256 feeCAIRO,
        uint256 reserveCAIRO,
        uint256 totalStakingPower
    );
    event DonateCAIRO(address user, uint256 donateCAIRO);
    event SetCanTransfer(bool allowed);

    event PreDeposit(uint256 cairoAmount);
    event ChangePerReward(uint256 cairoPerBlock);
    event UpdateCAIROFeeBurnRatio(uint256 cairoFeeBurnRatio);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    // ============ Modifiers ============

    modifier canTransfer() {
        require(_canTransfer, "vCAIROToken: not allowed transfer");
        _;
    }

    modifier balanceEnough(address account, uint256 amount) {
        require(
            availableBalanceOf(account) >= amount,
            "vCAIROToken: available amount not enough"
        );
        _;
    }

    event TokenInfo(uint256 cairoTokenSupply, uint256 cairoBalanceInVCairo);
    event CurrentUserInfo(
        address user,
        uint128 stakingPower,
        uint128 superiorSP,
        address superior,
        uint256 credit,
        uint256 creditDebt
    );

    function logTokenInfo(IERC20 token) internal {
        emit TokenInfo(token.totalSupply(), token.balanceOf(address(this)));
    }

    function logCurrentUserInfo(address user) internal {
        UserInfo storage currentUser = userInfo[user];
        emit CurrentUserInfo(
            user,
            currentUser.stakingPower,
            currentUser.superiorSP,
            currentUser.superior,
            currentUser.credit,
            currentUser.creditDebt
        );
    }

    // ============ Constructor ============

    constructor(
        address cairoToken,
        address cairoTeam,
        address cairoReserve,
        address cairoTreasury
    ) {
        _cairoToken = cairoToken;
        _cairoTeam = cairoTeam;
        _cairoReserve = cairoReserve;
        _cairoTreasury = cairoTreasury;
        changePerReward(2 * 10**18);
    }

    // ============ Ownable Functions ============`

    function setCanTransfer(bool allowed) public onlyOwner {
        _canTransfer = allowed;
        emit SetCanTransfer(allowed);
    }

    function changePerReward(uint256 cairoPerBlock) public onlyOwner {
        _updateAlpha();
        _cairoPerBlock = cairoPerBlock;
        logTokenInfo(IERC20(_cairoToken));
        emit ChangePerReward(cairoPerBlock);
    }

    function updateCAIROFeeBurnRatio(uint256 cairoFeeBurnRatio) public onlyOwner {
        _cairoFeeBurnRatio = cairoFeeBurnRatio;
        emit UpdateCAIROFeeBurnRatio(_cairoFeeBurnRatio);
    }

    function updateCAIROFeeReserveRatio(uint256 cairoFeeReserve)
        public
        onlyOwner
    {
        _cairoFeeReserveRatio = cairoFeeReserve;
    }

    function updateTeamAddress(address team) public onlyOwner {
        _cairoTeam = team;
    }

    function updateTreasuryAddress(address treasury) public onlyOwner {
        _cairoTreasury = treasury;
    }

    function updateReserveAddress(address newAddress) public onlyOwner {
        _cairoReserve = newAddress;
    }

    function setSuperiorMinCAIRO(uint256 val) public onlyOwner {
        _superiorMinCAIRO = val;
    }

    function emergencyWithdraw() public onlyOwner {
        uint256 cairoBalance = IERC20(_cairoToken).balanceOf(address(this));
        IERC20(_cairoToken).safeTransfer(owner(), cairoBalance);
    }

    // ============ Mint & Redeem & Donate ============

    function mint(uint256 cairoAmount, address superiorAddress) public {
        require(
            superiorAddress != address(0) && superiorAddress != msg.sender,
            "vCAIROToken: Superior INVALID"
        );
        require(cairoAmount >= 1e18, "vCAIROToken: must mint greater than 1");

        UserInfo storage user = userInfo[msg.sender];

        if (user.superior == address(0)) {
            require(
                superiorAddress == _cairoTeam ||
                    userInfo[superiorAddress].superior != address(0),
                "vCAIROToken: INVALID_SUPERIOR_ADDRESS"
            );
            user.superior = superiorAddress;
        }

        if (_superiorMinCAIRO > 0) {
            uint256 curCAIRO = cairoBalanceOf(user.superior);
            if (curCAIRO < _superiorMinCAIRO) {
                user.superior = _cairoTeam;
            }
        }

        _updateAlpha();

        IERC20(_cairoToken).safeTransferFrom(
            msg.sender,
            address(this),
            cairoAmount
        );

        uint256 newStakingPower = DecimalMath.divFloor(cairoAmount, alpha);

        _mint(user, newStakingPower);

        logTokenInfo(IERC20(_cairoToken));
        logCurrentUserInfo(msg.sender);
        logCurrentUserInfo(user.superior);
        emit MintVCAIRO(
            msg.sender,
            superiorAddress,
            cairoAmount,
            _totalStakingPower
        );
    }

    function redeem(uint256 vCairoAmount, bool all)
        public
        balanceEnough(msg.sender, vCairoAmount)
    {
        _updateAlpha();
        UserInfo storage user = userInfo[msg.sender];

        uint256 cairoAmount;
        uint256 stakingPower;

        if (all) {
            stakingPower = uint256(user.stakingPower).sub(
                DecimalMath.divFloor(user.credit, alpha)
            );
            cairoAmount = DecimalMath.mulFloor(stakingPower, alpha);
        } else {
            cairoAmount = vCairoAmount.mul(_cairoRatio);
            stakingPower = DecimalMath.divFloor(cairoAmount, alpha);
        }

        _redeem(user, stakingPower);

        (
            uint256 cairoReceive,
            uint256 burnCairoAmount,
            uint256 withdrawFeeAmount,
            uint256 reserveAmount
        ) = getWithdrawResult(cairoAmount);

        IERC20(_cairoToken).safeTransfer(msg.sender, cairoReceive);

        if (burnCairoAmount > 0) {
            IERC20(_cairoToken).safeTransfer(hole, burnCairoAmount);
        }
        if (reserveAmount > 0) {
            IERC20(_cairoToken).safeTransfer(_cairoReserve, reserveAmount);
        }

        if (withdrawFeeAmount > 0) {
            alpha = uint112(
                uint256(alpha).add(
                    DecimalMath.divFloor(withdrawFeeAmount, _totalStakingPower)
                )
            );
        }

        logTokenInfo(IERC20(_cairoToken));
        logCurrentUserInfo(msg.sender);
        logCurrentUserInfo(user.superior);
        emit RedeemVCAIRO(
            msg.sender,
            cairoReceive,
            burnCairoAmount,
            withdrawFeeAmount,
            reserveAmount,
            _totalStakingPower
        );
    }

    function donate(uint256 cairoAmount) public {
        IERC20(_cairoToken).safeTransferFrom(
            msg.sender,
            address(this),
            cairoAmount
        );

        alpha = uint112(
            uint256(alpha).add(
                DecimalMath.divFloor(cairoAmount, _totalStakingPower)
            )
        );
        logTokenInfo(IERC20(_cairoToken));
        emit DonateCAIRO(msg.sender, cairoAmount);
    }

    function totalSupply() public view returns (uint256 vCairoSupply) {
        uint256 totalCairo = IERC20(_cairoToken).balanceOf(address(this));
        (, uint256 curDistribution) = getLatestAlpha();

        uint256 actualCairo = totalCairo.add(curDistribution);
        vCairoSupply = actualCairo / _cairoRatio;
    }

    function balanceOf(address account)
        public
        view
        returns (uint256 vCairoAmount)
    {
        vCairoAmount = cairoBalanceOf(account) / _cairoRatio;
    }

    function transfer(address to, uint256 vCairoAmount) public returns (bool) {
        _updateAlpha();
        _transfer(msg.sender, to, vCairoAmount);
        return true;
    }

    function approve(address spender, uint256 vCairoAmount)
        public
        canTransfer
        returns (bool)
    {
        _allowed[msg.sender][spender] = vCairoAmount;
        emit Approval(msg.sender, spender, vCairoAmount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 vCairoAmount
    ) public returns (bool) {
        require(
            vCairoAmount <= _allowed[from][msg.sender],
            "ALLOWANCE_NOT_ENOUGH"
        );
        _updateAlpha();
        _transfer(from, to, vCairoAmount);
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(
            vCairoAmount
        );
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        returns (uint256)
    {
        return _allowed[owner][spender];
    }

    // ============ Helper Functions ============

    function getLatestAlpha()
        public
        view
        returns (uint256 newAlpha, uint256 curDistribution)
    {
        if (_lastRewardBlock == 0) {
            curDistribution = 0;
        } else {
            curDistribution = _cairoPerBlock * (block.number - _lastRewardBlock);
        }
        if (_totalStakingPower > 0) {
            newAlpha = uint256(alpha).add(
                DecimalMath.divFloor(curDistribution, _totalStakingPower)
            );
        } else {
            newAlpha = alpha;
        }
    }

    function availableBalanceOf(address account)
        public
        view
        returns (uint256 vCairoAmount)
    {
        vCairoAmount = balanceOf(account);
    }

    function cairoBalanceOf(address account)
        public
        view
        returns (uint256 cairoAmount)
    {
        UserInfo memory user = userInfo[account];
        (uint256 newAlpha, ) = getLatestAlpha();
        uint256 nominalCairo = DecimalMath.mulFloor(
            uint256(user.stakingPower),
            newAlpha
        );
        if (nominalCairo > user.credit) {
            cairoAmount = nominalCairo - user.credit;
        } else {
            cairoAmount = 0;
        }
    }

    function getWithdrawResult(uint256 cairoAmount)
        public
        view
        returns (
            uint256 cairoReceive,
            uint256 burnCairoAmount,
            uint256 withdrawFeeCairoAmount,
            uint256 reserveCairoAmount
        )
    {
        uint256 feeRatio = _feeRatio;

        withdrawFeeCairoAmount = DecimalMath.mulFloor(cairoAmount, feeRatio);
        cairoReceive = cairoAmount.sub(withdrawFeeCairoAmount);

        burnCairoAmount = DecimalMath.mulFloor(
            withdrawFeeCairoAmount,
            _cairoFeeBurnRatio
        );
        reserveCairoAmount = DecimalMath.mulFloor(
            withdrawFeeCairoAmount,
            _cairoFeeReserveRatio
        );

        withdrawFeeCairoAmount = withdrawFeeCairoAmount.sub(burnCairoAmount);
        withdrawFeeCairoAmount = withdrawFeeCairoAmount.sub(reserveCairoAmount);
    }

    function setRatioValue(uint256 ratioFee) public onlyOwner {
        _feeRatio = ratioFee;
    }

    function getSuperior(address account)
        public
        view
        returns (address superior)
    {
        return userInfo[account].superior;
    }

    // ============ Internal Functions ============

    function _updateAlpha() internal {
        (uint256 newAlpha, uint256 curDistribution) = getLatestAlpha();
        uint256 newTotalDistribution = curDistribution.add(
            _totalBlockDistribution
        );
        require(
            newAlpha <= type(uint112).max && newTotalDistribution <= type(uint112).max,
            "OVERFLOW"
        );
        alpha = uint112(newAlpha);
        _totalBlockDistribution = uint112(newTotalDistribution);
        _lastRewardBlock = uint32(block.number);

        if (curDistribution > 0) {
            IERC20(_cairoToken).safeTransferFrom(
                _cairoTreasury,
                address(this),
                curDistribution
            );

            _totalBlockReward = _totalBlockReward.add(curDistribution);
            logTokenInfo(IERC20(_cairoToken));
            emit PreDeposit(curDistribution);
        }
    }

    function _mint(UserInfo storage to, uint256 stakingPower) internal {
        require(stakingPower <= type(uint128).max, "OVERFLOW");
        UserInfo storage superior = userInfo[to.superior];
        uint256 superiorIncreSP = DecimalMath.mulFloor(
            stakingPower,
            _superiorRatio
        );
        uint256 superiorIncreCredit = DecimalMath.mulFloor(
            superiorIncreSP,
            alpha
        );

        to.stakingPower = uint128(uint256(to.stakingPower).add(stakingPower));
        to.superiorSP = uint128(uint256(to.superiorSP).add(superiorIncreSP));

        superior.stakingPower = uint128(
            uint256(superior.stakingPower).add(superiorIncreSP)
        );
        superior.credit = uint128(
            uint256(superior.credit).add(superiorIncreCredit)
        );

        _totalStakingPower = _totalStakingPower.add(stakingPower).add(
            superiorIncreSP
        );
    }

    function _redeem(UserInfo storage from, uint256 stakingPower) internal {
        from.stakingPower = uint128(
            uint256(from.stakingPower).sub(stakingPower)
        );

        uint256 userCreditSP = DecimalMath.divFloor(from.credit, alpha);
        if (from.stakingPower > userCreditSP) {
            from.stakingPower = uint128(
                uint256(from.stakingPower).sub(userCreditSP)
            );
        } else {
            userCreditSP = from.stakingPower;
            from.stakingPower = 0;
        }
        from.creditDebt = from.creditDebt.add(from.credit);
        from.credit = 0;

        // superior decrease sp = min(stakingPower*0.1, from.superiorSP)
        uint256 superiorDecreSP = DecimalMath.mulFloor(
            stakingPower,
            _superiorRatio
        );
        superiorDecreSP = from.superiorSP <= superiorDecreSP
            ? from.superiorSP
            : superiorDecreSP;
        from.superiorSP = uint128(
            uint256(from.superiorSP).sub(superiorDecreSP)
        );
        uint256 superiorDecreCredit = DecimalMath.mulFloor(
            superiorDecreSP,
            alpha
        );

        UserInfo storage superior = userInfo[from.superior];
        if (superiorDecreCredit > superior.creditDebt) {
            uint256 dec = DecimalMath.divFloor(superior.creditDebt, alpha);
            superiorDecreSP = dec >= superiorDecreSP
                ? 0
                : superiorDecreSP.sub(dec);
            superiorDecreCredit = superiorDecreCredit.sub(superior.creditDebt);
            superior.creditDebt = 0;
        } else {
            superior.creditDebt = superior.creditDebt.sub(superiorDecreCredit);
            superiorDecreCredit = 0;
            superiorDecreSP = 0;
        }
        uint256 creditSP = DecimalMath.divFloor(superior.credit, alpha);

        if (superiorDecreSP >= creditSP) {
            superior.credit = 0;
            superior.stakingPower = uint128(
                uint256(superior.stakingPower).sub(creditSP)
            );
        } else {
            superior.credit = uint128(
                uint256(superior.credit).sub(superiorDecreCredit)
            );
            superior.stakingPower = uint128(
                uint256(superior.stakingPower).sub(superiorDecreSP)
            );
        }

        _totalStakingPower = _totalStakingPower
            .sub(stakingPower)
            .sub(superiorDecreSP)
            .sub(userCreditSP);
    }

    function _transfer(
        address from,
        address to,
        uint256 vCairoAmount
    ) internal canTransfer balanceEnough(from, vCairoAmount) {
        require(from != address(0), "transfer from the zero address");
        require(to != address(0), "transfer to the zero address");
        require(from != to, "transfer from same with to");

        uint256 stakingPower = DecimalMath.divFloor(
            vCairoAmount * _cairoRatio,
            alpha
        );

        UserInfo storage fromUser = userInfo[from];
        UserInfo storage toUser = userInfo[to];

        _redeem(fromUser, stakingPower);
        _mint(toUser, stakingPower);

        logTokenInfo(IERC20(_cairoToken));
        logCurrentUserInfo(from);
        logCurrentUserInfo(fromUser.superior);
        logCurrentUserInfo(to);
        logCurrentUserInfo(toUser.superior);
        emit Transfer(from, to, vCairoAmount);
    }
}
