-include .env

.PHONY: clean build test testCoverage testCoverageReport deployMockToken deploy

clean:
	rm -rf cache/ \
		artifacts/ \
		out/ \
		coverage/
	 forge clean

build:
	forge build

test:
	forge test

testCoverage:
	forge coverage --no-match-coverage '^(script|test)/'

testCoverageReport: 
	forge coverage --no-match-coverage '^(script|test)/' --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage

deployMockToken:
	make clean && \
	make build && \
	forge script \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		script/deployERC20Mock.s.sol:DeployERC20Mock --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

deploy:
	forge script script/DeployDePINNetwork.s.sol:DeployDePINNetwork \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast

# Control Plane Commands
.PHONY: cp-setup cp-up cp-down cp-logs cp-build cp-restart

cp-setup:
	./setup-control-plane.sh

cp-up:
	docker-compose up -d

cp-down:
	docker-compose down

cp-down-volumes:
	docker-compose down -v

cp-logs:
	docker-compose logs -f

cp-logs-control:
	docker-compose logs -f control-plane

cp-logs-rabbitmq:
	docker-compose logs -f rabbitmq

cp-build:
	docker-compose build

cp-restart:
	docker-compose restart

# Node Management
.PHONY: node-add node-remove node-list

node-add:
	@echo "Usage: make node-add NUM=3 KEY=0xYourPrivateKey"
	@if [ -z "$(NUM)" ] || [ -z "$(KEY)" ]; then \
		echo "Error: NUM and KEY are required"; \
		exit 1; \
	fi
	./add-node.sh $(NUM) $(KEY)

node-remove:
	@echo "Usage: make node-remove NUM=3"
	@if [ -z "$(NUM)" ]; then \
		echo "Error: NUM is required"; \
		exit 1; \
	fi
	./remove-node.sh $(NUM)

node-list:
	./list-nodes.sh

# Development
.PHONY: dev-up dev-down dev-logs

dev-up:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

dev-down:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

dev-logs:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

# Install dependencies
.PHONY: install-deps

install-deps:
	cd control-plane && npm install
	cd listener && npm install

