# TokenMinds Solidity Template

Fill project description here.

## Introduction

Fill project introduction here

## Features

Fill project features here.

## Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/)
- [Make](https://www.gnu.org/software/make/)

### Setup Instructions

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd smart-contract
   ```

2. **Install dependencies**

   ```bash
   # Install Foundry dependencies
   forge install
   ```

3. **Install Foundry submodules**
   ```bash
   git submodule update --init --recursive
   ```

## Configuration

### Environment Setup

1. **Copy the environment template**

   ```bash
   cp .env.example .env
   ```

2. **Fill in the environment variables**

## Usage

### Development Commands

#### Building

```bash
# Clean and build contracts
make clean
make build

# Or use Foundry directly
forge build
```

#### Testing

```bash
# Run all tests
make test

# Run tests with gas reporting
forge test --gas-report

# Run specific test file
forge test --match-path test/w3gg.t.sol
```

#### Coverage

```bash
# Generate coverage report
make testCoverage

# Generate HTML coverage report
make testCoverageReport
```

#### Code Formatting

```bash
forge fmt
```

### Deployment

#### Deploy Mock Token (for testing)

```bash
make deployMockToken
```

## Project Structure

```
smart-contract/
├── src/                          # Smart contract source code
│   └── erc20mock.sol           # Mock ERC20 for testing
├── script/                      # Deployment scripts
│   └── deployERC20Mock.sol       # Deploy ERC20 mock
├── test/                        # Test files
│   └── token.t.sol             # Token-related tests
├── coverage/                    # Coverage reports
├── foundry.toml                 # Foundry configuration
├── Makefile                     # Deployment automation
```

## Development Tools

- **Foundry**: Smart contract development framework
- **VS Code**: Recommended IDE with Solidity extensions

## License

MIT License - see the [LICENSE](LICENSE) file for details.
