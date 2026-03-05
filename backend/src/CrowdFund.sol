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
        uint256 approvalWeight; // Số lượng phiếu thuận (theo tỷ trọng đóng góp)
        bool complete;          // Trạng thái đã hoàn thành (đã rút tiền) chưa
        uint256 deadline;       // Thời hạn kết thúc bỏ phiếu (Timestamp)
        mapping(address => bool) voters; // Theo dõi ai đã vote cho request này
    }

    //--------------------------------------------------------------------
    // 2. STATE VARIABLES
    //--------------------------------------------------------------------

    address public immutable manager;                 // Người tạo dự án
    uint256 public immutable minimumContribution;     // Số tiền nạp tối thiểu
    uint256 public totalRaised;             // Tổng số ETH đã huy động được
    
    // Biến trạng thái cho logic Anti-Scam
    bool public projectFailed;              // Trạng thái dự án (True = Thất bại -> Mở Refund)
    uint256 public consecutiveRejectedRequests; // Đếm số lần Request bị từ chối liên tiếp
    mapping(address => bool) public cancelVoters; // Đánh dấu ai đã vote hủy
    uint256 public cancelVotesWeight;       // Tổng số phiếu đòi hủy dự án (theo tỷ trọng)
    uint256 public lockedRefundPool;        // Số dư bị khóa tại thời điểm dự án fail

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
    event RequestCreatedEvent(uint256 indexed requestId, string description, uint256 amount, address recipient, uint256 deadline);
    event ProjectCancelled(address indexed initiator);
    event RefundIssued(address indexed backer, uint256 amount);
    event RequestApproved(address indexed voter, uint256 indexed requestId, uint256 weight);
    event ProjectCancelVoted(address indexed voter, uint256 weight);

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
    error CrowdFund__EmptyDescription();
    error CrowdFund__InvalidRequest();
    error CrowdFund__ProjectFailed();
    error CrowdFund__RequestNotComplete();
    error CrowdFund__VotingEnded();
    error CrowdFund__CannotFinalizeYet();
    error CrowdFund__ZeroAddress();
    error CrowdFund__ZeroAmount();
    error CrowdFund__ManagerCannotContribute();

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
        if (_minimum == 0) revert CrowdFund__ZeroAmount();
        manager = msg.sender;
        minimumContribution = _minimum;
        // Các biến khác mặc định là 0 hoặc false theo default của Solidity
    }

    /**
     * @notice Hàm cho phép Backer nạp tiền vào dự án
     * @dev Cập nhật totalRaised và approversCount (nếu là người mới)
     */
    function contribute() public payable {
        if (msg.sender == manager) revert CrowdFund__ManagerCannotContribute();
        if (msg.value == 0) revert CrowdFund__ZeroAmount();
        // Kiểm tra số tiền nạp tối thiểu
        if (msg.value < minimumContribution) {
            revert CrowdFund__ContributionTooLow();
        }
        if (projectFailed) revert CrowdFund__ProjectFailed();

        // Cập nhật số tiền đóng góp của người dùng
        contributions[msg.sender] += msg.value;
        
        if (cancelVoters[msg.sender]) {
            cancelVotesWeight += msg.value;
        }
        
        uint256 reqsLen = requests.length;
        if (reqsLen > 0) {
            uint256 lastIndex = reqsLen - 1;
            if (!requests[lastIndex].complete && requests[lastIndex].voters[msg.sender]) {
                requests[lastIndex].approvalWeight += msg.value;
            }
        }
        
        // Cập nhật tổng số tiền huy động được của cả dự án
        totalRaised += msg.value;

        emit ContributeEvent(msg.sender, msg.value, contributions[msg.sender]);

        if (cancelVotesWeight > totalRaised / 2) {
            projectFailed = true;
            lockedRefundPool = address(this).balance;
            emit ProjectCancelled(msg.sender);
        }
    }

    /**
     * @notice Manager tạo yêu cầu rút tiền (Request)
     * @param _description Mô tả mục đích
     * @param _amount Số tiền cần rút
     * @param _recipient Địa chỉ nhận tiền
     */
    function createRequest(string calldata _description, uint256 _amount, address payable _recipient) public onlyManager {
        if (_recipient == address(0)) revert CrowdFund__ZeroAddress();
        if (_amount == 0) revert CrowdFund__ZeroAmount();
        if (_amount > address(this).balance) revert CrowdFund__InvalidRequestAmount();
        if (projectFailed) revert CrowdFund__ProjectFailed();
        if (bytes(_description).length == 0) revert CrowdFund__EmptyDescription();

        // V2: Chỉ cho phép 1 Request Active. Request trước đó phải hoàn thành (complete == true).
        if (requests.length > 0) {
            Request storage lastRequest = requests[requests.length - 1];
            if (!lastRequest.complete) revert CrowdFund__RequestNotComplete();
        }

        Request storage newRequest = requests.push();
        newRequest.description = _description;
        newRequest.amount = _amount;
        newRequest.recipient = _recipient;
        newRequest.approvalWeight = 0;
        newRequest.complete = false;
        
        // V2: Gán deadline là 7 ngày kể từ lúc tạo
        newRequest.deadline = block.timestamp + 7 days;

        emit RequestCreatedEvent(requests.length - 1, _description, _amount, _recipient, newRequest.deadline);
    }

    /**
     * @notice Backer bỏ phiếu chấp thuận cho Request
     * @param _index Chỉ số của Request trong mảng
     */
    function approveRequest(uint256 _index) public {
        if (projectFailed) revert CrowdFund__ProjectFailed();
        if (_index >= requests.length) revert CrowdFund__InvalidRequest();
        Request storage request = requests[_index];

        if (request.complete) revert CrowdFund__RequestAlreadyCompleted();
        if (contributions[msg.sender] == 0) revert CrowdFund__NotContributor();
        if (request.voters[msg.sender]) revert CrowdFund__AlreadyVoted();
        
        // V2: Kiểm tra thời hạn Voting
        if (block.timestamp >= request.deadline) revert CrowdFund__VotingEnded();

        request.voters[msg.sender] = true;
        request.approvalWeight += contributions[msg.sender];

        emit RequestApproved(msg.sender, _index, contributions[msg.sender]);
    }

    /**
     * @notice Manager hoàn tất Request và rút tiền nếu đủ phiếu bầu
     * @param _index Chỉ số của Request
     */
    function finalizeRequest(uint256 _index) public onlyManager {
        Request storage request = requests[_index];

        if (projectFailed) revert CrowdFund__ProjectAlreadyFailed();
        if (request.complete) revert CrowdFund__RequestAlreadyCompleted();
        
        // V2 Logic:
        // Điều kiện 1: Đủ phiếu quá bán (> 50%) -> Có thể finalize sớm.
        // Điều kiện 2: Hết thời gian (deadline) -> Buộc phải finalize để chốt kết quả (đậu hoặc rớt).
        bool hasEnoughVotes = request.approvalWeight > totalRaised / 2;

        if (hasEnoughVotes) {
            // --- TRƯỜNG HỢP THÀNH CÔNG ---
            if (address(this).balance < request.amount) revert CrowdFund__InsufficientContractBalance();

            // Effects
            request.complete = true;

            // Interactions
            (bool success, ) = request.recipient.call{value: request.amount}("");
            
            if (success) {
                consecutiveRejectedRequests = 0;
            } else {
                consecutiveRejectedRequests++;
                if (consecutiveRejectedRequests >= 4) {
                    projectFailed = true;
                    lockedRefundPool = address(this).balance;
                    emit ProjectCancelled(msg.sender);
                }
            }
        } else {
            // --- TRƯỜNG HỢP THẤT BẠI (Hết giờ mà không đủ phiếu) ---
            request.complete = true; // Đóng request này lại
            consecutiveRejectedRequests++; // Tăng bộ đếm thất bại

            // Kiểm tra điều kiện Anti-Scam bị động
            if (consecutiveRejectedRequests >= 4) {
                projectFailed = true;
                lockedRefundPool = address(this).balance;
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
        cancelVotesWeight += contributions[msg.sender];

        emit ProjectCancelVoted(msg.sender, contributions[msg.sender]);

        if (cancelVotesWeight > totalRaised / 2) {
            projectFailed = true;
            lockedRefundPool = address(this).balance;
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
        uint256 refundAmount = (contributions[msg.sender] * lockedRefundPool) / totalRaised;

        // Effects: Reset số dư đóng góp về 0 để tránh Reentrancy
        contributions[msg.sender] = 0;

        // Interactions
        (bool success, ) = msg.sender.call{value: refundAmount}("");
        if (!success) revert CrowdFund__RefundTransferFailed();

        emit RefundIssued(msg.sender, refundAmount);
    }
}
