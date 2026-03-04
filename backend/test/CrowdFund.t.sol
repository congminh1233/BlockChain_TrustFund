// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/CrowdFund.sol";

contract CrowdFundTest is Test {
    CrowdFund public crowdFund;

    address public manager;
    address public backer1;
    address public backer2;
    address public vendor;

    uint256 public constant MIN_CONTRIBUTION = 0.1 ether;

    // 1. SETUP
    function setUp() public {
        manager = makeAddr("manager");
        backer1 = makeAddr("backer1");
        backer2 = makeAddr("backer2");
        vendor = makeAddr("vendor");

        vm.deal(backer1, 10 ether);
        vm.deal(backer2, 10 ether);

        vm.prank(manager);
        crowdFund = new CrowdFund(MIN_CONTRIBUTION);
    }

    // 2. TEST NẠP TIỀN
    function test_Contribute() public {
        // Arrange
        uint256 amount = 1 ether;

        // Act
        vm.prank(backer1);
        crowdFund.contribute{value: amount}();

        // Assert
        assertEq(crowdFund.contributions(backer1), amount);
        assertEq(crowdFund.approversCount(), 1);
        assertEq(crowdFund.totalRaised(), amount);

        // Test Revert: Contribution Too Low
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__ContributionTooLow.selector);
        crowdFund.contribute{value: 0.01 ether}();
    }

    // 3. TEST TẠO REQUEST
    function test_CreateRequest() public {
        // Arrange
        vm.prank(backer1);
        crowdFund.contribute{value: 1 ether}();

        // Act
        vm.prank(manager);
        crowdFund.createRequest("Buy Servers", 0.5 ether, payable(vendor));

        // Assert
        (
            string memory desc,
            uint256 amt,
            address rec,
            uint256 appCount,
            bool comp
        ) = crowdFund.requests(0);

        assertEq(desc, "Buy Servers");
        assertEq(amt, 0.5 ether);
        assertEq(rec, vendor);
        assertEq(appCount, 0);
        assertFalse(comp);

        // Test Revert: Not Manager
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__NotManager.selector);
        crowdFund.createRequest("Scam", 0.1 ether, payable(backer1));

        // Test Revert: Amount > TotalRaised
        vm.prank(manager);
        vm.expectRevert(CrowdFund.CrowdFund__InvalidRequestAmount.selector);
        crowdFund.createRequest("Too Much", 2 ether, payable(vendor));
    }

    // 4. TEST BỎ PHIẾU
    function test_ApproveRequest() public {
        // Arrange
        vm.prank(backer1);
        crowdFund.contribute{value: 1 ether}();
        vm.prank(manager);
        crowdFund.createRequest("Marketing", 0.5 ether, payable(vendor));

        // Act
        vm.prank(backer1);
        crowdFund.approveRequest(0);

        // Assert
        (,,, uint256 approvalCount,) = crowdFund.requests(0);
        assertEq(approvalCount, 1);

        // Test Revert: Double Vote
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__AlreadyVoted.selector);
        crowdFund.approveRequest(0);

        // Test Revert: Not Contributor
        vm.prank(backer2);
        vm.expectRevert(CrowdFund.CrowdFund__NotContributor.selector);
        crowdFund.approveRequest(0);
    }

    // 5. TEST GIẢI NGÂN (FINALIZE)
    function test_FinalizeRequest() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 1 ether}();
        // Total approvers = 2. Threshold > 1.

        // --- Scenario 1: Failure (Passive Cancel Logic) ---
        vm.prank(manager);
        crowdFund.createRequest("Fail Request", 1 ether, payable(vendor)); // Index 0

        // Only 1 vote (50% <= 50%)
        vm.prank(backer1);
        crowdFund.approveRequest(0);

        uint256 initialVendorBalance = vendor.balance;

        vm.prank(manager);
        crowdFund.finalizeRequest(0);

        // Assert: Complete = true, Money not sent, Counter increased
        (,,,, bool complete0) = crowdFund.requests(0);
        assertTrue(complete0);
        assertEq(vendor.balance, initialVendorBalance);
        assertEq(crowdFund.consecutiveRejectedRequests(), 1);

        // --- Scenario 2: Success ---
        vm.prank(manager);
        crowdFund.createRequest("Success Request", 1 ether, payable(vendor)); // Index 1

        // 2 votes (100% > 50%)
        vm.prank(backer1); crowdFund.approveRequest(1);
        vm.prank(backer2); crowdFund.approveRequest(1);

        vm.prank(manager);
        crowdFund.finalizeRequest(1);

        // Assert: Complete = true, Money sent, Counter reset
        (,,,, bool complete1) = crowdFund.requests(1);
        assertTrue(complete1);
        assertEq(vendor.balance, initialVendorBalance + 1 ether);
        assertEq(crowdFund.consecutiveRejectedRequests(), 0);
    }

    // 6. TEST CHỦ ĐỘNG HỦY DỰ ÁN (ACTIVE CANCEL)
    function test_ActiveCancel_VoteCancelProject() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 1 ether}();

        // Act 1: Backer1 votes cancel
        vm.prank(backer1);
        crowdFund.voteCancelProject();

        // Assert 1
        assertEq(crowdFund.cancelVotesCount(), 1);
        assertFalse(crowdFund.projectFailed());

        // Test Revert: Double Vote
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__AlreadyVoted.selector);
        crowdFund.voteCancelProject();

        // Act 2: Backer2 votes cancel
        vm.prank(backer2);
        crowdFund.voteCancelProject();

        // Assert 2
        assertTrue(crowdFund.projectFailed());
    }

    // 7. TEST BỊ ĐỘNG HỦY DỰ ÁN (PASSIVE CANCEL - 4 FAILURES)
    function test_PassiveCancel_ConsecutiveFailures() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();

        // Act & Assert Loop
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(manager);
            crowdFund.createRequest("Spam", 0.1 ether, payable(vendor));

            // Finalize immediately (0 votes)
            vm.prank(manager);
            crowdFund.finalizeRequest(i);

            if (i < 3) {
                assertFalse(crowdFund.projectFailed());
                assertEq(crowdFund.consecutiveRejectedRequests(), i + 1);
            } else {
                assertTrue(crowdFund.projectFailed());
            }
        }
    }

    // 8. TEST TOÁN HỌC HOÀN TIỀN (REFUND MATH)
    function test_GetRefund_MathAccuracy() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 10 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 10 ether}();
        // Total Raised: 20E

        // Spend 4E
        vm.prank(manager); crowdFund.createRequest("Legit", 4 ether, payable(vendor));
        vm.prank(backer1); crowdFund.approveRequest(0);
        vm.prank(backer2); crowdFund.approveRequest(0);
        vm.prank(manager); crowdFund.finalizeRequest(0);
        // Balance: 16E

        // Trigger Fail
        vm.prank(backer1); crowdFund.voteCancelProject();
        vm.prank(backer2); crowdFund.voteCancelProject();
        assertTrue(crowdFund.projectFailed());

        // Act
        uint256 preBalance = backer1.balance;
        vm.prank(backer1);
        crowdFund.getRefund();
        uint256 postBalance = backer1.balance;

        // Assert: (10 / 20) * 16 = 8 Ether
        assertEq(postBalance - preBalance, 8 ether);
        assertEq(crowdFund.contributions(backer1), 0);
    }

    // 9. TEST CHỐNG RÚT TIỀN KÉP (DOUBLE REFUND)
    function test_Revert_DoubleRefund() public {
        // Arrange: Trigger fail first
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer1); crowdFund.voteCancelProject();
        assertTrue(crowdFund.projectFailed());

        // Act 1: First Refund
        vm.prank(backer1);
        crowdFund.getRefund();

        // Act 2: Double Refund
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__NotContributor.selector);
        crowdFund.getRefund();
    }

    // 10. TEST REVERT EARLY REFUND
    function test_Revert_EarlyRefund() public {
        // Arrange
        vm.prank(backer1);
        crowdFund.contribute{value: 1 ether}();

        assertFalse(crowdFund.projectFailed());

        // Act & Assert
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__ProjectNotFailed.selector);
        crowdFund.getRefund();
    }
}
