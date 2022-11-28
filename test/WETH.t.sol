// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/WETH.sol";

contract WETHTest is Test {
    WETH public weth;
    address bob = address(0x1);
    address mary = address(0x2);

    bytes32 constant depositEventTopic = keccak256('Deposit(address,uint256)');
    bytes32 constant approvalEventTopic = keccak256('Approval(address,address,uint256)');
    bytes32 constant transferEventTopic = keccak256('Transfer(address,address,uint256)');

    // Needed so the test contract itself can receive ether
    // when withdrawing
    receive() external payable {}

    function setUp() public {
        weth = new WETH();
    }

    function testInitialTotalSupply() public {
        weth = new WETH();
        uint amount = weth.totalSupply();
        assertEq(amount, 0);
    }

    function testDeposit() public {
        uint256 amoutDeposit = 1 ether;
        weth.deposit{value: amoutDeposit}();
        assertEq(weth.balanceOf(address(this)), amoutDeposit);
    }

    function testReceive() public {
        uint256 amoutDeposit = 1 ether;
        (bool success,) = address(weth).call{value: amoutDeposit}("");
        assertEq(success, true);
        assertEq(weth.balanceOf(address(this)), amoutDeposit);
    }

    function testWithdraw() public {
        uint256 amoutDeposit = 1 ether;
        weth.deposit{value: amoutDeposit}();
        assertEq(weth.balanceOf(address(this)), amoutDeposit);
        weth.withdraw(0.1 ether);
        assertEq(weth.balanceOf(address(this)), 0.9 ether);
    }

    function testTransfer() public {
        // Deposit WETH for test contract address
        uint256 amoutDeposit = 3 ether;
        weth.deposit{value: amoutDeposit}();
        assertEq(weth.balanceOf(address(this)), amoutDeposit);

        // Transfer WETH from test constract address to Mary address
        uint256 amountTransfer = 1;
        bool success = weth.transfer(mary, 1);
        assertEq(success, true);
        uint balanceWETHMary = weth.balanceOf(mary);
        assertEq(balanceWETHMary, amountTransfer);
    }

    function testApprove() public {
        vm.recordLogs();

        // Test contract deposits WETH
        uint256 amoutDeposit = 3 ether;
        weth.deposit{value: amoutDeposit}(); // one event
        assertEq(weth.balanceOf(address(this)), amoutDeposit);

        // Approve Bob to use some of this test contracts WETH
        uint256 bobAllowance = 1 ether;
        bool success = weth.approve(bob, bobAllowance); // two events
        assertEq(success, true);

        // Bob transfer some WETH to Mary
        address testerContractAddress = address(this);
        vm.startPrank(bob); // Prank means we are now calling functions as bob address
        uint256 amountMary = 0.5 ether;
        weth.transferFrom(testerContractAddress, mary, amountMary); // 3 events
        assertEq(weth.balanceOf(mary), amountMary);
        vm.stopPrank();

        // Get all events fired
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Check right amount of events fired
        assertEq(entries.length, 3);

        // Check first event deposit
        assertEq(entries[0].topics[0], depositEventTopic);
        assertEq(entries[0].topics[1], bytes32(abi.encode(testerContractAddress))); // Check Address deposited
        assertEq(abi.decode(entries[0].data, (uint256)), uint256(amoutDeposit)); // Check Amount deposited

        // Check second event approve
        assertEq(entries[1].topics[0], approvalEventTopic);
        assertEq(entries[1].topics[1], bytes32(abi.encode(testerContractAddress))); // Check Address approving
        assertEq(entries[1].topics[2], bytes32(abi.encode(bob))); // Check approved Address
        assertEq(abi.decode(entries[1].data, (uint256)), uint256(bobAllowance)); // Check Amount approved

        // Check third event transfer
        assertEq(entries[2].topics[0], transferEventTopic);
        assertEq(entries[2].topics[1], bytes32(abi.encode(testerContractAddress))); // Check Address approving
        assertEq(entries[2].topics[2], bytes32(abi.encode(mary))); // Check approved Address
        assertEq(abi.decode(entries[2].data, (uint256)), uint256(amountMary)); // Check Amount approved

        // All events:
        // [
        // Deposit (address indexed dst, uint wad)
        //     (
        //         [
        //             0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c,
        //             0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
        //         ],
        //         0x00000000000000000000000000000000000000000000000029a2241af62c0000
        //     ),
        // Approve (address indexed src, address indexed guy, uint wad)
        //     (
        //         [
        //             0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925,
        //             0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496,
        //             0x0000000000000000000000000000000000000000000000000000000000000001
        //         ],
        //         0x0000000000000000000000000000000000000000000000000de0b6b3a7640000
        //     ),
        // Transfer(address indexed src, address indexed dst, uint wad)
        //     (
        //         [
        //             0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
        //             0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496,
        //             0x0000000000000000000000000000000000000000000000000000000000000002
        //         ],
        //     0x00000000000000000000000000000000000000000000000006f05b59d3b20000
        //     )
        // ]
    }
}
