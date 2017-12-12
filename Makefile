.DEFAULT_GOAL := all

OS := $(shell uname)

DOCKERFILE_MD5SUM=$(shell md5sum ./Dockerfile | cut -d" " -f1)
DEV_DOCKER_IMAGE := csilvm_dev:$(DOCKERFILE_MD5SUM)

ifeq ($(OS), Linux)
DOCKER ?= yes
else ifeq ($(OS), Darwin)
  ifeq ($(MAKECMDGOALS), check)
  DOCKER ?= yes
  else
  DOCKER ?= no
  endif
else
$(error Unsupported OS '$(OS)')
endif

.DEFAULT_GOAL := all

.PHONY: dev-image build check all clean shell rebuild-dev-image gofmt

rebuild-dev-image:
	docker build --rm -t $(DEV_DOCKER_IMAGE) .

dev-image:
	docker inspect $(DEV_DOCKER_IMAGE) &> /dev/null || docker build --rm -t $(DEV_DOCKER_IMAGE) .

ifeq ($(DOCKER), yes)
TEST_PREFIX := docker run --rm $(DEV_DOCKER_IMAGE)
BUILD_PREFIX := docker run --rm -v `pwd`:/go/src/github.com/mesosphere/csilvm $(DEV_DOCKER_IMAGE)
PRIVILEGED_BUILD_PREFIX := docker run --rm --ipc=host --privileged -v /run:/run -v /tmp:/tmp --net=host -v /dev:/dev -ti -v `pwd`:/go/src/github.com/mesosphere/csilvm $(DEV_DOCKER_IMAGE)

build: dev-image
check: dev-image
gofmt: dev-image
sudo-test: dev-image
shell: dev-image
endif

check:
	$(BUILD_PREFIX) sh -c "go build -v ./... && gometalinter --config=gometalinter.conf --vendor ./..."

build:
	$(BUILD_PREFIX) go build ./cmd/csilvm

gofmt:
	$(BUILD_PREFIX) sh -c "find pkg -name '*.go' | xargs gofmt -s -w"
	$(BUILD_PREFIX) sh -c "find cmd -name '*.go' | xargs gofmt -s -w"

all: build

.PHONY: sudo-test
sudo-test:
	$(PRIVILEGED_BUILD_PREFIX) sh -c "go test -c -i ./pkg/lvm && ./lvm.test -test.v"
	$(PRIVILEGED_BUILD_PREFIX) sh -c "go test -c -i ./pkg/csilvm && ./csilvm.test -test.v"

shell:
	$(PRIVILEGED_BUILD_PREFIX) /bin/bash
