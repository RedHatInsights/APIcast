SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec
.DEFAULT_GOAL := gateway
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
WORKDIR := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
DOCKER ?= $(shell which docker 2> /dev/null || echo "docker")

gateway: ## run gateway configured to access upstream powered with TLS
	$(DOCKER) compose -f docker-compose.yml up --attach gateway

clean:
	$(DOCKER) compose down --volumes --remove-orphans
	$(DOCKER) compose -f docker-compose.yml down --volumes --remove-orphans
	- rm -rf gateway-cert
	- rm -rf upstream-cert
	- rm -rf bin

ca:
	openssl genrsa -out rootCA.key 2048
	openssl req -batch -new -x509 -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.pem

clientcerts:
	openssl req -subj '/CN=$(DOMAIN)'  -newkey rsa:4096 -nodes \
			-sha256 \
			-days 3650 \
			-keyout $(DOMAIN).key \
			-out $(DOMAIN).csr
	chmod +r $(DOMAIN).key
	openssl x509 -req -in $(DOMAIN).csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out $(DOMAIN).crt -days 500 -sha256

$(WORKDIR)/gateway-cert:
	mkdir -p gateway-cert

.PHONY: gateway-certs
gateway-certs: $(WORKDIR)/gateway-cert
	$(MAKE) ca -C $(WORKDIR)/gateway-cert -f $(WORKDIR)/Makefile
	$(MAKE) clientcerts -C $(WORKDIR)/gateway-cert -f $(WORKDIR)/Makefile DOMAIN=gateway.example.com

$(WORKDIR)/upstream-cert:
	mkdir -p upstream-cert

.PHONY: upstream-certs
upstream-certs: $(WORKDIR)/upstream-cert
	$(MAKE) ca -C $(WORKDIR)/upstream-cert -f $(WORKDIR)/Makefile
	$(MAKE) clientcerts -C $(WORKDIR)/upstream-cert -f $(WORKDIR)/Makefile DOMAIN=upstream.example.com
	cat $(WORKDIR)/upstream-cert/upstream.example.com.key $(WORKDIR)/upstream-cert/upstream.example.com.crt >$(WORKDIR)/upstream-cert/upstream.example.com.pem

GRPCURL=$(WORKDIR)/bin/grpcurl
$(GRPCURL):
	$(call go-install-tool,$(GRPCURL),github.com/fullstorydev/grpcurl/cmd/grpcurl@v1.8.9)

.PHONY: grpcurl
grpcurl: $(GRPCURL) ## Download grpcurl locally if necessary.

# go-install-tool will 'go install' any package $2 and install it to $1.
define go-install-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo "Downloading $(2)" ;\
GOBIN=$(WORKDIR)/bin go install $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef
