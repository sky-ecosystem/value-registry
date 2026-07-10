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

pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { DeployValueRegistry } from "../script/Deploy.s.sol";
import { ValueRegistry } from "../src/ValueRegistry.sol";

contract DeployTest is Test {
    DeployValueRegistry deploy;

    address admin = address(0xa27);
    address admin2 = address(0xa28);
    address bud = address(0xb0d);

    function setUp() public {
        deploy = new DeployValueRegistry();
    }

    /// @dev Runs the script and recovers the deployer (broadcast sender)
    ///      from the constructor's Rely event, so the test does not depend
    ///      on which sender forge picks for broadcasts
    function _run(address[] memory admins, address[] memory buds)
        internal
        returns (ValueRegistry registry, address deployer)
    {
        vm.recordLogs();
        registry = deploy.run(admins, buds);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs[0].topics[0], ValueRegistry.Rely.selector);
        deployer = address(uint160(uint256(logs[0].topics[1])));
    }

    function testRun() public {
        address[] memory admins = new address[](2);
        admins[0] = admin;
        admins[1] = admin2;
        address[] memory buds = new address[](1);
        buds[0] = bud;

        (ValueRegistry registry, address deployer) = _run(admins, buds);

        assertEq(registry.wards(admin), 1, "admin-is-ward");
        assertEq(registry.wards(admin2), 1, "admin2-is-ward");
        assertEq(registry.buds(bud), 1, "bud-is-bud");
        assertEq(registry.wards(bud), 0, "bud-is-not-ward");
        assertEq(registry.buds(admin), 0, "admin-is-not-bud");

        assertEq(registry.wards(deployer), 0, "deployer-denied");

        assertEq(registry.count(), 0, "registry-starts-empty");
    }

    function testRunNoBuds() public {
        address[] memory admins = new address[](1);
        admins[0] = admin;

        (ValueRegistry registry,) = _run(admins, new address[](0));

        assertEq(registry.wards(admin), 1);
    }

    function testRunDeployerIsAdmin() public {
        // Discovery run to learn the broadcast sender used in this environment
        address[] memory admins = new address[](1);
        admins[0] = admin;
        (, address deployer) = _run(admins, new address[](0));

        address[] memory adminsWithDeployer = new address[](2);
        adminsWithDeployer[0] = admin;
        adminsWithDeployer[1] = deployer;
        (ValueRegistry registry, address deployer2) = _run(adminsWithDeployer, new address[](0));

        assertEq(deployer2, deployer, "same-broadcast-sender");
        assertEq(registry.wards(deployer), 1, "deployer-admin-keeps-access");
        assertEq(registry.wards(admin), 1, "admin-is-ward");
    }

    function testRevertRunNoAdmins() public {
        address[] memory buds = new address[](1);
        buds[0] = bud;

        vm.expectRevert("DeployValueRegistry/no-admins");
        deploy.run(new address[](0), buds);
    }
}
