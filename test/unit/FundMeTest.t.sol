// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    DeployFundMe deployFundMe;

    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STRATING_BALANCE = 10 ether;
    address USER = makeAddr("test");

    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STRATING_BALANCE);
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        // console.log(msg.sender); 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        // console.log(address(fundMe)); 0x90193C961A926261B756D1E5bb255e67ff9498A1
        // console.log(address(deployFundMe)); 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        // console.log(address(fundMe.i_owner())); 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert();
        fundMe.fund(); // send 0 value
    }

    function testFundUpdatesFundedDatastructure() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFund(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0); //每次运行一个测试函数前都会运行一次setup函数，所以前面调用了fund函数这里仍然使用索引为0
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER); // cheatcode会自动跳过vm（下一行），应用到fundMe.withdraw()
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        //Arrange
        uint256 staringOwnerBalance = fundMe.getOwner().balance;
        uint256 staringFundBalance = address(fundMe).balance;

        //Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        //Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundBalance = address(fundMe).balance;
        assertEq(endingOwnerBalance, staringOwnerBalance + staringFundBalance);
        assertEq(endingFundBalance, 0);
    }

    function testWithdrawWithMutilpleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 staringOwnerBalance = fundMe.getOwner().balance;
        uint256 staringFundBalance = address(fundMe).balance;

        // uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.startPrank(fundMe.getOwner()); // start stop之间可以将prank应用多行代码
        fundMe.withdraw(); //使用本地anvil链进行开发，无论是否分叉，gas价格默认设置为0，所以这里的withdraw并没有消耗gas费，下面的fundMe.getOwner().balance = staringOwnerBalance + staringFundBalance才成立
        vm.stopPrank();
        // uint256 gasEnd = gasleft();
        // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        // console.log(gasUsed);

        assertEq(address(fundMe).balance, 0);
        assertEq(
            fundMe.getOwner().balance,
            staringOwnerBalance + staringFundBalance
        );
    }

    function testWithdrawWithMutilpleFundersCheaper() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 staringOwnerBalance = fundMe.getOwner().balance;
        uint256 staringFundBalance = address(fundMe).balance;

        // uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.startPrank(fundMe.getOwner()); // start stop之间可以将prank应用多行代码
        fundMe.cheaperWithdraw(); //使用本地anvil链进行开发，无论是否分叉，gas价格默认设置为0，所以这里的withdraw并没有消耗gas费，下面的fundMe.getOwner().balance = staringOwnerBalance + staringFundBalance才成立
        vm.stopPrank();
        // uint256 gasEnd = gasleft();
        // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        // console.log(gasUsed);

        assertEq(address(fundMe).balance, 0);
        assertEq(
            fundMe.getOwner().balance,
            staringOwnerBalance + staringFundBalance
        );
    }
}
