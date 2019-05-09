GO111MODULE ?= on
export GO111MODULE

DOCKER_BUILDKIT ?= 1
export DOCKER_BUILDKIT

ORG_PATH=github.com/Azure
PROJECT_NAME := aad-pod-identity
REPO_PATH="$(ORG_PATH)/$(PROJECT_NAME)"
NMI_BINARY_NAME := nmi
MIC_BINARY_NAME := mic
DEMO_BINARY_NAME := demo
IDENTITY_VALIDATOR_BINARY_NAME := identityvalidator

DEFAULT_VERSION := 0.0.0-dev
NMI_VERSION ?= $(DEFAULT_VERSION)
MIC_VERSION ?= $(DEFAULT_VERSION)
DEMO_VERSION ?= $(DEFAULT_VERSION)
IDENTITY_VALIDATOR_VERSION ?= $(DEFAULT_VERSION)

VERSION_VAR := $(REPO_PATH)/version.Version
GIT_VAR := $(REPO_PATH)/version.GitCommit
BUILD_DATE_VAR := $(REPO_PATH)/version.BuildDate
BUILD_DATE := $$(date +%Y-%m-%d-%H:%M)
GIT_HASH := $$(git rev-parse --short HEAD)

ifeq ($(OS),Windows_NT)
	GO_BUILD_MODE = default
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S), Linux)
		GO_BUILD_MODE = pie
	endif
	ifeq ($(UNAME_S), Darwin)
		GO_BUILD_MODE = default
	endif
endif

GO_BUILD_OPTIONS := --tags "netgo osusergo"  -ldflags "-s -X $(VERSION_VAR)=$(NMI_VERSION) -X $(GIT_VAR)=$(GIT_HASH) -X $(BUILD_DATE_VAR)=$(BUILD_DATE) -extldflags '-static'"
E2E_TEST_OPTIONS := -count=1 -v -timeout 24h -ginkgo.failFast

# useful for other docker repos
REGISTRY_NAME ?= upstreamk8sci
REGISTRY ?= $(REGISTRY_NAME).azurecr.io
REPO_PREFIX ?= k8s/aad-pod-identity
NMI_IMAGE ?= $(REPO_PREFIX)/$(NMI_BINARY_NAME):$(NMI_VERSION)
MIC_IMAGE ?= $(REPO_PREFIX)/$(MIC_BINARY_NAME):$(MIC_VERSION)
DEMO_IMAGE ?= $(REPO_PREFIX)/$(DEMO_BINARY_NAME):$(DEMO_VERSION)
IDENTITY_VALIDATOR_IMAGE ?= $(REPO_PREFIX)/$(IDENTITY_VALIDATOR_BINARY_NAME):$(IDENTITY_VALIDATOR_VERSION)

.PHONY: clean-nmi
clean-nmi:
	rm -rf bin/$(PROJECT_NAME)/$(NMI_BINARY_NAME)

.PHONY: clean-mic
clean-mic:
	rm -rf bin/$(PROJECT_NAME)/$(MIC_BINARY_NAME)

.PHONY: clean-demo
clean-demo:
	rm -rf bin/$(PROJECT_NAME)/$(DEMO_BINARY_NAME)

.PHONY: clean-idenityvalidator
clean-identityvalidator:
	rm -rf bin/$(PROJECT_NAME)/$(IDENTITY_VALIDATOR_BINARY_NAME)

.PHONY: clean
clean:
	rm -rf bin/$(PROJECT_NAME)

.PHONY: build-nmi
build-nmi: clean-nmi
	CGO_ENABLED=0 PKG_NAME=github.com/Azure/$(PROJECT_NAME)/cmd/$(NMI_BINARY_NAME) $(MAKE) bin/$(PROJECT_NAME)/$(NMI_BINARY_NAME)

.PHONY: build-mic
build-mic: clean-mic
	CGO_ENABLED=0 PKG_NAME=github.com/Azure/$(PROJECT_NAME)/cmd/$(MIC_BINARY_NAME) $(MAKE) bin/$(PROJECT_NAME)/$(MIC_BINARY_NAME)

.PHONY: build-demo
build-demo: build_tags := netgo osusergo
build-demo: clean-demo
	PKG_NAME=github.com/Azure/$(PROJECT_NAME)/cmd/$(DEMO_BINARY_NAME) ${MAKE} bin/$(PROJECT_NAME)/$(DEMO_BINARY_NAME)

bin/%:
	GOOS=linux GOARCH=amd64 go build $(GO_BUILD_OPTIONS) -o "$(@)" "$(PKG_NAME)"

.PHONY: build-identityvalidator
build-identityvalidator: clean-identityvalidator
	PKG_NAME=github.com/Azure/$(PROJECT_NAME)/test/e2e/$(IDENTITY_VALIDATOR_BINARY_NAME) $(MAKE) bin/$(PROJECT_NAME)/$(IDENTITY_VALIDATOR_BINARY_NAME)

.PHONY: build
build: clean build-nmi build-mic build-demo build-identityvalidator

.PHONY: deepcopy-gen
deepcopy-gen:
	deepcopy-gen -i ./pkg/apis/aadpodidentity/v1/ -o ../../../ -O aadpodidentity_deepcopy_generated -p aadpodidentity

.PHONY: image-nmi
image-nmi:
	docker build -t "$(REGISTRY)/$(NMI_IMAGE)" --build-arg NMI_VEARSION="$(NMI_VERSION)" --target=nmi .

.PHONY: image-mic
image-mic:
	docker build -t "$(REGISTRY)/$(MIC_IMAGE)" --build-arg MIC_VERSION="$(MIC_VERSION)" --target=mic .

.PHONY: image-demo
image-demo:
	docker build -t $(REGISTRY)/$(DEMO_IMAGE) --build-arg DEMO_VERSION="$(DEMO_VERSION)" --target=demo .

.PHONY: image-identityvalidator
image-identityvalidator:
	docker build -t $(REGISTRY)/$(IDENTITY_VALIDATOR_IMAGE) --build-arg IDENTITY_VALIDATOR_VERSION="$(IDENTITY_VALIDATOR_VERSION)" --target=identityvalidator .

.PHONY: image
image: image-nmi image-mic image-demo image-identityvalidator

.PHONY: push-nmi
push-nmi: validate-version-NMI validate-image-nmi-not-exists
	docker push $(REGISTRY)/$(NMI_IMAGE)

.PHONY: push-mic
push-mic: validate-version-MIC validate-image-mic-not-exists
	docker push $(REGISTRY)/$(MIC_IMAGE)

.PHONY: validate-image-mic-not-exists
validate-image-mic-not-exists:
	az acr repository show --name $(REGISTRY_NAME) --image $(MIC_IMAGE) > /dev/null 2>&1 || exit 0; \
	echo $(MIC_IMAGE) already exists
	false

.PHONY: validate-image-nmi-not-exists
validate-image-nmi-not-exists:
	az acr repository show --name $(REGISTRY_NAME) --image $(NMI_IMAGE) > /dev/null 2>&1 || exit 0; \
	echo "$(NMI_IMAGE) already exists"; \
	false

.PHONY: push-demo
push-demo: validate-version-DEMO
	docker push $(REGISTRY)/$(DEMO_IMAGE)


.PHONY: validate-image-identityvalidator-not-exists
validate-image-nmi-not-exists:
	az acr repository show --name $(REGISTRY_NAME) --image $(IDENTITY_VALIDATOR_IMAGE) > /dev/null 2>&1 || exit 0; \
	echo "$(IDENTIY_VALIDATOR_IMAGE) already exists"; \
	false

.PHONY: push-identityvalidator
push-identityvalidator: validate-version-IDENTITY_VALIDATOR validate-image-identityvalidator-not-exists
	docker push $(REGISTRY)/$(IDENTITY_VALIDATOR_IMAGE)

.PHONY: push
push: push-nmi push-mic push-demo push-identityvalidator

.PHONY: e2e
e2e:
	go test github.com/Azure/$(PROJECT_NAME)/test/e2e $(E2E_TEST_OPTIONS)

.PHONY: unit-test
unit-test:
	go test $(shell go list ./... | grep -v /test/e2e) -v

.PHONY: validate-version
validate-version: validate-version-NMI validate-version-MIC validate-version-IDENTITY_VALIDATOR validate-version-DEMO

.PHONY: validate-version-%
validate-version-%:
	@echo $(*)_VERSION=$($(*)_VERSION)
	@DEFAULT_VERSION=$(DEFAULT_VERSION) CHECK_VERSION="$($(*)_VERSION)" scripts/validate_version.sh

.PHONY: mod
mod:
	@go mod tidy

.PHONY: check-vendor
check-mod: mod
	@git diff --exit-code go.mod go.sum
