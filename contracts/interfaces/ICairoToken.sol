// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2;

import './IBEP20.sol';

interface ICairoRouter is IBEP20 {
    function transferFromCairoNetwork(address sender, address recipient, uint256 amount) external;
}
