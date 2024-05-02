SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec
.DEFAULT_GOAL := gateway
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
WORKDIR := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
DOCKER ?= $(shell which docker 2> /dev/null || echo "docker")

gateway: ## run gateway configured to keycloak integration
	$(DOCKER) compose -f docker-compose.yml up --attach gateway

keycloak-data: ## Keycloak provisioning
	# Keycloak 23.0.4 REST API reference
	# https://www.keycloak.org/docs-api/23.0.4/rest-api/
	# Init CLI authenticated session
	$(DOCKER) compose -p keycloak-env exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
		--server http://127.0.0.1:8080 --realm master --user admin --password adminpass
	# realm basic
	$(DOCKER) compose -p keycloak-env exec keycloak /opt/keycloak/bin/kcadm.sh create realms \
		--server http://127.0.0.1:8080 \
		-s realm=basic \
		-s enabled=true
	# Issuer client (only used because it is being configured in the oidc_issuer_endpoint property)
	$(DOCKER) compose -p keycloak-env exec keycloak /opt/keycloak/bin/kcadm.sh create clients \
		-r basic \
		--server http://127.0.0.1:8080 \
		-s clientId=oidc-issuer-for-3scale \
		-s enabled=true \
		-s protocol=openid-connect \
		-s publicClient=false \
		-s standardFlowEnabled=false \
		-s directAccessGrantsEnabled=false \
		-s serviceAccountsEnabled=true \
		-s clientAuthenticatorType=client-secret \
		-s secret=oidc-issuer-for-3scale-secret
	# client my-client
	$(DOCKER) compose -p keycloak-env exec keycloak /opt/keycloak/bin/kcadm.sh create clients \
		-r basic \
		--server http://127.0.0.1:8080 \
		-s clientId=my-client \
		-s enabled=true \
		-s protocol=openid-connect \
		-s publicClient=true \
		-s directAccessGrantsEnabled=true \
		-s clientAuthenticatorType=client-secret \
		-s secret=my-client-secret
	# user bob
	$(DOCKER) compose -p keycloak-env exec keycloak /opt/keycloak/bin/kcadm.sh create users \
		--server http://127.0.0.1:8080 \
		-r basic \
		-s enabled=true \
		-s emailVerified=true \
		-s username=bob
	# user bob credentials
	$(DOCKER) compose -p keycloak-env exec keycloak /opt/keycloak/bin/kcadm.sh set-password \
		-r basic \
		--admin-root http://127.0.0.1:8080/admin \
		--username bob \
		--new-password bobpass

token: ## User bob gets token. Requires `curl` and `jq` installed
# Do not indent these comments below. This make target is used as
# export ACCESS_TOKEN=$(make token)
# If indented, make will echo the comments
# Token is requested from the APIcast container to get a token with correct issuer
# "iss": "http://keycloak:8080/realms/basic"
# Requesting the token from localhost outside docker compose would lead to
# oidc.lua:203: verify(): [jwt] failed verification for token, reason: Claim 'iss' ('http://127.0.0.1:9090/realms/basic') returned failure
	@$(DOCKER) compose -p keycloak-env exec gateway curl -H "Content-Type: application/x-www-form-urlencoded" \
		-d 'grant_type=password' \
		-d 'client_id=my-client' \
		-d 'username=bob' \
		-d 'password=bobpass' "http://keycloak:8080/realms/basic/protocol/openid-connect/token" | jq -r '.access_token'

clean:
	$(DOCKER) compose down --volumes --remove-orphans
	$(DOCKER) compose -f docker-compose.yml down --volumes --remove-orphans
