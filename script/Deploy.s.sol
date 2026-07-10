// SPDX-FileCopyrightText: © 2026 Sky Ecosystem
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.34;

import { Script } from "forge-std/Script.sol";

import { ValueRegistry } from "../src/ValueRegistry.sol";

/// @title Deploy script for the ValueRegistry
/// @notice Deploys the registry, relies each admin, kisses each bud and
///         finally denies the deployer (unless the deployer is an admin)
contract DeployValueRegistry is Script {
    function run(address[] memory admins, address[] memory buds) external returns (ValueRegistry registry) {
        require(admins.length > 0, "DeployValueRegistry/no-admins");

        vm.startBroadcast();
        (, address deployer,) = vm.readCallers();

        registry = new ValueRegistry();

        bool deployerIsAdmin;
        for (uint256 i; i < admins.length; i++) {
            registry.rely(admins[i]);
            if (admins[i] == deployer) deployerIsAdmin = true;
        }

        for (uint256 i; i < buds.length; i++) {
            registry.kiss(buds[i]);
        }

        if (!deployerIsAdmin) {
            registry.deny(deployer);
        }
        vm.stopBroadcast();
    }
}
