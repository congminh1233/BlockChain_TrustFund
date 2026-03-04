// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title TRUSTFUND - Decentralized Milestone-based Crowdfunding
 * @author Gemini Code Assist
 * @notice Contract quản lý gọi vốn cộng đồng với cơ chế bảo vệ nhà đầu tư (Anti-Scam).
 */
contract CrowdFund {
    //--------------------------------------------------------------------
    // 1. STRUCTS
    //--------------------------------------------------------------------
    
    struct Request {
        string description;     // Mô tả mục đích sử dụng vốn
        uint256 amount;         // Số tiền muốn rút (Wei)
        address recipient;      // Địa chỉ nhận tiền (Vendor/Supplier)
        uint256 approvalCount;  // Số lượng phiếu thuận
        bool complete;          // Trạng thái đã hoàn thành (đã rút tiền) chưa
        mapping(address => bool) voters; // Theo dõi ai đã vote cho request này
    }

    //--------------------------------------------------------------------
    // 2. STATE VARIABLES
    //--------------------------------------------------------------------

    address public immutable manager;                 // Người tạo dự án
    uint256 public immutable minimumContribution;     // Số tiền nạp tối thiểu
    uint256 public totalRaised;             // Tổng số ETH đã huy động được
    uint256 public approversCount;          // Tổng số lượng Backer (Unique addresses)
    
    // Biến trạng thái cho logic Anti-Scam
    bool public projectFailed;              // Trạng thái dự án (True = Thất bại -> Mở Refund)
    uint256 public consecutiveRejectedRequests; // Đếm số lần Request bị từ chối liên tiếp
    mapping(address => bool) public cancelVoters; // Đánh dấu ai đã vote hủy
    uint256 public cancelVotesCount;        // Tổng số phiếu đòi hủy dự án

    //--------------------------------------------------------------------
    // 3. MAPPINGS & ARRAYS
    //--------------------------------------------------------------------

    // Lưu trữ số tiền đóng góp của từng Backer
    mapping(address => uint256) public contributions;
    
    // Danh sách các yêu cầu giải ngân (Requests)
    // Lưu ý: Do struct Request chứa mapping, getter tự động của Solidity sẽ bỏ qua field 'voters'
    Request[] public requests;

    //--------------------------------------------------------------------
    // 4. EVENTS
    //--------------------------------------------------------------------

    event ContributeEvent(address indexed backer, uint256 amount, uint256 totalContributed);
    event RequestCreatedEvent(uint256 indexed requestId, string description, uint256 amount, address recipient);
    event ProjectCancelled(address indexed initiator);
    event RefundIssued(address indexed backer, uint256 amount);

    //--------------------------------------------------------------------
    // 5. CUSTOM ERRORS (Gas Optimization)
    //--------------------------------------------------------------------

    error CrowdFund__NotManager();
    error CrowdFund__ContributionTooLow();
    error CrowdFund__NotContributor();
    error CrowdFund__AlreadyVoted();
    error CrowdFund__RequestAlreadyCompleted();
    error CrowdFund__NotEnoughVotes();
    error CrowdFund__TransferFailed();
    error CrowdFund__InvalidRequestAmount();
    error CrowdFund__InsufficientContractBalance();
    error CrowdFund__ProjectAlreadyFailed();
    error CrowdFund__ProjectNotFailed();
    error CrowdFund__RefundTransferFailed();

    //--------------------------------------------------------------------
    // 6. MODIFIERS
    //--------------------------------------------------------------------

    modifier onlyManager() {
        if (msg.sender != manager) {
            revert CrowdFund__NotManager();
        }
        _;
    }

    //--------------------------------------------------------------------
    // 7. FUNCTIONS
    //--------------------------------------------------------------------

    /**
     * @notice Khởi tạo dự án
     * @param _minimum Số tiền tối thiểu (Wei) để trở thành Backer
     */
    constructor(uint256 _minimum) {
        manager = msg.sender;
        minimumContribution = _minimum;
        // Các biến khác mặc định là 0 hoặc false theo default của Solidity
    }

    /**
     * @notice Hàm cho phép Backer nạp tiền vào dự án
     * @dev Cập nhật totalRaised và approversCount (nếu là người mới)
     */
    function contribute() public payable {
        // Kiểm tra số tiền nạp tối thiểu
        if (msg.value < minimumContribution) {
            revert CrowdFund__ContributionTooLow();
        }

        // Nếu đây là lần đầu tiên địa chỉ này nạp tiền, tăng số lượng approvers
        if (contributions[msg.sender] == 0) {
            approversCount++;
        }

        // Cập nhật số tiền đóng góp của người dùng
        contributions[msg.sender] += msg.value;
        
        // Cập nhật tổng số tiền huy động được của cả dự án
        totalRaised += msg.value;

        emit ContributeEvent(msg.sender, msg.value, contributions[msg.sender]);
    }

    /**
     * @notice Manager tạo yêu cầu rút tiền (Request)
     * @param _description Mô tả mục đích
     * @param _amount Số tiền cần rút
     * @param _recipient Địa chỉ nhận tiền
     */
    function createRequest(string calldata _description, uint256 _amount, address payable _recipient) public onlyManager {
        if (_amount == 0 || _amount > totalRaised) revert CrowdFund__InvalidRequestAmount();

        Request storage newRequest = requests.push();
        newRequest.description = _description;
        newRequest.amount = _amount;
        newRequest.recipient = _recipient;
        newRequest.approvalCount = 0;
        newRequest.complete = false;

        emit RequestCreatedEvent(requests.length - 1, _description, _amount, _recipient);
    }

    /**
     * @notice Backer bỏ phiếu chấp thuận cho Request
     * @param _index Chỉ số của Request trong mảng
     */
    function approveRequest(uint256 _index) public {
        Request storage request = requests[_index];

        if (request.complete) revert CrowdFund__RequestAlreadyCompleted();
        if (contributions[msg.sender] == 0) revert CrowdFund__NotContributor();
        if (request.voters[msg.sender]) revert CrowdFund__AlreadyVoted();

        request.voters[msg.sender] = true;
        request.approvalCount++;
    }

    /**
     * @notice Manager hoàn tất Request và rút tiền nếu đủ phiếu bầu
     * @param _index Chỉ số của Request
     */
    function finalizeRequest(uint256 _index) public onlyManager {
        Request storage request = requests[_index];

        if (projectFailed) revert CrowdFund__ProjectAlreadyFailed();
        if (request.complete) revert CrowdFund__RequestAlreadyCompleted();
        
        // Logic mới: Không revert nếu thiếu phiếu, mà xử lý theo nhánh If-Else
        if (request.approvalCount > approversCount / 2) {
            // --- TRƯỜNG HỢP THÀNH CÔNG ---
            if (address(this).balance < request.amount) revert CrowdFund__InsufficientContractBalance();

            // Effects
            request.complete = true;
            consecutiveRejectedRequests = 0; // Reset bộ đếm

            // Interactions
            (bool success, ) = request.recipient.call{value: request.amount}("");
            if (!success) revert CrowdFund__TransferFailed();
        } else {
            // --- TRƯỜNG HỢP THẤT BẠI (Bị Backer từ chối) ---
            request.complete = true; // Đóng request này lại
            consecutiveRejectedRequests++; // Tăng bộ đếm thất bại

            // Kiểm tra điều kiện Anti-Scam bị động
            if (consecutiveRejectedRequests >= 4) {
                projectFailed = true;
                emit ProjectCancelled(msg.sender);
            }
        }
    }

    /**
     * @notice Backer bỏ phiếu hủy dự án (Active Anti-Scam)
     */
    function voteCancelProject() public {
        if (projectFailed) revert CrowdFund__ProjectAlreadyFailed();
        if (contributions[msg.sender] == 0) revert CrowdFund__NotContributor();
        if (cancelVoters[msg.sender]) revert CrowdFund__AlreadyVoted();

        cancelVoters[msg.sender] = true;
        cancelVotesCount++;

        if (cancelVotesCount > approversCount / 2) {
            projectFailed = true;
            emit ProjectCancelled(msg.sender);
        }
    }

    /**
     * @notice Rút lại tiền khi dự án thất bại (Refund)
     */
    function getRefund() public {
        if (!projectFailed) revert CrowdFund__ProjectNotFailed();
        if (contributions[msg.sender] == 0) revert CrowdFund__NotContributor();

        // Tính toán số tiền hoàn lại dựa trên tỷ lệ đóng góp và số dư hiện tại
        // Công thức: (Tiền đã nạp * Số dư contract còn lại) / Tổng tiền đã huy động
        uint256 refundAmount = (contributions[msg.sender] * address(this).balance) / totalRaised;

        // Effects: Reset số dư đóng góp về 0 để tránh Reentrancy
        contributions[msg.sender] = 0;

        // Interactions
        (bool success, ) = msg.sender.call{value: refundAmount}("");
        if (!success) revert CrowdFund__RefundTransferFailed();

        emit RefundIssued(msg.sender, refundAmount);
    }
}
