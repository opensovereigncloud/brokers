# Image URL to use all building/pushing image targets
MACHINEBROKER_IMG ?= machinebroker:latest
VOLUMEBROKER_IMG ?= volumebroker:latest
BUCKETBROKER_IMG ?= bucketbroker:latest

# LDFLAGS for the build targets
LDFLAGS ?= -s -w
VERSION=$(shell git describe --tags --abbrev=0)
COMMIT=$(shell git log -n1 --format="%h")
MACHINEBROKER_VERSION = github.com/ironcore-dev/brokers/machinebroker/version.Version
MACHINEBROKER_COMMIT = github.com/ironcore-dev/brokers/machinebroker/version.Commit
VOLUMEBROKER_VERSION = github.com/ironcore-dev/brokers/volumebroker/version.Version
VOLUMEBROKER_COMMIT = github.com/ironcore-dev/brokers/volumebroker/version.Commit
BUCKETBROKER_VERSION = github.com/ironcore-dev/brokers/bucketbroker/version.Version
BUCKETBROKER_COMMIT = github.com/ironcore-dev/brokers/bucketbroker/version.Commit

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# Setting SHELL to bash allows bash commands to be executed by recipes.
# This is a requirement for 'setup-envtest.sh' in the test target.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

.PHONY: all
all: build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

.PHONY: fmt
fmt: goimports ## Run goimports against code.
	$(GOIMPORTS) -w .

.PHONY: vet
vet: ## Run go vet against code.
	go vet ./...

.PHONY: lint
lint: golangci-lint ## Run golangci-lint on the code.
	$(GOLANGCI_LINT) run ./...

.PHONY: add-license
add-license: addlicense ## Add license headers to all go files.
	find . -name '*.go' -exec $(ADDLICENSE) -f hack/license-header.txt {} +

.PHONY: check-license
check-license: addlicense ## Check that every file has a license header present.
	find . -name '*.go' -exec $(ADDLICENSE) -check -c 'IronCore authors' {} +

.PHONY: check
check: add-license fmt lint test # Add licenses, lint and test.

.PHONY: test
test: fmt vet test-only ## Run tests.

.PHONY: test-only
test-only: envtest ## Run *only* the tests - no generation, linting etc.
	KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) --bin-dir $(LOCALBIN) -p path)" go test ./... -coverprofile cover.out

##@ Build

.PHONY: build
build: fmt vet ## Build broker binaries.
	go build -ldflags="${LDFLAGS} -X $(MACHINEBROKER_VERSION)=$(VERSION) -X $(MACHINEBROKER_COMMIT)=$(COMMIT)" -o bin/machinebroker ./machinebroker/cmd/machinebroker
	go build -ldflags="${LDFLAGS} -X $(VOLUMEBROKER_VERSION)=$(VERSION) -X $(VOLUMEBROKER_COMMIT)=$(COMMIT)" -o bin/volumebroker ./volumebroker/cmd/volumebroker
	go build -ldflags="${LDFLAGS} -X $(BUCKETBROKER_VERSION)=$(VERSION) -X $(BUCKETBROKER_COMMIT)=$(COMMIT)" -o bin/bucketbroker ./bucketbroker/cmd/bucketbroker

.PHONY: docker-build
docker-build: docker-build-machinebroker docker-build-volumebroker docker-build-bucketbroker ## Build docker images for all brokers.

.PHONY: docker-build-machinebroker
docker-build-machinebroker: ## Build machinebroker image.
	docker build --build-arg LDFLAGS="${LDFLAGS} -X $(MACHINEBROKER_VERSION)=$(VERSION) -X $(MACHINEBROKER_COMMIT)=$(COMMIT)" --target machinebroker -t ${MACHINEBROKER_IMG} .

.PHONY: docker-build-volumebroker
docker-build-volumebroker: ## Build volumebroker image.
	docker build --build-arg LDFLAGS="${LDFLAGS} -X $(VOLUMEBROKER_VERSION)=$(VERSION) -X $(VOLUMEBROKER_COMMIT)=$(COMMIT)" --target volumebroker -t ${VOLUMEBROKER_IMG} .

.PHONY: docker-build-bucketbroker
docker-build-bucketbroker: ## Build bucketbroker image.
	docker build --build-arg LDFLAGS="${LDFLAGS} -X $(BUCKETBROKER_VERSION)=$(VERSION) -X $(BUCKETBROKER_COMMIT)=$(COMMIT)" --target bucketbroker -t ${BUCKETBROKER_IMG} .

.PHONY: docker-push
docker-push: ## Push docker images for all brokers.
	docker push ${MACHINEBROKER_IMG}
	docker push ${VOLUMEBROKER_IMG}
	docker push ${BUCKETBROKER_IMG}

##@ Tools

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Tool Binaries
ENVTEST ?= $(LOCALBIN)/setup-envtest
ADDLICENSE ?= $(LOCALBIN)/addlicense
GOIMPORTS ?= $(LOCALBIN)/goimports
GOLANGCI_LINT ?= $(LOCALBIN)/golangci-lint

## Tool Versions
#ENVTEST_VERSION is the version of controller-runtime release branch to fetch the envtest setup script (i.e. release-0.20)
ENVTEST_VERSION ?= $(shell go list -m -f "{{ .Version }}" sigs.k8s.io/controller-runtime | awk -F'[v.]' '{printf "release-%d.%d", $$2, $$3}')
#ENVTEST_K8S_VERSION is the version of Kubernetes to use for setting up ENVTEST binaries (i.e. 1.31)
ENVTEST_K8S_VERSION ?= $(shell go list -m -f "{{ .Version }}" k8s.io/api | awk -F'[v.]' '{printf "1.%d.%d",$$3, $$2}')

ADDLICENSE_VERSION ?= v1.1.1
GOIMPORTS_VERSION ?= v0.41.0
GOLANGCI_LINT_VERSION ?= v2.13

.PHONY: envtest
envtest: $(ENVTEST) ## Download envtest-setup locally if necessary.
$(ENVTEST): $(LOCALBIN)
	$(call go-install-tool,$(ENVTEST),sigs.k8s.io/controller-runtime/tools/setup-envtest,$(ENVTEST_VERSION))

.PHONY: addlicense
addlicense: $(ADDLICENSE) ## Download addlicense locally if necessary.
$(ADDLICENSE): $(LOCALBIN)
	$(call go-install-tool,$(ADDLICENSE),github.com/google/addlicense,$(ADDLICENSE_VERSION))

.PHONY: goimports
goimports: $(GOIMPORTS) ## Download goimports locally if necessary.
$(GOIMPORTS): $(LOCALBIN)
	$(call go-install-tool,$(GOIMPORTS),golang.org/x/tools/cmd/goimports,$(GOIMPORTS_VERSION))

.PHONY: golangci-lint
golangci-lint: $(GOLANGCI_LINT) ## Download golangci-lint locally if necessary.
$(GOLANGCI_LINT): $(LOCALBIN)
	$(call go-install-tool,$(GOLANGCI_LINT),github.com/golangci/golangci-lint/v2/cmd/golangci-lint,$(GOLANGCI_LINT_VERSION))

# go-install-tool will 'go install' any package with custom target and name of binary, if it doesn't exist
# $1 - target path with name of binary
# $2 - package url which can be installed
# $3 - specific version of package
define go-install-tool
@[ -f "$(1)-$(3)" ] && [ "$$(readlink -- "$(1)" 2>/dev/null)" = "$(1)-$(3)" ] || { \
set -e; \
package=$(2)@$(3) ;\
echo "Downloading $${package}" ;\
rm -f $(1) ;\
GOBIN=$(LOCALBIN) go install $${package} ;\
mv $(1) $(1)-$(3) ;\
} ;\
ln -sf $$(realpath $(1)-$(3)) $(1)
endef
