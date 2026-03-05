// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/CrowdFund.sol";

// ========================================================================
// MALICIOUS CONTRACTS (SECURITY TESTING)
// ========================================================================

contract MaliciousBacker {
    CrowdFund public crowdFund;
    
    constructor(address _crowdFund) {
        crowdFund = CrowdFund(_crowdFund);
    }

    function attackContribute() external payable {
        crowdFund.contribute{value: msg.value}();
    }

    function attackRefund() external {
        crowdFund.getRefund();
    }

    // Fallback function để tấn công Reentrancy khi nhận ETH
    receive() external payable {
        if (address(crowdFund).balance >= 1 ether) {
            crowdFund.getRefund();
        }
    }
}

contract MaliciousVendor {
    CrowdFund public crowdFund;
    uint256 public requestId;

    constructor(address _crowdFund) {
        crowdFund = CrowdFund(_crowdFund);
    }

    function setRequestId(uint256 _id) external {
        requestId = _id;
    }

    // Fallback function để tấn công Reentrancy khi nhận ETH giải ngân
    receive() external payable {
        crowdFund.finalizeRequest(requestId);
    }
}

contract RejectingVendor {
    // Fallback function to intentionally reject ETH
    receive() external payable {
        revert("I reject ETH");
    }
}

contract CrowdFundTest is Test {
    CrowdFund public crowdFund;

    address public manager;
    address public backer1;
    address public backer2;
    address public vendor;

    uint256 public constant MIN_CONTRIBUTION = 0.1 ether;

    // Events for vm.expectEmit testing
    event RequestApproved(address indexed voter, uint256 indexed requestId, uint256 weight);
    event ProjectCancelVoted(address indexed voter, uint256 weight);
    event ProjectCancelled(address indexed initiator);

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
        assertEq(crowdFund.totalRaised(), amount);

        // Test Revert: Contribution Too Low
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__ContributionTooLow.selector);
        crowdFund.contribute{value: 0.01 ether}();
    }

    function test_Revert_Contribute_Manager() public {
        // Act & Assert
        vm.deal(manager, 1 ether);
        vm.prank(manager);
        vm.expectRevert(CrowdFund.CrowdFund__ManagerCannotContribute.selector);
        crowdFund.contribute{value: 1 ether}();
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
            bool comp,
            
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
        (,,, uint256 approvalCount,,) = crowdFund.requests(0);
        assertEq(approvalCount, 1 ether);

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

        // Warp past deadline to allow finalization with insufficient votes
        vm.warp(block.timestamp + 7 days + 1);

        vm.prank(manager);
        crowdFund.finalizeRequest(0);

        // Assert: Complete = true, Money not sent, Counter increased
        (,,,, bool complete0,) = crowdFund.requests(0);
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
        (,,,, bool complete1,) = crowdFund.requests(1);
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
        assertEq(crowdFund.cancelVotesWeight(), 1 ether);
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

            // Warp past deadline to allow finalization with insufficient votes
            vm.warp(block.timestamp + 7 days + 1);

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

    // ========================================================================
    // PHẦN 1: TEST TIME-LOCK & SEQUENTIAL LIMIT
    // ========================================================================

    function test_Revert_CreateRequest_SequentialLimit() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(manager); crowdFund.createRequest("Req 0", 0.5 ether, payable(vendor));

        // Act & Assert
        vm.prank(manager);
        vm.expectRevert(CrowdFund.CrowdFund__RequestNotComplete.selector);
        crowdFund.createRequest("Req 1", 0.1 ether, payable(vendor));
    }

    function test_Revert_ApproveRequest_AfterDeadline() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(manager); crowdFund.createRequest("Req 0", 0.5 ether, payable(vendor));

        // Act: Warp past 7 days
        vm.warp(block.timestamp + 7 days + 1);

        // Assert
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__VotingEnded.selector);
        crowdFund.approveRequest(0);
    }

    function test_FinalizeRequest_EarlyFail() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(manager); crowdFund.createRequest("Req 0", 0.5 ether, payable(vendor));

        // Act: Immediate finalize with 0 votes (Early Fail)
        vm.prank(manager);
        crowdFund.finalizeRequest(0);

        // Assert: Request marked complete (failed) and counter increased
        assertEq(crowdFund.consecutiveRejectedRequests(), 1);
    }

    function test_FinalizeRequest_BeforeDeadline_WithEnoughVotes() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 1 ether}();
        vm.prank(manager); crowdFund.createRequest("Req 0", 1 ether, payable(vendor));

        // Act: Both vote (100% approval)
        vm.prank(backer1); crowdFund.approveRequest(0);
        vm.prank(backer2); crowdFund.approveRequest(0);

        uint256 preBalance = vendor.balance;
        vm.prank(manager);
        crowdFund.finalizeRequest(0);

        // Assert
        (,,,, bool complete,) = crowdFund.requests(0);
        assertTrue(complete);
        assertEq(vendor.balance, preBalance + 1 ether);
    }

    function test_FinalizeRequest_AfterDeadline_NotEnoughVotes() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(manager); crowdFund.createRequest("Req 0", 0.5 ether, payable(vendor));

        // Act: Warp past deadline (no votes)
        vm.warp(block.timestamp + 7 days + 1);

        uint256 preBalance = vendor.balance;
        vm.prank(manager);
        crowdFund.finalizeRequest(0);

        // Assert: Request closed but money NOT sent
        (,,,, bool complete,) = crowdFund.requests(0);
        assertTrue(complete);
        assertEq(vendor.balance, preBalance);
        assertEq(crowdFund.consecutiveRejectedRequests(), 1);
    }

    // ========================================================================
    // PHẦN 2: TEST INPUT VALIDATION & EDGE CASES
    // ========================================================================

    function test_Revert_CreateRequest_ZeroAddress() public {
        vm.prank(manager);
        vm.expectRevert(CrowdFund.CrowdFund__ZeroAddress.selector);
        crowdFund.createRequest("Zero Addr", 1 ether, payable(address(0)));
    }

    function test_Revert_CreateRequest_ZeroAmount() public {
        vm.prank(manager);
        vm.expectRevert(CrowdFund.CrowdFund__ZeroAmount.selector);
        crowdFund.createRequest("Zero Amt", 0, payable(vendor));

        // Assert: Request was not added (accessing index 0 should revert)
        vm.expectRevert();
        crowdFund.requests(0);
    }

    function test_Revert_CreateRequest_ProjectFailed() public {
        // Arrange: Fail the project
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer1); crowdFund.voteCancelProject();
        vm.prank(backer2); crowdFund.voteCancelProject();

        // Act & Assert
        vm.prank(manager);
        vm.expectRevert(CrowdFund.CrowdFund__ProjectFailed.selector);
        crowdFund.createRequest("Fail", 1 ether, payable(vendor));
    }

    function test_Revert_ApproveRequest_OutOfBounds() public {
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__InvalidRequest.selector);
        crowdFund.approveRequest(999);
    }

    function test_Revert_ApproveRequest_AlreadyComplete() public {
        // Arrange: Setup và Finalize thủ công (Decoupling)
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 1 ether}();
        vm.prank(manager); crowdFund.createRequest("Req 0", 1 ether, payable(vendor));
        
        vm.prank(backer1); crowdFund.approveRequest(0);
        vm.prank(backer2); crowdFund.approveRequest(0);
        vm.prank(manager); crowdFund.finalizeRequest(0);

        // Act & Assert
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__RequestAlreadyCompleted.selector);
        crowdFund.approveRequest(0);
    }

    function test_Revert_FinalizeRequest_NotManager() public {
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(manager); crowdFund.createRequest("Req 0", 0.5 ether, payable(vendor));

        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__NotManager.selector);
        crowdFund.finalizeRequest(0);
    }

    function test_Revert_FinalizeRequest_DoubleFinalize() public {
        // Arrange: Setup và Finalize lần 1 (Decoupling)
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 1 ether}();
        vm.prank(manager); crowdFund.createRequest("Req 0", 1 ether, payable(vendor));
        
        vm.prank(backer1); crowdFund.approveRequest(0);
        vm.prank(backer2); crowdFund.approveRequest(0);
        vm.prank(manager); crowdFund.finalizeRequest(0);

        // Act & Assert
        vm.prank(manager);
        vm.expectRevert(CrowdFund.CrowdFund__RequestAlreadyCompleted.selector);
        crowdFund.finalizeRequest(0);
    }

    function test_Revert_FinalizeRequest_ProjectFailed() public {
        // Arrange: Create request then fail project
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 1 ether}();
        vm.prank(manager); crowdFund.createRequest("Req 0", 0.5 ether, payable(vendor));

        vm.prank(backer1); crowdFund.voteCancelProject();
        vm.prank(backer2); crowdFund.voteCancelProject(); // Project Failed

        // Act & Assert
        vm.prank(manager);
        vm.expectRevert(CrowdFund.CrowdFund__ProjectAlreadyFailed.selector);
        crowdFund.finalizeRequest(0);
    }

    function test_Revert_Contribute_ProjectFailed() public {
        // Arrange: Fail project
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer1); crowdFund.voteCancelProject();
        vm.prank(backer2); crowdFund.voteCancelProject();

        // Act & Assert
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__ProjectFailed.selector);
        crowdFund.contribute{value: 1 ether}();
    }

    // ========================================================================
    // PHẦN 3: SECURITY & FUZZ TESTING (NEW)
    // ========================================================================

    function testFuzz_Contribute(uint256 amount) public {
        // Arrange: Giới hạn amount hợp lệ
        amount = bound(amount, MIN_CONTRIBUTION, 100_000 ether);
        vm.deal(backer1, amount);

        // Act
        vm.prank(backer1);
        crowdFund.contribute{value: amount}();

        // Assert
        assertEq(crowdFund.contributions(backer1), amount);
        assertEq(crowdFund.totalRaised(), amount);
    }

    function testFuzz_Revert_CreateRequest_AmountExceedsRaised(uint256 requestAmount) public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 1 ether}();
        // Total raised = 2 ether

        // Act & Assert
        requestAmount = bound(requestAmount, 2 ether + 1, type(uint128).max);
        vm.prank(manager);
        vm.expectRevert(CrowdFund.CrowdFund__InvalidRequestAmount.selector);
        crowdFund.createRequest("Excess", requestAmount, payable(vendor));
    }

    function testFuzz_Revert_ApproveRequest_OutOfBounds(uint256 randomRequestId) public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(manager); crowdFund.createRequest("Req 0", 0.5 ether, payable(vendor));

        // Act & Assert
        randomRequestId = bound(randomRequestId, 1, type(uint256).max);
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__InvalidRequest.selector);
        crowdFund.approveRequest(randomRequestId);
    }

    function test_Revert_CreateRequest_EmptyDescription() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();

        // Act & Assert
        vm.prank(manager);
        vm.expectRevert(CrowdFund.CrowdFund__EmptyDescription.selector);
        crowdFund.createRequest("", 0.5 ether, payable(vendor));
    }

    function test_Revert_Reentrancy_GetRefund() public {
        // Arrange
        MaliciousBacker attacker = new MaliciousBacker(address(crowdFund));
        
        attacker.attackContribute{value: 1 ether}();
        
        // Làm dự án thất bại
        vm.prank(backer2); crowdFund.contribute{value: 1 ether}();
        vm.prank(address(attacker)); crowdFund.voteCancelProject();
        vm.prank(backer2); crowdFund.voteCancelProject();
        assertTrue(crowdFund.projectFailed());

        // Act & Assert: Mong đợi Revert khi cố gắng Re-enter
        vm.expectRevert(CrowdFund.CrowdFund__RefundTransferFailed.selector);
        attacker.attackRefund();
        
        // Fix: Revert rolls back state, so attacker balance returns to 0 (initial 1 ETH was spent)
        assertEq(address(attacker).balance, 0 ether);
    }

    function test_Revert_Reentrancy_FinalizeRequest() public {
        // Arrange
        MaliciousVendor maliciousVendor = new MaliciousVendor(address(crowdFund));
        
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 1 ether}();
        
        vm.prank(manager);
        crowdFund.createRequest("Trap", 1 ether, payable(address(maliciousVendor)));
        maliciousVendor.setRequestId(0);
        
        vm.prank(backer1); crowdFund.approveRequest(0);
        vm.prank(backer2); crowdFund.approveRequest(0);
        
        // Act & Assert
        vm.prank(manager);
        crowdFund.finalizeRequest(0);

        assertEq(address(maliciousVendor).balance, 0 ether);
        (,,,, bool complete,) = crowdFund.requests(0);
        assertTrue(complete);
        assertEq(crowdFund.consecutiveRejectedRequests(), 1);
    }

    function test_Revert_VoteCancelProject_NotContributor() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();

        // Act & Assert
        address random = makeAddr("random");
        vm.prank(random);
        vm.expectRevert(CrowdFund.CrowdFund__NotContributor.selector);
        crowdFund.voteCancelProject();
    }

    function test_Revert_ApproveRequest_ProjectFailed() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 1 ether}();
        vm.prank(manager); crowdFund.createRequest("Req", 1 ether, payable(vendor));

        // Trigger failure
        vm.prank(backer1); crowdFund.voteCancelProject();
        vm.prank(backer2); crowdFund.voteCancelProject();

        // Act & Assert
        vm.prank(backer1);
        vm.expectRevert(CrowdFund.CrowdFund__ProjectFailed.selector);
        crowdFund.approveRequest(0);
    }

    function test_Revert_GetRefund_NotContributor_CleanSlate() public {
        // Arrange
        vm.prank(backer1); crowdFund.contribute{value: 1 ether}();
        vm.prank(backer1); crowdFund.voteCancelProject();

        // Act & Assert
        address thief = makeAddr("thief");
        vm.prank(thief);
        vm.expectRevert(CrowdFund.CrowdFund__NotContributor.selector);
        crowdFund.getRefund();
    }

    function test_Vulnerability_SybilApproverInflation() public {
        // Arrange: Deploy a fresh instance of CrowdFund with minimumContribution = 0
        
        // Act & Assert: Expect Revert because _minimum cannot be 0
        vm.expectRevert(CrowdFund.CrowdFund__ZeroAmount.selector);
        new CrowdFund(0);
    }

    function testFuzz_GetRefund_MathAccuracy(uint256 contrib1, uint256 contrib2, uint256 spendAmount) public {
        // Arrange
        contrib1 = bound(contrib1, MIN_CONTRIBUTION, 10_000 ether);
        contrib2 = bound(contrib2, MIN_CONTRIBUTION, 10_000 ether);
        uint256 totalRaised = contrib1 + contrib2;

        // Constrain spendAmount to be between 1 and contrib1 + contrib2 - 1
        spendAmount = bound(spendAmount, 1, totalRaised - 1);

        vm.deal(backer1, contrib1);
        vm.deal(backer2, contrib2);

        vm.prank(backer1); crowdFund.contribute{value: contrib1}();
        vm.prank(backer2); crowdFund.contribute{value: contrib2}();

        vm.prank(manager); crowdFund.createRequest("Spend", spendAmount, payable(vendor));
        vm.prank(backer1); crowdFund.approveRequest(0);
        vm.prank(backer2); crowdFund.approveRequest(0);
        vm.prank(manager); crowdFund.finalizeRequest(0);

        vm.prank(backer1); crowdFund.voteCancelProject();
        if (!crowdFund.projectFailed()) {
            vm.prank(backer2); crowdFund.voteCancelProject();
        }

        uint256 contractBalance = address(crowdFund).balance;

        // Act
        uint256 preBalance = backer1.balance;
        vm.prank(backer1);
        crowdFund.getRefund();
        uint256 postBalance = backer1.balance;

        // Assert
        uint256 expectedRefund = (contrib1 * contractBalance) / totalRaised;
        assertEq(postBalance - preBalance, expectedRefund);
    }

    // ========================================================================
    // AUDIT FIXES & SECURITY TESTS
    // ========================================================================

    function test_VulnerabilityFix_ContributeTriggersFail() public {
        vm.prank(backer1); crowdFund.contribute{value: 2 ether}();
        vm.prank(backer2); crowdFund.contribute{value: 5 ether}();
        
        vm.prank(backer1); 
        crowdFund.voteCancelProject();
        assertFalse(crowdFund.projectFailed());

        // Backer 1 adds more funds, crossing the 50% cancel threshold
        vm.deal(backer1, 6 ether);
        vm.prank(backer1);
        crowdFund.contribute{value: 6 ether}();

        // The project MUST fail immediately inside the contribute function
        assertTrue(crowdFund.projectFailed());
        assertEq(crowdFund.lockedRefundPool(), 13 ether);
    }

    function test_VulnerabilityFix_TransferFailIncrementsCounter() public {
        RejectingVendor rejectingVendor = new RejectingVendor();
        vm.prank(backer1); crowdFund.contribute{value: 2 ether}();
        
        vm.prank(manager);
        crowdFund.createRequest("Buy from bad vendor", 1 ether, payable(address(rejectingVendor)));
        
        vm.prank(backer1); 
        crowdFund.approveRequest(0);

        uint256 initialCounter = crowdFund.consecutiveRejectedRequests();

        vm.prank(manager);
        crowdFund.finalizeRequest(0); // This will fail internally due to RejectingVendor

        // The counter MUST increment, not reset
        assertEq(crowdFund.consecutiveRejectedRequests(), initialCounter + 1);
        
        (,,,, bool complete,) = crowdFund.requests(0);
        assertTrue(complete);
        assertEq(address(rejectingVendor).balance, 0);
    }

    function test_GovernanceEventsEmitted() public {
        vm.prank(backer1); crowdFund.contribute{value: 2 ether}();
        vm.prank(manager); crowdFund.createRequest("Event Test", 1 ether, payable(vendor));

        // Expect RequestApproved
        vm.expectEmit(true, true, false, true);
        emit RequestApproved(backer1, 0, 2 ether); 
        
        vm.prank(backer1);
        crowdFund.approveRequest(0);

        // Expect ProjectCancelVoted
        vm.expectEmit(true, false, false, true);
        emit ProjectCancelVoted(backer1, 2 ether); 

        vm.prank(backer1);
        crowdFund.voteCancelProject();
    }
}
