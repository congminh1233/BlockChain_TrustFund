import { useState, useEffect } from 'react';
import { ethers } from 'ethers';

// ============================================================================
// 1. CONFIGURATION (Người dùng tự điền sau khi Deploy)
// ============================================================================
const CONTRACT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // Ví dụ: "0x123..."
const CONTRACT_ABI = [{"type":"constructor","inputs":[{"name":"_minimum","type":"uint256","internalType":"uint256"}],"stateMutability":"nonpayable"},{"type":"function","name":"approveRequest","inputs":[{"name":"_index","type":"uint256","internalType":"uint256"}],"outputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"approversCount","inputs":[],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},{"type":"function","name":"cancelVoters","inputs":[{"name":"","type":"address","internalType":"address"}],"outputs":[{"name":"","type":"bool","internalType":"bool"}],"stateMutability":"view"},{"type":"function","name":"cancelVotesCount","inputs":[],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},{"type":"function","name":"consecutiveRejectedRequests","inputs":[],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},{"type":"function","name":"contribute","inputs":[],"outputs":[],"stateMutability":"payable"},{"type":"function","name":"contributions","inputs":[{"name":"","type":"address","internalType":"address"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},{"type":"function","name":"createRequest","inputs":[{"name":"_description","type":"string","internalType":"string"},{"name":"_amount","type":"uint256","internalType":"uint256"},{"name":"_recipient","type":"address","internalType":"address payable"}],"outputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"finalizeRequest","inputs":[{"name":"_index","type":"uint256","internalType":"uint256"}],"outputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"getRefund","inputs":[],"outputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"manager","inputs":[],"outputs":[{"name":"","type":"address","internalType":"address"}],"stateMutability":"view"},{"type":"function","name":"minimumContribution","inputs":[],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},{"type":"function","name":"projectFailed","inputs":[],"outputs":[{"name":"","type":"bool","internalType":"bool"}],"stateMutability":"view"},{"type":"function","name":"requests","inputs":[{"name":"","type":"uint256","internalType":"uint256"}],"outputs":[{"name":"description","type":"string","internalType":"string"},{"name":"amount","type":"uint256","internalType":"uint256"},{"name":"recipient","type":"address","internalType":"address"},{"name":"approvalCount","type":"uint256","internalType":"uint256"},{"name":"complete","type":"bool","internalType":"bool"}],"stateMutability":"view"},{"type":"function","name":"totalRaised","inputs":[],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},{"type":"function","name":"voteCancelProject","inputs":[],"outputs":[],"stateMutability":"nonpayable"},{"type":"event","name":"ContributeEvent","inputs":[{"name":"backer","type":"address","indexed":true,"internalType":"address"},{"name":"amount","type":"uint256","indexed":false,"internalType":"uint256"},{"name":"totalContributed","type":"uint256","indexed":false,"internalType":"uint256"}],"anonymous":false},{"type":"event","name":"ProjectCancelled","inputs":[{"name":"initiator","type":"address","indexed":true,"internalType":"address"}],"anonymous":false},{"type":"event","name":"RefundIssued","inputs":[{"name":"backer","type":"address","indexed":true,"internalType":"address"},{"name":"amount","type":"uint256","indexed":false,"internalType":"uint256"}],"anonymous":false},{"type":"event","name":"RequestCreatedEvent","inputs":[{"name":"requestId","type":"uint256","indexed":true,"internalType":"uint256"},{"name":"description","type":"string","indexed":false,"internalType":"string"},{"name":"amount","type":"uint256","indexed":false,"internalType":"uint256"},{"name":"recipient","type":"address","indexed":false,"internalType":"address"}],"anonymous":false},{"type":"error","name":"CrowdFund__AlreadyVoted","inputs":[]},{"type":"error","name":"CrowdFund__ContributionTooLow","inputs":[]},{"type":"error","name":"CrowdFund__InsufficientContractBalance","inputs":[]},{"type":"error","name":"CrowdFund__InvalidRequestAmount","inputs":[]},{"type":"error","name":"CrowdFund__NotContributor","inputs":[]},{"type":"error","name":"CrowdFund__NotEnoughVotes","inputs":[]},{"type":"error","name":"CrowdFund__NotManager","inputs":[]},{"type":"error","name":"CrowdFund__ProjectAlreadyFailed","inputs":[]},{"type":"error","name":"CrowdFund__ProjectNotFailed","inputs":[]},{"type":"error","name":"CrowdFund__RefundTransferFailed","inputs":[]},{"type":"error","name":"CrowdFund__RequestAlreadyCompleted","inputs":[]},{"type":"error","name":"CrowdFund__TransferFailed","inputs":[]}];     // Copy mảng ABI từ file JSON sau khi compile (out/CrowdFund.sol/CrowdFund.json)

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

  // Dữ liệu dự án
  const [projectStats, setProjectStats] = useState({
    manager: "",
    minimumContribution: "0",
    totalRaised: "0",
    currentBalance: "0",
    approversCount: "0",
    projectFailed: false,
    consecutiveRejectedRequests: "0",
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
      fetchProjectData(_contract, _provider);

    } catch (err) {
      console.error(err);
      setError("Kết nối ví thất bại!");
    }
  };

  const fetchProjectData = async (_contract, _provider) => {
    try {
      setLoading(true);
      
      // 1. Lấy các biến public từ Smart Contract
      const manager = await _contract.manager();
      setManagerAddress(manager);
      const minContrib = await _contract.minimumContribution();
      const totalRaised = await _contract.totalRaised();
      const approversCount = await _contract.approversCount();
      const projectFailed = await _contract.projectFailed();
      const consecutiveRejectedRequests = await _contract.consecutiveRejectedRequests();
      
      // Lấy số dư thực tế của Contract
      const balance = await _provider.getBalance(CONTRACT_ADDRESS);

      setProjectStats({
        manager: manager.toLowerCase(),
        minimumContribution: ethers.formatEther(minContrib),
        totalRaised: ethers.formatEther(totalRaised),
        currentBalance: ethers.formatEther(balance),
        approversCount: approversCount.toString(),
        projectFailed: projectFailed,
        consecutiveRejectedRequests: consecutiveRejectedRequests.toString(),
      });

      // 2. Lấy danh sách Requests
      // Do Solidity không trả về mảng struct trực tiếp dễ dàng, ta loop qua index
      // (Cách này tạm thời cho demo, thực tế nên có hàm getRequestsCount hoặc dùng The Graph)
      const reqs = [];
      let index = 0;
      while (true) {
        try {
          // Gọi requests(index) -> Trả về mảng [desc, amount, recipient, approvalCount, complete]
          const req = await _contract.requests(index);
          reqs.push({
            id: index,
            description: req[0],
            amount: ethers.formatEther(req[1]),
            recipient: req[2],
            approvalCount: req[3].toString(),
            complete: req[4]
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
      console.error(err);
      // Parse lỗi từ Ethers (nếu có custom error)
      setError(err.reason || err.message || "Giao dịch thất bại!");
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
    handleTx(() => contract.finalizeRequest(id));
  };

  // ==========================================================================
  // 5. UI RENDERING
  // ==========================================================================

  const isManager = account?.toLowerCase() === managerAddress?.toLowerCase();
  const consecutiveFailures = Number(projectStats.consecutiveRejectedRequests);

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

        {/* ERROR MESSAGE */}
        {error && (
          <div className="bg-red-900/50 border border-red-500 text-red-200 p-4 rounded-lg">
            ⚠️ {error}
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
          <StatCard label="Total Raised" value={`${projectStats.totalRaised} ETH`} />
          <StatCard label="Current Balance" value={`${projectStats.currentBalance} ETH`} />
          <StatCard label="Backers" value={projectStats.approversCount} />
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
          </div>

          {/* RIGHT COLUMN: REQUESTS LIST */}
          <div className="lg:col-span-2">
            <h2 className="text-2xl font-bold mb-6 flex items-center gap-2">
              <span>Spending Requests</span>
              <span className="bg-gray-700 text-sm px-2 py-1 rounded-full">{requests.length}</span>
            </h2>

            <div className="space-y-4">
              {requests.length === 0 ? (
                <p className="text-gray-500 italic">No requests created yet.</p>
              ) : (
                requests.map((req) => {
                  const totalApprovers = Number(projectStats.approversCount);
                  const approvalCount = Number(req.approvalCount);
                  
                  let statusBadge;
                  if (!req.complete) {
                    statusBadge = <span className="px-2 py-1 rounded text-xs font-bold bg-yellow-900 text-yellow-300">PENDING</span>;
                  } else if (approvalCount > totalApprovers / 2) {
                    statusBadge = <span className="px-2 py-1 rounded text-xs font-bold bg-green-900 text-green-300">SUCCESS</span>;
                  } else {
                    statusBadge = <span className="px-2 py-1 rounded text-xs font-bold bg-red-900/50 text-red-300 border border-red-700">REJECTED</span>;
                  }

                  return (
                  <div key={req.id} className={`p-5 rounded-xl border ${req.complete ? "bg-gray-800/50 border-gray-700 opacity-70" : "bg-gray-800 border-gray-600"}`}>
                    <div className="flex justify-between items-start mb-3">
                      <h3 className="text-lg font-bold text-white">{req.description}</h3>
                      {statusBadge}
                    </div>
                    
                    <div className="grid grid-cols-2 gap-4 text-sm text-gray-300 mb-4">
                      <div><span className="text-gray-500">Amount:</span> {req.amount} ETH</div>
                      <div><span className="text-gray-500">Recipient:</span> {req.recipient.slice(0,6)}...{req.recipient.slice(-4)}</div>
                      <div className="col-span-2">
                        <span className="text-gray-500">Approval:</span> 
                        <span className="text-white font-bold ml-2">{req.approvalCount}</span> 
                        <span className="text-gray-500 mx-1">/</span> 
                        <span>{projectStats.approversCount} Backers</span>
                      </div>
                    </div>

                    {!req.complete && (
                      <div className="flex gap-3 mt-4">
                        {!isManager && (
                          <button 
                            onClick={() => onApproveRequest(req.id)}
                            className="flex-1 bg-green-600 hover:bg-green-700 py-2 rounded font-medium text-sm"
                          >
                            👍 Approve
                          </button>
                        )}
                        {isManager && (
                          <button 
                            onClick={() => onFinalizeRequest(req.id)}
                            className="flex-1 bg-purple-600 hover:bg-purple-700 py-2 rounded font-medium text-sm"
                          >
                            ⚡ Finalize
                          </button>
                        )}
                      </div>
                    )}
                  </div>
                  );
                })
              )}
            </div>
          </div>

        </div>
      </div>
    </div>
  );
}

// Component phụ hiển thị thẻ thống kê
function StatCard({ label, value }) {
  return (
    <div className="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-sm">
      <p className="text-gray-400 text-sm uppercase tracking-wider">{label}</p>
      <p className="text-2xl font-bold text-white mt-2">{value}</p>
    </div>
  );
}

export default App;
