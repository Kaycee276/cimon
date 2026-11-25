// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "./MockERC20.sol";

/// @dev Token that calls back into a target during transfer or transferFrom, simulating a
///      malicious or hook-enabled token. Records whether the reentrant call succeeded.
contract ReentrantERC20 is MockERC20 {
    address public target;
    bytes public payload;
    bool public onTransferFrom;
    bool public armed;

    bool public reentrySucceeded;
    bytes public reentryReturn;
    uint256 public reentryAttempts;

    function arm(address target_, bytes calldata payload_, bool onTransferFrom_) external {
        target = target_;
        payload = payload_;
        onTransferFrom = onTransferFrom_;
        armed = true;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _move(msg.sender, to, amount);
        if (armed && !onTransferFrom) _attack();
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _move(from, to, amount);
        if (armed && onTransferFrom) _attack();
        return true;
    }

    function _attack() private {
        armed = false; // attack once
        ++reentryAttempts;
        (reentrySucceeded, reentryReturn) = target.call(payload);
    }
}
