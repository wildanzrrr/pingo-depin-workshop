// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { DePINNetwork } from "../src/DePINNetwork.sol";

contract DePINNetworkTest is Test {
    DePINNetwork public depinNetwork;
    address public owner;
    address public node1;
    address public node2;

    event NodeRegistered(address indexed nodeAddress, string nodeName, uint256 timestamp);
    event TaskCreated(uint256 indexed taskId, string question, uint256 timestamp);
    event TaskAssigned(uint256 indexed taskId, address indexed nodeAddress, uint256 timestamp);
    event TaskCompleted(uint256 indexed taskId, address indexed nodeAddress, string answer, uint256 timestamp);

    function setUp() public {
        owner = address(this);
        node1 = makeAddr("node1");
        node2 = makeAddr("node2");

        depinNetwork = new DePINNetwork();
    }

    function testRegisterNode() public {
        vm.startPrank(node1);

        vm.expectEmit(true, false, false, true);
        emit NodeRegistered(node1, "Node 1", block.timestamp);

        depinNetwork.registerNode("Node 1");

        (string memory nodeName, bool isActive, uint256 registeredAt, uint256 tasksCompleted) =
            depinNetwork.getNodeInfo(node1);

        assertEq(nodeName, "Node 1");
        assertTrue(isActive);
        assertEq(tasksCompleted, 0);
        assertTrue(registeredAt > 0);

        vm.stopPrank();
    }

    function testCannotRegisterNodeTwice() public {
        vm.startPrank(node1);

        depinNetwork.registerNode("Node 1");

        vm.expectRevert("Node already registered");
        depinNetwork.registerNode("Node 1 Again");

        vm.stopPrank();
    }

    function testAddTask() public {
        string memory question = "What is 2 + 2?";

        vm.expectEmit(true, false, false, true);
        emit TaskCreated(0, question, block.timestamp);

        uint256 taskId = depinNetwork.addTask(question);

        assertEq(taskId, 0);
        assertEq(depinNetwork.getTaskCount(), 1);

        (string memory q, string memory a, address assigned, bool completed,,) = depinNetwork.getTaskResult(taskId);

        assertEq(q, question);
        assertEq(a, "");
        assertEq(assigned, address(0));
        assertFalse(completed);
    }

    function testOnlyOwnerCanAddTask() public {
        vm.prank(node1);
        vm.expectRevert();
        depinNetwork.addTask("What is 2 + 2?");
    }

    function testAssignTask() public {
        // Register node
        vm.prank(node1);
        depinNetwork.registerNode("Node 1");

        // Add task
        uint256 taskId = depinNetwork.addTask("What is 2 + 2?");

        // Assign task
        vm.prank(node1);
        vm.expectEmit(true, true, false, true);
        emit TaskAssigned(taskId, node1, block.timestamp);

        depinNetwork.assignTask(taskId);

        (,, address assigned, bool completed,,) = depinNetwork.getTaskResult(taskId);
        assertEq(assigned, node1);
        assertFalse(completed);
    }

    function testOnlyActiveNodeCanAssignTask() public {
        uint256 taskId = depinNetwork.addTask("What is 2 + 2?");

        vm.prank(node1);
        vm.expectRevert("Only active nodes can take tasks");
        depinNetwork.assignTask(taskId);
    }

    function testCompleteTask() public {
        // Register node
        vm.startPrank(node1);
        depinNetwork.registerNode("Node 1");
        vm.stopPrank();

        // Add task
        uint256 taskId = depinNetwork.addTask("What is 2 + 2?");

        // Assign and complete task
        vm.startPrank(node1);
        depinNetwork.assignTask(taskId);

        string memory answer = "The answer is 4";

        vm.expectEmit(true, true, false, true);
        emit TaskCompleted(taskId, node1, answer, block.timestamp);

        depinNetwork.completeTask(taskId, answer);
        vm.stopPrank();

        // Verify task completion
        (, string memory a, address assigned, bool completed,,) = depinNetwork.getTaskResult(taskId);

        assertEq(a, answer);
        assertTrue(completed);
        assertEq(assigned, node1);

        // Verify node stats
        (,,, uint256 tasksCompleted) = depinNetwork.getNodeInfo(node1);
        assertEq(tasksCompleted, 1);
    }

    function testOnlyAssignedNodeCanCompleteTask() public {
        // Register nodes
        vm.prank(node1);
        depinNetwork.registerNode("Node 1");

        vm.prank(node2);
        depinNetwork.registerNode("Node 2");

        // Add and assign task to node1
        uint256 taskId = depinNetwork.addTask("What is 2 + 2?");

        vm.prank(node1);
        depinNetwork.assignTask(taskId);

        // Try to complete with node2
        vm.prank(node2);
        vm.expectRevert("Task not assigned to this node");
        depinNetwork.completeTask(taskId, "Answer");
    }

    function testCannotCompleteTaskTwice() public {
        // Register node
        vm.startPrank(node1);
        depinNetwork.registerNode("Node 1");
        vm.stopPrank();

        // Add and complete task
        uint256 taskId = depinNetwork.addTask("What is 2 + 2?");

        vm.startPrank(node1);
        depinNetwork.assignTask(taskId);
        depinNetwork.completeTask(taskId, "Answer 1");

        vm.expectRevert("Task already completed");
        depinNetwork.completeTask(taskId, "Answer 2");
        vm.stopPrank();
    }

    function testDeactivateNode() public {
        vm.startPrank(node1);
        depinNetwork.registerNode("Node 1");

        assertTrue(depinNetwork.isNodeActive(node1));

        depinNetwork.deactivateNode();

        assertFalse(depinNetwork.isNodeActive(node1));
        vm.stopPrank();
    }

    function testGetRegisteredNodes() public {
        vm.prank(node1);
        depinNetwork.registerNode("Node 1");

        vm.prank(node2);
        depinNetwork.registerNode("Node 2");

        address[] memory nodes = depinNetwork.getRegisteredNodes();
        assertEq(nodes.length, 2);
        assertEq(nodes[0], node1);
        assertEq(nodes[1], node2);
    }

    function testCannotRegisterNodeWithEmptyName() public {
        vm.prank(node1);
        vm.expectRevert("Node name cannot be empty");
        depinNetwork.registerNode("");
    }

    function testCannotDeactivateInactiveNode() public {
        vm.prank(node1);
        vm.expectRevert("Node not registered or already inactive");
        depinNetwork.deactivateNode();
    }

    function testCannotAddTaskWithEmptyQuestion() public {
        vm.expectRevert("Question cannot be empty");
        depinNetwork.addTask("");
    }

    function testCannotAssignNonExistentTask() public {
        vm.startPrank(node1);
        depinNetwork.registerNode("Node 1");

        vm.expectRevert("Task does not exist");
        depinNetwork.assignTask(999);
        vm.stopPrank();
    }

    function testCannotAssignCompletedTask() public {
        // Register node and create task
        vm.prank(node1);
        depinNetwork.registerNode("Node 1");

        uint256 taskId = depinNetwork.addTask("What is 1 + 1?");

        // Assign and complete task
        vm.startPrank(node1);
        depinNetwork.assignTask(taskId);
        depinNetwork.completeTask(taskId, "2");
        vm.stopPrank();

        // Try to assign completed task with another node
        vm.prank(node2);
        depinNetwork.registerNode("Node 2");

        vm.prank(node2);
        vm.expectRevert("Task already completed");
        depinNetwork.assignTask(taskId);
    }

    function testCannotAssignAlreadyAssignedTask() public {
        // Register two nodes
        vm.prank(node1);
        depinNetwork.registerNode("Node 1");

        vm.prank(node2);
        depinNetwork.registerNode("Node 2");

        uint256 taskId = depinNetwork.addTask("What is 1 + 1?");

        // Node 1 assigns task
        vm.prank(node1);
        depinNetwork.assignTask(taskId);

        // Node 2 tries to assign same task
        vm.prank(node2);
        vm.expectRevert("Task already assigned");
        depinNetwork.assignTask(taskId);
    }

    function testCannotCompleteNonExistentTask() public {
        vm.prank(node1);
        depinNetwork.registerNode("Node 1");

        vm.prank(node1);
        vm.expectRevert("Task does not exist");
        depinNetwork.completeTask(999, "answer");
    }

    function testCannotCompleteTaskWithEmptyAnswer() public {
        vm.prank(node1);
        depinNetwork.registerNode("Node 1");

        uint256 taskId = depinNetwork.addTask("What is 1 + 1?");

        vm.startPrank(node1);
        depinNetwork.assignTask(taskId);

        vm.expectRevert("Answer cannot be empty");
        depinNetwork.completeTask(taskId, "");
        vm.stopPrank();
    }

    function testCannotGetNonExistentTaskResult() public {
        vm.expectRevert("Task does not exist");
        depinNetwork.getTaskResult(999);
    }

    function testInactiveNodeCannotCompleteTask() public {
        // Register and assign task
        vm.prank(node1);
        depinNetwork.registerNode("Node 1");

        uint256 taskId = depinNetwork.addTask("What is 1 + 1?");

        vm.prank(node1);
        depinNetwork.assignTask(taskId);

        // Deactivate node
        vm.prank(node1);
        depinNetwork.deactivateNode();

        // Try to complete task
        vm.prank(node1);
        vm.expectRevert("Only active nodes can complete tasks");
        depinNetwork.completeTask(taskId, "2");
    }
}

