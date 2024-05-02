SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec
.DEFAULT_GOAL := gateway
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
WORKDIR := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
DOCKER ?= $(shell which docker 2> /dev/null || echo "docker")

gateway: ## run gateway configured to access plain HTTP 1.1 upstream
	$(DOCKER) compose -f docker-compose.yml up --attach gateway

clean:
	$(DOCKER) compose down --volumes --remove-orphans
	$(DOCKER) compose -f docker-compose.yml down --volumes --remove-orphans
