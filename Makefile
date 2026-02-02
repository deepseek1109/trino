.PHONY: build image tests

# Dynamic version: Maven version + 7-char commit hash (e.g., 480-SNAPSHOT-fced032)
TRINO_VERSION := $(shell ./mvnw help:evaluate -Dexpression=project.version -q -DforceStdout --raw-streams 2>/dev/null)-$(shell git rev-parse --short=7 HEAD)
DOCKER_DIR := core/docker
PYTHON_TESTS_DIR := tests/python

build: ## Build Trino from source
	./mvnw clean install -DskipTests -pl '!docs' -q
	@echo "✓ Build complete: core/trino-server/target/trino-server-$(TRINO_VERSION).tar.gz"

image: ## Build Docker image with your changes (runs build if needed)
	@if [ ! -f "core/trino-server/target/trino-server-$(TRINO_VERSION).tar.gz" ]; then \
		echo "Building from source first..."; \
		$(MAKE) build; \
	fi
	@cd $(DOCKER_DIR) && ./build.sh -t trino -x
	@echo "✓ Image ready: trino:$(TRINO_VERSION)"

tests: ## Run Python tests against deployed Trino
	@python3 -m pytest $(PYTHON_TESTS_DIR) -v --tb=short 2>/dev/null || \
		(echo "Tests not found. Creating sample tests..."; \
		 mkdir -p $(PYTHON_TESTS_DIR); \
		 pip install -q trino pytest; \
		 echo "Add your tests to $(PYTHON_TESTS_DIR)/"; \
		 exit 1)
