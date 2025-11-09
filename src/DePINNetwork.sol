// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DePINNetwork
 * @dev Simple DEPIN network contract for node registration and task management
 */
contract DePINNetwork is Ownable {
    // Structs
    struct Node {
        address nodeAddress;
        string nodeName;
        bool isActive;
        uint256 registeredAt;
        uint256 tasksCompleted;
    }

    struct Task {
        uint256 taskId;
        string question;
        string answer;
        address assignedNode;
        bool isCompleted;
        uint256 createdAt;
        uint256 completedAt;
    }

    // State variables
    mapping(address => Node) public nodes;
    mapping(uint256 => Task) public tasks;
    address[] public registeredNodes;
    uint256 public taskCounter;

    // Events
    event NodeRegistered(address indexed nodeAddress, string nodeName, uint256 timestamp);
    event NodeDeactivated(address indexed nodeAddress, uint256 timestamp);
    event TaskCreated(uint256 indexed taskId, string question, uint256 timestamp);
    event TaskAssigned(uint256 indexed taskId, address indexed nodeAddress, uint256 timestamp);
    event TaskCompleted(uint256 indexed taskId, address indexed nodeAddress, string answer, uint256 timestamp);

    constructor() Ownable(msg.sender) { }

    /**
     * @dev Register a new node operator
     * @param _nodeName Name of the node
     */
    function registerNode(string memory _nodeName) external {
        require(!nodes[msg.sender].isActive, "Node already registered");
        require(bytes(_nodeName).length > 0, "Node name cannot be empty");

        nodes[msg.sender] = Node({
            nodeAddress: msg.sender,
            nodeName: _nodeName,
            isActive: true,
            registeredAt: block.timestamp,
            tasksCompleted: 0
        });

        registeredNodes.push(msg.sender);

        emit NodeRegistered(msg.sender, _nodeName, block.timestamp);
    }

    /**
     * @dev Deactivate a node
     */
    function deactivateNode() external {
        require(nodes[msg.sender].isActive, "Node not registered or already inactive");
        nodes[msg.sender].isActive = false;
        emit NodeDeactivated(msg.sender, block.timestamp);
    }

    /**
     * @dev Add a new task (question) to the network
     * @param _question The question to be answered
     */
    function addTask(string memory _question) external onlyOwner returns (uint256) {
        require(bytes(_question).length > 0, "Question cannot be empty");

        uint256 taskId = taskCounter++;

        tasks[taskId] = Task({
            taskId: taskId,
            question: _question,
            answer: "",
            assignedNode: address(0),
            isCompleted: false,
            createdAt: block.timestamp,
            completedAt: 0
        });

        emit TaskCreated(taskId, _question, block.timestamp);

        return taskId;
    }

    /**
     * @dev Assign a task to a node (can be called by node or owner)
     * @param _taskId The task ID to assign
     */
    function assignTask(uint256 _taskId) external {
        require(nodes[msg.sender].isActive, "Only active nodes can take tasks");
        require(_taskId < taskCounter, "Task does not exist");
        require(!tasks[_taskId].isCompleted, "Task already completed");
        require(tasks[_taskId].assignedNode == address(0), "Task already assigned");

        tasks[_taskId].assignedNode = msg.sender;

        emit TaskAssigned(_taskId, msg.sender, block.timestamp);
    }

    /**
     * @dev Complete a task by submitting the answer
     * @param _taskId The task ID to complete
     * @param _answer The answer to the question
     */
    function completeTask(uint256 _taskId, string memory _answer) external {
        require(nodes[msg.sender].isActive, "Only active nodes can complete tasks");
        require(_taskId < taskCounter, "Task does not exist");
        require(tasks[_taskId].assignedNode == msg.sender, "Task not assigned to this node");
        require(!tasks[_taskId].isCompleted, "Task already completed");
        require(bytes(_answer).length > 0, "Answer cannot be empty");

        tasks[_taskId].answer = _answer;
        tasks[_taskId].isCompleted = true;
        tasks[_taskId].completedAt = block.timestamp;
        nodes[msg.sender].tasksCompleted++;

        emit TaskCompleted(_taskId, msg.sender, _answer, block.timestamp);
    }

    /**
     * @dev Get task result
     * @param _taskId The task ID to query
     */
    function getTaskResult(uint256 _taskId)
        external
        view
        returns (
            string memory question,
            string memory answer,
            address assignedNode,
            bool isCompleted,
            uint256 createdAt,
            uint256 completedAt
        )
    {
        require(_taskId < taskCounter, "Task does not exist");
        Task memory task = tasks[_taskId];
        return (task.question, task.answer, task.assignedNode, task.isCompleted, task.createdAt, task.completedAt);
    }

    /**
     * @dev Check if an address is a registered active node
     * @param _nodeAddress The address to check
     */
    function isNodeActive(address _nodeAddress) external view returns (bool) {
        return nodes[_nodeAddress].isActive;
    }

    /**
     * @dev Get node information
     * @param _nodeAddress The address of the node
     */
    function getNodeInfo(address _nodeAddress)
        external
        view
        returns (string memory nodeName, bool isActive, uint256 registeredAt, uint256 tasksCompleted)
    {
        Node memory node = nodes[_nodeAddress];
        return (node.nodeName, node.isActive, node.registeredAt, node.tasksCompleted);
    }

    /**
     * @dev Get all registered nodes
     */
    function getRegisteredNodes() external view returns (address[] memory) {
        return registeredNodes;
    }

    /**
     * @dev Get task count
     */
    function getTaskCount() external view returns (uint256) {
        return taskCounter;
    }
}
