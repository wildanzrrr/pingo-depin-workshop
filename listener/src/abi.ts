export const DePINNetworkABI = [
  {
    type: "constructor",
    inputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "registerNode",
    inputs: [
      {
        name: "_nodeName",
        type: "string",
        internalType: "string",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "deactivateNode",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "addTask",
    inputs: [
      {
        name: "_question",
        type: "string",
        internalType: "string",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "assignTask",
    inputs: [
      {
        name: "_taskId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "completeTask",
    inputs: [
      {
        name: "_taskId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "_answer",
        type: "string",
        internalType: "string",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "getTaskResult",
    inputs: [
      {
        name: "_taskId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "question",
        type: "string",
        internalType: "string",
      },
      {
        name: "answer",
        type: "string",
        internalType: "string",
      },
      {
        name: "assignedNode",
        type: "address",
        internalType: "address",
      },
      {
        name: "isCompleted",
        type: "bool",
        internalType: "bool",
      },
      {
        name: "createdAt",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "completedAt",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isNodeActive",
    inputs: [
      {
        name: "_nodeAddress",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getNodeInfo",
    inputs: [
      {
        name: "_nodeAddress",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "nodeName",
        type: "string",
        internalType: "string",
      },
      {
        name: "isActive",
        type: "bool",
        internalType: "bool",
      },
      {
        name: "registeredAt",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "tasksCompleted",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getRegisteredNodes",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address[]",
        internalType: "address[]",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getTaskCount",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "owner",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "event",
    name: "NodeRegistered",
    inputs: [
      {
        name: "nodeAddress",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "nodeName",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "timestamp",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "NodeDeactivated",
    inputs: [
      {
        name: "nodeAddress",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "timestamp",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "TaskCreated",
    inputs: [
      {
        name: "taskId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "question",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "timestamp",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "TaskAssigned",
    inputs: [
      {
        name: "taskId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "nodeAddress",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "timestamp",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "TaskCompleted",
    inputs: [
      {
        name: "taskId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "nodeAddress",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "answer",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "timestamp",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
] as const;
