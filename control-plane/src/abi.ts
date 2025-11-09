export const DePINNetworkABI = [
  "event NodeRegistered(address indexed nodeAddress, string nodeName, uint256 timestamp)",
  "event NodeDeactivated(address indexed nodeAddress, uint256 timestamp)",
  "event TaskCreated(uint256 indexed taskId, string question, uint256 timestamp)",
  "event TaskAssigned(uint256 indexed taskId, address indexed nodeAddress, uint256 timestamp)",
  "event TaskCompleted(uint256 indexed taskId, address indexed nodeAddress, string answer, uint256 timestamp)",
  "function registerNode(string memory _nodeName) external",
  "function deactivateNode() external",
  "function addTask(string memory _question) external returns (uint256)",
  "function assignTask(uint256 _taskId) external",
  "function completeTask(uint256 _taskId, string memory _answer) external",
  "function getNodeInfo(address _nodeAddress) external view returns (string memory nodeName, bool isActive, uint256 registeredAt, uint256 tasksCompleted)",
  "function getTaskResult(uint256 _taskId) external view returns (string memory question, string memory answer, address assignedNode, bool isCompleted)",
  "function isNodeActive(address _nodeAddress) external view returns (bool)",
  "function taskCounter() external view returns (uint256)"
];
