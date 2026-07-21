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

import {DeployValueRegistry} from "../script/Deploy.s.sol";
import {ValueRegistry} from "../src/ValueRegistry.sol";

contract DeployTest is Test {
    DeployValueRegistry script;

    address admin = address(0xa27);
    address admin2 = address(0xa28);
    address bud = address(0xb0d);

    function setUp() public {
        script = new DeployValueRegistry();
    }

    /// @dev Runs the script and recovers the deployer (broadcast sender)
    ///      from the constructor's Rely event, so the test does not depend
    ///      on which sender forge picks for broadcasts
    function _run(address[] memory admins, address[] memory buds)
        internal
        returns (ValueRegistry registry, address deployer, Vm.Log[] memory logs)
    {
        vm.recordLogs();
        registry = script.run(admins, buds);

        logs = vm.getRecordedLogs();
        assertEq(logs[0].topics[0], ValueRegistry.Rely.selector);
        deployer = address(uint160(uint256(logs[0].topics[1])));
    }

    /// @dev Counts `topic0(usr)` events emitted for `usr` in the recorded logs
    function _countFor(Vm.Log[] memory logs, bytes32 topic0, address usr) internal pure returns (uint256 n) {
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].topics.length < 2) continue;
            if (logs[i].topics[0] == topic0 && logs[i].topics[1] == bytes32(uint256(uint160(usr)))) n++;
        }
    }

    function testRun() public {
        address[] memory admins = new address[](2);
        admins[0] = admin;
        admins[1] = admin2;
        address[] memory buds = new address[](1);
        buds[0] = bud;

        (ValueRegistry registry, address deployer,) = _run(admins, buds);

        assertEq(registry.wards(admin), 1, "testRun/admin-is-ward");
        assertEq(registry.wards(admin2), 1, "testRun/admin2-is-ward");
        assertEq(registry.buds(bud), 1, "testRun/bud-is-bud");
        assertEq(registry.wards(bud), 0, "testRun/bud-is-not-ward");
        assertEq(registry.buds(admin), 0, "testRun/admin-is-not-bud");

        assertEq(registry.wards(deployer), 0, "testRun/deployer-denied");

        assertEq(registry.count(), 0, "testRun/registry-starts-empty");
    }

    function testRunNoBuds() public {
        address[] memory admins = new address[](1);
        admins[0] = admin;

        (ValueRegistry registry,,) = _run(admins, new address[](0));

        assertEq(registry.wards(admin), 1, "testRunNoBuds/admin-is-ward");
    }

    function testRunDeployerIsAdmin() public {
        // Discovery run to learn the broadcast sender used in this environment
        address[] memory admins = new address[](1);
        admins[0] = admin;
        (, address deployer,) = _run(admins, new address[](0));

        address[] memory adminsWithDeployer = new address[](2);
        adminsWithDeployer[0] = admin;
        adminsWithDeployer[1] = deployer;
        (ValueRegistry registry, address deployer2, Vm.Log[] memory logs) = _run(adminsWithDeployer, new address[](0));

        assertEq(deployer2, deployer, "testRunDeployerIsAdmin/same-broadcast-sender");
        assertEq(registry.wards(deployer), 1, "testRunDeployerIsAdmin/deployer-admin-keeps-access");
        assertEq(registry.wards(admin), 1, "testRunDeployerIsAdmin/admin-is-ward");

        // The constructor already relies the deployer, so listing them as an admin
        // must not emit a second Rely, and must not emit a Deny that is later undone
        assertEq(
            _countFor(logs, ValueRegistry.Rely.selector, deployer), 1, "testRunDeployerIsAdmin/no-double-rely-deployer"
        );
        assertEq(_countFor(logs, ValueRegistry.Rely.selector, admin), 1, "testRunDeployerIsAdmin/single-rely-admin");
        assertEq(_countFor(logs, ValueRegistry.Deny.selector, deployer), 0, "testRunDeployerIsAdmin/no-deny-deployer");
    }

    function testRevertRunZeroAddressAdmin() public {
        address[] memory admins = new address[](2);
        admins[0] = admin;
        admins[1] = address(0);

        vm.expectRevert("DeployValueRegistry/admin-is-zero");
        script.run(admins, new address[](0));
    }

    function testRevertRunZeroAddressBud() public {
        address[] memory admins = new address[](1);
        admins[0] = admin;
        address[] memory buds = new address[](2);
        buds[0] = bud;
        buds[1] = address(0);

        vm.expectRevert("DeployValueRegistry/bud-is-zero");
        script.run(admins, buds);
    }

    function testRevertRunNoAdmins() public {
        address[] memory buds = new address[](1);
        buds[0] = bud;

        vm.expectRevert("DeployValueRegistry/no-admins");
        script.run(new address[](0), buds);
    }
}
