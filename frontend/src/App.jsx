import { useState, useEffect } from 'react';
import { ethers } from 'ethers';

// ============================================================================
// 1. CONFIGURATION (Người dùng tự điền sau khi Deploy)
// ============================================================================

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================
const formatEth = (ethString) => {
  if (!ethString || isNaN(Number(ethString))) {
    return "0.0000";
  }
  return Number(ethString).toLocaleString('en-US', {
    maximumFractionDigits: 4,
  });
};
// ============================================================================
const CONTRACT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // Ví dụ: "0x123..."
const CONTRACT_ABI = [{"type": "constructor","inputs": [{"name": "_minimum","type": "uint256","internalType": "uint256"}],"stateMutability": "nonpayable"},{"type": "function","name": "approveRequest","inputs": [{"name": "_index","type": "uint256","internalType": "uint256"}],"outputs": [],"stateMutability": "nonpayable"},{"type": "function","name": "cancelVoters","inputs": [{"name": "","type": "address","internalType": "address"}],"outputs": [{"name": "","type": "bool","internalType": "bool"}],"stateMutability": "view"},{"type": "function","name": "cancelVotesWeight","inputs": [],"outputs": [{"name": "","type": "uint256","internalType": "uint256"}],"stateMutability": "view"},{"type": "function","name": "consecutiveRejectedRequests","inputs": [],"outputs": [{"name": "","type": "uint256","internalType": "uint256"}],"stateMutability": "view"},{"type": "function","name": "contribute","inputs": [],"outputs": [],"stateMutability": "payable"},{"type": "function","name": "contributions","inputs": [{"name": "","type": "address","internalType": "address"}],"outputs": [{"name": "","type": "uint256","internalType": "uint256"}],"stateMutability": "view"},{"type": "function","name": "createRequest","inputs": [{"name": "_description","type": "string","internalType": "string"},{"name": "_amount","type": "uint256","internalType": "uint256"},{"name": "_recipient","type": "address","internalType": "address payable"}],"outputs": [],"stateMutability": "nonpayable"},{"type": "function","name": "finalizeRequest","inputs": [{"name": "_index","type": "uint256","internalType": "uint256"}],"outputs": [],"stateMutability": "nonpayable"},{"type": "function","name": "getRefund","inputs": [],"outputs": [],"stateMutability": "nonpayable"},{"type": "function","name": "lockedRefundPool","inputs": [],"outputs": [{"name": "","type": "uint256","internalType": "uint256"}],"stateMutability": "view"},{"type": "function","name": "manager","inputs": [],"outputs": [{"name": "","type": "address","internalType": "address"}],"stateMutability": "view"},{"type": "function","name": "minimumContribution","inputs": [],"outputs": [{"name": "","type": "uint256","internalType": "uint256"}],"stateMutability": "view"},{"type": "function","name": "projectFailed","inputs": [],"outputs": [{"name": "","type": "bool","internalType": "bool"}],"stateMutability": "view"},{"type": "function","name": "requests","inputs": [{"name": "","type": "uint256","internalType": "uint256"}],"outputs": [{"name": "description","type": "string","internalType": "string"},{"name": "amount","type": "uint256","internalType": "uint256"},{"name": "recipient","type": "address","internalType": "address"},{"name": "approvalWeight","type": "uint256","internalType": "uint256"},{"name": "complete","type": "bool","internalType": "bool"},{"name": "deadline","type": "uint256","internalType": "uint256"}],"stateMutability": "view"},{"type": "function","name": "totalRaised","inputs": [],"outputs": [{"name": "","type": "uint256","internalType": "uint256"}],"stateMutability": "view"},{"type": "function","name": "voteCancelProject","inputs": [],"outputs": [],"stateMutability": "nonpayable"},{"type": "event","name": "ContributeEvent","inputs": [{"name": "backer","type": "address","indexed": true,"internalType": "address"},{"name": "amount","type": "uint256","indexed": false,"internalType": "uint256"},{"name": "totalContributed","type": "uint256","indexed": false,"internalType": "uint256"}],"anonymous": false},{"type": "event","name": "ProjectCancelVoted","inputs": [{"name": "voter","type": "address","indexed": true,"internalType": "address"},{"name": "weight","type": "uint256","indexed": false,"internalType": "uint256"}],"anonymous": false},{"type": "event","name": "ProjectCancelled","inputs": [{"name": "initiator","type": "address","indexed": true,"internalType": "address"}],"anonymous": false},{"type": "event","name": "RefundIssued","inputs": [{"name": "backer","type": "address","indexed": true,"internalType": "address"},{"name": "amount","type": "uint256","indexed": false,"internalType": "uint256"}],"anonymous": false},{"type": "event","name": "RequestApproved","inputs": [{"name": "voter","type": "address","indexed": true,"internalType": "address"},{"name": "requestId","type": "uint256","indexed": true,"internalType": "uint256"},{"name": "weight","type": "uint256","indexed": false,"internalType": "uint256"}],"anonymous": false},{"type": "event","name": "RequestCreatedEvent","inputs": [{"name": "requestId","type": "uint256","indexed": true,"internalType": "uint256"},{"name": "description","type": "string","indexed": false,"internalType": "string"},{"name": "amount","type": "uint256","indexed": false,"internalType": "uint256"},{"name": "recipient","type": "address","indexed": false,"internalType": "address"},{"name": "deadline","type": "uint256","indexed": false,"internalType": "uint256"}],"anonymous": false},{"type": "error","name": "CrowdFund__AlreadyVoted","inputs": []},{"type": "error","name": "CrowdFund__CannotFinalizeYet","inputs": []},{"type": "error","name": "CrowdFund__ContributionTooLow","inputs": []},{"type": "error","name": "CrowdFund__EmptyDescription","inputs": []},{"type": "error","name": "CrowdFund__InsufficientContractBalance","inputs": []},{"type": "error","name": "CrowdFund__InvalidRequest","inputs": []},{"type": "error","name": "CrowdFund__InvalidRequestAmount","inputs": []},{"type": "error","name": "CrowdFund__ManagerCannotContribute","inputs": []},{"type": "error","name": "CrowdFund__NotContributor","inputs": []},{"type": "error","name": "CrowdFund__NotEnoughVotes","inputs": []},{"type": "error","name": "CrowdFund__NotManager","inputs": []},{"type": "error","name": "CrowdFund__ProjectAlreadyFailed","inputs": []},{"type": "error","name": "CrowdFund__ProjectFailed","inputs": []},{"type": "error","name": "CrowdFund__ProjectNotFailed","inputs": []},{"type": "error","name": "CrowdFund__RefundTransferFailed","inputs": []},{"type": "error","name": "CrowdFund__RequestAlreadyCompleted","inputs": []},{"type": "error","name": "CrowdFund__RequestNotComplete","inputs": []},{"type": "error","name": "CrowdFund__TransferFailed","inputs": []},{"type": "error","name": "CrowdFund__VotingEnded","inputs": []},{"type": "error","name": "CrowdFund__ZeroAddress","inputs": []},{"type": "error","name": "CrowdFund__ZeroAmount","inputs": []}];

function App() {
  // ==========================================================================
  // 2. STATE MANAGEMENT
  // ==========================================================================
  const [account, setAccount] = useState(null);
  const [contract, setContract] = useState(null);
  const [provider, setProvider] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [managerAddress, setManagerAddress] = useState("");
  const [userContribution, setUserContribution] = useState("0");
  const [historyPage, setHistoryPage] = useState(1); // Pagination state

  // Dữ liệu dự án
  const [projectStats, setProjectStats] = useState({
    manager: "",
    minimumContribution: "0",
    totalRaised: "0",
    currentBalance: "0",
    lockedRefundPool: "0", // Thay thế approversCount
    projectFailed: false,
    consecutiveRejectedRequests: "0",
    cancelVotesWeight: "0",
  });

  // Danh sách Requests
  const [requests, setRequests] = useState([]);

  // Form Inputs
  const [contributeAmount, setContributeAmount] = useState("");
  const [createReqForm, setCreateReqForm] = useState({
    description: "",
    amount: "",
    recipient: "",
  });

  useEffect(() => {
    if (projectStats.projectFailed) {
      document.title = "TrustFund | Project Canceled";
    } else {
      document.title = "TrustFund | Dashboard";
    }
  }, [projectStats.projectFailed]); // Chạy lại mỗi khi trạng thái dự án thay đổi

  // Tự động lắng nghe sự kiện thay đổi ví hoặc mạng
  useEffect(() => {
    if (window.ethereum) {
      const handleAccountsChanged = (accounts) => {
        if (accounts.length > 0) {
          setAccount(accounts[0]);
          // Kết nối lại để cập nhật signer mới
          connectWallet();
        } else {
          setAccount(null);
          setContract(null);
          setUserContribution("0");
        }
      };

      const handleChainChanged = () => {
        window.location.reload();
      };

      window.ethereum.on('accountsChanged', handleAccountsChanged);
      window.ethereum.on('chainChanged', handleChainChanged);

      return () => {
        window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
        window.ethereum.removeListener('chainChanged', handleChainChanged);
      };
    }
  }, []);

  // ==========================================================================
  // 3. WEB3 CONNECTION & DATA FETCHING
  // ==========================================================================

  const connectWallet = async () => {
    try {
      if (!window.ethereum) return alert("Vui lòng cài đặt MetaMask!");
      
      const _provider = new ethers.BrowserProvider(window.ethereum);
      const accounts = await _provider.send("eth_requestAccounts", []);
      const _signer = await _provider.getSigner();
      
      // Khởi tạo Contract Instance
      const _contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, _signer);

      setAccount(accounts[0]);
      setProvider(_provider);
      setContract(_contract);
      
      // Load dữ liệu ngay sau khi kết nối
      fetchProjectData(_contract, _provider, accounts[0]);

    } catch (err) {
      console.error(err);
      setError("Kết nối ví thất bại!");
    }
  };

  const fetchProjectData = async (_contract, _provider, _currentAccount = account) => {
    try {
      setLoading(true);
      
      // 1. Lấy các biến public từ Smart Contract
      const manager = await _contract.manager();
      setManagerAddress(manager);
      const minContrib = await _contract.minimumContribution();
      const totalRaised = await _contract.totalRaised();
      const lockedRefundPool = await _contract.lockedRefundPool();
      const projectFailed = await _contract.projectFailed();
      const consecutiveRejectedRequests = await _contract.consecutiveRejectedRequests();
      const cancelVotesWeight = await _contract.cancelVotesWeight();
      
      // Lấy số dư thực tế của Contract
      const balance = await _provider.getBalance(CONTRACT_ADDRESS);

      // Lấy thông tin đóng góp của user hiện tại
      if (_currentAccount) {
        const contrib = await _contract.contributions(_currentAccount);
        setUserContribution(ethers.formatEther(contrib));
      }

      setProjectStats({
        manager: manager.toLowerCase(),
        minimumContribution: ethers.formatEther(minContrib),
        totalRaised: ethers.formatEther(totalRaised),
        currentBalance: ethers.formatEther(balance),
        lockedRefundPool: ethers.formatEther(lockedRefundPool),
        projectFailed: projectFailed,
        consecutiveRejectedRequests: consecutiveRejectedRequests.toString(),
        cancelVotesWeight: ethers.formatEther(cancelVotesWeight),
      });

      // 2. Lấy danh sách Requests
      // Do Solidity không trả về mảng struct trực tiếp dễ dàng, ta loop qua index
      // (Cách này tạm thời cho demo, thực tế nên có hàm getRequestsCount hoặc dùng The Graph)
      const reqs = [];
      let index = 0;
      while (true) {
        try {
          // Gọi requests(index)
          const req = await _contract.requests(index);
          const deadlineTs = Number(req[5]);
          reqs.push({
            id: index,
            description: req[0],
            amount: ethers.formatEther(req[1]),
            recipient: req[2],
            approvalWeight: ethers.formatEther(req[3]),
            complete: req[4],
            deadlineTs: deadlineTs,
            deadline: new Date(deadlineTs * 1000).toLocaleString(),
            creationDate: new Date((deadlineTs - 7 * 24 * 60 * 60) * 1000).toLocaleDateString()
          });
          index++;
        } catch (e) {
          // Dừng loop khi không tìm thấy index tiếp theo (revert)
          break;
        }
      }
      setRequests(reqs);

    } catch (err) {
      console.error("Lỗi tải dữ liệu:", err);
    } finally {
      setLoading(false);
    }
  };

  // ==========================================================================
  // 4. TRANSACTION HANDLERS
  // ==========================================================================

  // Helper function: Parse Error Message
  const getFriendlyErrorMessage = (error) => {
    console.error("Transaction Error:", error); // Log raw error for debugging

    // 1. User Rejected
    if (error.code === "ACTION_REJECTED" || (error.message && error.message.includes("user rejected"))) {
      return "User rejected the transaction.";
    }

    // 2. Ethers v6 / Custom Errors
    // Ethers usually populates 'reason' with the revert string or custom error name if ABI is present
    if (error.reason) return error.reason;

    // 3. Try to decode custom error from data if present (and not parsed by Ethers)
    if (error.data) {
      try {
        const iface = new ethers.Interface(CONTRACT_ABI);
        const decoded = iface.parseError(error.data);
        if (decoded) return `Contract Error: ${decoded.name}`;
      } catch (e) { /* ignore decoding error */ }
    }

    // 4. Fallback to short message or full message
    if (error.shortMessage) return error.shortMessage;
    return error.message || "An unknown error occurred.";
  };

  // Helper để xử lý transaction
  const handleTx = async (txFn) => {
    if (!contract) return;
    try {
      setLoading(true);
      setError("");
      const tx = await txFn();
      await tx.wait(); // Đợi transaction được mine
      alert("Giao dịch thành công!");
      // Reload lại dữ liệu
      fetchProjectData(contract, provider);
    } catch (err) {
      const friendlyMsg = getFriendlyErrorMessage(err);
      setError(friendlyMsg);
      // Auto-hide toast after 6 seconds
      setTimeout(() => setError(""), 6000);
    } finally {
      setLoading(false);
    }
  };

  // Hàm refresh thủ công
  const onRefresh = () => {
    if (contract && provider) {
      fetchProjectData(contract, provider);
    }
  };

  const onContribute = () => {
    if (!contributeAmount) return;
    handleTx(() => contract.contribute({ value: ethers.parseEther(contributeAmount) }));
  };

  const onVoteCancel = () => {
    handleTx(() => contract.voteCancelProject());
  };

  const onRefund = () => {
    handleTx(() => contract.getRefund());
  };

  const onCreateRequest = () => {
    const { description, amount, recipient } = createReqForm;
    if (!description || !amount || !recipient) return;
    handleTx(() => contract.createRequest(description, ethers.parseEther(amount), recipient));
  };

  const onApproveRequest = (id) => {
    handleTx(() => contract.approveRequest(id));
  };

  const onFinalizeRequest = (id) => {
    const req = requests.find((r) => r.id === id);
    if (!req) return;

    const totalRaisedNum = Number(projectStats.totalRaised);
    const approvalWeightNum = Number(req.approvalWeight);
    
    // Check if failing (<= 50%)
    const isFailing = approvalWeightNum <= (totalRaisedNum / 2);

    if (isFailing) {
      const confirmed = window.confirm("⚠️ Cảnh báo: Yêu cầu này chưa đạt đủ >50% phiếu thuận. Nếu bạn Finalize ngay lúc này, hệ thống sẽ tính đây là 1 lần THẤT BẠI. (Dự án sẽ bị hủy nếu đạt 4 lần thất bại liên tiếp). Bạn có chắc chắn muốn tiếp tục?");
      if (!confirmed) return;
    }

    handleTx(() => contract.finalizeRequest(id));
  };

  // ==========================================================================
  // 5. UI RENDERING
  // ==========================================================================

  const isManager = account?.toLowerCase() === managerAddress?.toLowerCase();
  const consecutiveFailures = Number(projectStats.consecutiveRejectedRequests);

  // Filter & Pagination Logic
  const activeRequests = requests.filter(req => !req.complete);
  const historyRequests = requests.filter(req => req.complete).sort((a, b) => b.id - a.id); // Newest first
  const itemsPerPage = 5;
  const totalPages = Math.ceil(historyRequests.length / itemsPerPage);
  const currentHistory = historyRequests.slice((historyPage - 1) * itemsPerPage, historyPage * itemsPerPage);

  return (
    <div className="min-h-screen bg-gray-900 text-white font-sans p-6">
      <div className="max-w-6xl mx-auto space-y-8">
        
        {/* HEADER */}
        <header className="flex justify-between items-center border-b border-gray-700 pb-6">
          <div>
            <h1 className="text-3xl font-bold text-blue-400">TRUSTFUND</h1>
            <p className="text-gray-400 text-sm">Decentralized Milestone-based Crowdfunding</p>
          </div>
          <button 
            onClick={connectWallet}
            className={`px-6 py-2 rounded-full font-semibold transition flex items-center gap-2 ${
              account 
                ? (isManager ? "bg-yellow-500 text-black cursor-default" : "bg-sky-600 text-white cursor-default") 
                : "bg-blue-600 hover:bg-blue-700 text-white"
            }`}
          >
            {account ? (
              <>
                <span className="w-2 h-2 rounded-full bg-current animate-pulse"></span>
                {isManager ? "Manager: " : "Backer: "}
                {account.slice(0, 6)}...{account.slice(-4)}
              </>
            ) : "Connect Wallet"}
          </button>
        </header>

        {/* ERROR TOAST (Fixed Position) */}
        {error && (
          <div className="fixed top-5 right-5 z-50 max-w-md w-full bg-red-900/95 border border-red-500 text-red-100 p-4 rounded-lg shadow-2xl backdrop-blur-sm transition-all transform translate-y-0" style={{ wordBreak: "break-word" }}>
            <div className="flex justify-between items-start gap-3">
              <span className="text-2xl">⚠️</span>
              <div className="flex-1 overflow-hidden">
                <h4 className="font-bold text-sm uppercase text-red-300 mb-1">Transaction Failed</h4>
                <p className="text-sm max-h-40 overflow-y-auto pr-2 custom-scrollbar">
                  {error}
                </p>
              </div>
              <button onClick={() => setError("")} className="text-red-300 hover:text-white font-bold text-xl leading-none">&times;</button>
            </div>
          </div>
        )}

        {/* LOADING OVERLAY */}
        {loading && (
          <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50">
            <div className="animate-spin rounded-full h-16 w-16 border-t-4 border-blue-500"></div>
          </div>
        )}

        {/* WARNING BANNERS (Anti-Scam System) */}
        {!projectStats.projectFailed && consecutiveFailures === 2 && (
          <div className="bg-orange-900/50 border border-orange-500 text-orange-200 p-4 rounded-lg flex items-center gap-3">
            <span className="text-2xl">⚠️</span>
            <div>
              <p className="font-bold">Caution: 2 consecutive requests have been rejected by backers.</p>
              <p className="text-sm opacity-80">If 4 consecutive requests are rejected, the project will be marked as FAILED.</p>
            </div>
          </div>
        )}

        {!projectStats.projectFailed && consecutiveFailures === 3 && (
          <div className="bg-red-900/50 border border-red-500 text-red-200 p-4 rounded-lg animate-pulse flex items-center gap-3">
            <span className="text-2xl">🚨</span>
            <div>
              <p className="font-bold text-lg">CRITICAL WARNING: 3 consecutive requests rejected!</p>
              <p className="text-sm">1 more rejection will automatically CANCEL the entire project and trigger refunds!</p>
            </div>
          </div>
        )}

        {/* DASHBOARD HEADER & REFRESH */}
        <div className="flex justify-between items-center">
          <h2 className="text-xl font-bold text-gray-300">Dashboard Overview</h2>
          <button 
            onClick={onRefresh}
            disabled={loading || !contract}
            className="flex items-center gap-2 text-sm text-blue-400 hover:text-blue-300 transition disabled:opacity-50"
          >
            <svg 
              className={`w-5 h-5 ${loading ? "animate-spin" : ""}`} 
              fill="none" viewBox="0 0 24 24" stroke="currentColor"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            Refresh Data
          </button>
        </div>

        {/* DASHBOARD STATS */}
        <section className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <StatCard label="Total Raised" value={`${formatEth(projectStats.totalRaised)} ETH`} fullValue={`${projectStats.totalRaised} ETH`} />
          <StatCard label="Current Balance" value={`${formatEth(projectStats.currentBalance)} ETH`} fullValue={`${projectStats.currentBalance} ETH`} />
          <StatCard label="Locked Refund Pool" value={`${formatEth(projectStats.lockedRefundPool)} ETH`} fullValue={`${projectStats.lockedRefundPool} ETH`} />
          <div className={`p-6 rounded-xl border ${projectStats.projectFailed ? "bg-red-900/20 border-red-500" : "bg-green-900/20 border-green-500"}`}>
            <p className="text-gray-400 text-sm uppercase tracking-wider">Status</p>
            <p className={`text-2xl font-bold mt-2 ${projectStats.projectFailed ? "text-red-400" : "text-green-400"}`}>
              {projectStats.projectFailed ? "CANCELED" : "ACTIVE"}
            </p>
          </div>
        </section>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          
          {/* LEFT COLUMN: ACTIONS */}
          <div className="lg:col-span-1 space-y-8">
            
            {/* BACKER AREA */}
            {!isManager && (
            <div className="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-lg">
              <h2 className="text-xl font-bold mb-4 text-blue-300">Backer Area</h2>
              
              <div className="mb-6 p-4 bg-blue-900/20 border border-blue-500/30 rounded-lg flex justify-between items-center">
                <span className="text-gray-300">Your Contribution:</span>
                <span className="text-xl font-bold text-blue-400 truncate" title={`${userContribution} ETH`}>{formatEth(userContribution)} ETH</span>
              </div>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Contribute Amount (ETH)</label>
                  <div className="flex gap-2">
                    <input 
                      type="number" 
                      placeholder={`Min ${projectStats.minimumContribution}`}
                      value={contributeAmount}
                      onChange={(e) => setContributeAmount(e.target.value)}
                      className="w-full bg-gray-700 border border-gray-600 rounded px-3 py-2 focus:outline-none focus:border-blue-500"
                    />
                    <button onClick={onContribute} className="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded font-medium">
                      Fund
                    </button>
                  </div>
                </div>

                <hr className="border-gray-700 my-4" />

                <button onClick={onVoteCancel} className="w-full bg-orange-700 hover:bg-orange-800 text-white py-3 rounded font-bold transition">
                  🚨 Vote Cancel Project
                </button>

                {projectStats.projectFailed && (
                  <button onClick={onRefund} className="w-full bg-red-600 hover:bg-red-700 text-white py-3 rounded font-bold animate-pulse mt-2">
                    💸 Claim Refund
                  </button>
                )}
              </div>
            </div>
            )}

            {/* MANAGER AREA (Chỉ hiển thị nếu là Manager) */}
            {isManager && (
              <div className="bg-gray-800 p-6 rounded-xl border border-purple-500/50 shadow-lg">
                <h2 className="text-xl font-bold mb-4 text-purple-300">Manager Area</h2>
                <div className="space-y-3">
                  <input 
                    type="text" placeholder="Description" 
                    className="w-full bg-gray-700 rounded px-3 py-2"
                    value={createReqForm.description}
                    onChange={(e) => setCreateReqForm({...createReqForm, description: e.target.value})}
                  />
                  <input 
                    type="number" placeholder="Amount (ETH)" 
                    className="w-full bg-gray-700 rounded px-3 py-2"
                    value={createReqForm.amount}
                    onChange={(e) => setCreateReqForm({...createReqForm, amount: e.target.value})}
                  />
                  <input 
                    type="text" placeholder="Recipient Address" 
                    className="w-full bg-gray-700 rounded px-3 py-2"
                    value={createReqForm.recipient}
                    onChange={(e) => setCreateReqForm({...createReqForm, recipient: e.target.value})}
                  />
                  <button onClick={onCreateRequest} className="w-full bg-purple-600 hover:bg-purple-700 py-2 rounded font-bold">
                    Create Request
                  </button>
                </div>
              </div>
            )}

            {/* CANCELLATION TRACKER */}
            {!projectStats.projectFailed && Number(projectStats.totalRaised) > 0 && (
              <div className="bg-gray-800 p-6 rounded-xl border border-red-500/30 shadow-lg mt-8">
                <h2 className="text-xl font-bold mb-4 text-red-400 flex items-center gap-2">
                  <span>🚨</span> Refund Vote Progress
                </h2>
                
                {(() => {
                  const cancelWeightNum = Number(projectStats.cancelVotesWeight);
                  const totalRaisedNum = Number(projectStats.totalRaised);
                  const cancelThreshold = totalRaisedNum / 2;
                  const cancelPercent = cancelThreshold > 0 ? Math.min((cancelWeightNum / cancelThreshold) * 100, 100) : 0;
                  const isHighRisk = cancelPercent >= 75;

                  return (
                    <div>
                      <div className="flex justify-between items-end mb-2">
                        <span className="text-gray-400 text-sm">Votes to Cancel Project</span>
                        <div className="text-right">
                          <span className={`font-bold text-lg ${isHighRisk ? 'text-red-400' : 'text-orange-400'}`}>
                            {formatEth(projectStats.cancelVotesWeight)}
                          </span>
                          <span className="text-sm text-gray-500"> / {formatEth(cancelThreshold)} ETH</span>
                        </div>
                      </div>
                      
                      <div className="w-full bg-gray-900 h-3 rounded-full overflow-hidden border border-gray-700">
                        <div 
                          className={`h-full transition-all duration-500 ${isHighRisk ? 'bg-red-500' : 'bg-orange-500'}`}
                          style={{ width: `${cancelPercent}%` }}
                        ></div>
                      </div>
                      
                      <p className="text-xs text-gray-500 mt-2 text-right">
                        Reaching the threshold (&gt;50% of total funds) will automatically cancel the project and unlock refunds.
                      </p>
                    </div>
                  );
                })()}
              </div>
            )}
          </div>

          {/* RIGHT COLUMN: REQUESTS LIST */}
          <div className="lg:col-span-2">
            
            {/* SECTION 1: ACTIVE PROPOSAL */}
            {activeRequests.length > 0 && (
              <div className="mb-10">
                <h2 className="text-xl font-bold text-green-400 mb-4 flex items-center gap-2">
                  <span className="animate-pulse">●</span> Current Active Proposal
                </h2>
                {activeRequests.map((req) => {
                  const totalRaised = Number(projectStats.totalRaised);
                  const approvalWeight = Number(req.approvalWeight);
                  const threshold = totalRaised / 2;
                  const approvalPercent = threshold > 0 ? Math.min((approvalWeight / threshold) * 100, 100) : 0;

                  return (
                    <div key={req.id} className="bg-gray-800 border-2 border-green-500/30 p-6 rounded-xl shadow-lg relative overflow-hidden">
                      <div className="absolute top-0 right-0 bg-green-600 text-white text-xs font-bold px-3 py-1 rounded-bl-lg">
                        VOTING LIVE
                      </div>
                      
                      <div className="mb-4">
                        <h3 className="text-2xl font-bold text-white break-words">{req.description}</h3>
                        <p className="text-sm text-gray-400 mt-1">Created on: {req.creationDate} • Deadline: {req.deadline}</p>
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
                        <div className="bg-gray-900/50 p-4 rounded-lg">
                          <p className="text-gray-500 text-xs uppercase">Request Amount</p>
                          <p className="text-xl font-bold text-white truncate" title={`${req.amount} ETH`}>{formatEth(req.amount)} ETH</p>
                          <p className="text-gray-500 text-xs mt-1">To: {req.recipient.slice(0,6)}...{req.recipient.slice(-4)}</p>
                        </div>
                        <div className="bg-gray-900/50 p-4 rounded-lg">
                          <p className="text-gray-500 text-xs uppercase">Approval Progress</p>
                          <div className="flex items-end gap-2">
                            <p className="text-xl font-bold text-green-400 truncate" title={`${req.approvalWeight} ETH`}>{formatEth(req.approvalWeight)}</p>
                            <p className="text-sm text-gray-500 mb-1 truncate" title={`${threshold} ETH`}>/ {formatEth(threshold)} ETH</p>
                          </div>
                          {/* Progress Bar */}
                          <div className="w-full bg-gray-700 h-2 rounded-full mt-2 overflow-hidden">
                            <div 
                              className="bg-green-500 h-full transition-all duration-500" 
                              style={{ width: `${Math.min(approvalPercent, 100)}%` }}
                            ></div>
                          </div>
                          <p className="text-xs text-gray-500 mt-1 text-right">Goal: Reach &gt;50% of total funds ({formatEth(threshold)} ETH) to approve.</p>
                        </div>
                      </div>

                      <div className="flex gap-3">
                        {!isManager && (
                          <button 
                            onClick={() => onApproveRequest(req.id)}
                            className="flex-1 bg-green-600 hover:bg-green-700 text-white py-3 rounded-lg font-bold text-lg shadow-lg transition transform hover:scale-[1.02]"
                          >
                            👍 Approve Request
                          </button>
                        )}
                        {isManager && (
                          <button 
                            onClick={() => onFinalizeRequest(req.id)}
                            className="flex-1 bg-purple-600 hover:bg-purple-700 text-white py-3 rounded-lg font-bold text-lg shadow-lg transition transform hover:scale-[1.02]"
                          >
                            ⚡ Finalize Request
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}

            {/* SECTION 2: FUNDING HISTORY */}
            <div>
              <h2 className="text-xl font-bold text-gray-300 mb-4 flex items-center justify-between">
                <span>Funding History</span>
                <span className="text-sm font-normal text-gray-500">Page {historyPage} of {totalPages || 1}</span>
              </h2>

              <div className="space-y-4">
                {currentHistory.length === 0 ? (
                  <div className="p-8 text-center border border-gray-700 rounded-xl bg-gray-800/50">
                    <p className="text-gray-500">No finalized requests yet.</p>
                  </div>
                ) : (
                  currentHistory.map((req) => {
                    const totalRaised = Number(projectStats.totalRaised);
                    const approvalWeight = Number(req.approvalWeight);
                    const isApproved = approvalWeight > totalRaised / 2;

                    return (
                      <div key={req.id} className="bg-gray-800 border border-gray-700 p-5 rounded-xl opacity-90 hover:opacity-100 transition">
                        <div className="flex justify-between items-start mb-2">
                          <div>
                            <h3 className="text-lg font-bold text-gray-200 break-words">{req.description}</h3>
                            <p className="text-xs text-gray-500">Created: {req.creationDate}</p>
                          </div>
                          {isApproved ? (
                            <span className="px-3 py-1 rounded text-xs font-bold bg-green-900/50 text-green-400 border border-green-700" title={`Snapshot Verified: ${req.approvalWeight} ETH`}>
                              Approved: {formatEth(req.approvalWeight)} ETH (&gt;50%)
                            </span>
                          ) : (
                            <span className="px-3 py-1 rounded text-xs font-bold bg-red-900/50 text-red-400 border border-red-700">
                              Rejected / Expired
                            </span>
                          )}
                        </div>
                        <div className="flex justify-between items-center text-sm text-gray-400 mt-3">
                          <span>Amount: <span className="text-white truncate" title={`${req.amount} ETH`}>{formatEth(req.amount)} ETH</span></span>
                          <span>Recipient: {req.recipient.slice(0,6)}...</span>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>

              {/* Pagination Controls */}
              {totalPages > 1 && (
                <div className="flex justify-center gap-4 mt-6">
                  <button 
                    onClick={() => setHistoryPage(p => Math.max(1, p - 1))}
                    disabled={historyPage === 1}
                    className="px-4 py-2 bg-gray-800 hover:bg-gray-700 rounded disabled:opacity-50 transition"
                  >
                    Previous
                  </button>
                  <button 
                    onClick={() => setHistoryPage(p => Math.min(totalPages, p + 1))}
                    disabled={historyPage === totalPages}
                    className="px-4 py-2 bg-gray-800 hover:bg-gray-700 rounded disabled:opacity-50 transition"
                  >
                    Next
                  </button>
                </div>
              )}
            </div>
          </div>

        </div>
      </div>
    </div>
  );
}

// Component phụ hiển thị thẻ thống kê
function StatCard({ label, value, fullValue }) {
  return (
    <div className="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-sm overflow-hidden">
      <p className="text-gray-400 text-sm uppercase tracking-wider">{label}</p>
      <p className="text-2xl font-bold text-white mt-2 truncate" title={fullValue || value}>{value}</p>
    </div>
  );
}

export default App;
