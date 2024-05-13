#!/bin/bash

export IMAGE_TAG="apicast-base:pr-check"

function teardown_podman() {
    podman image rm -f $IMAGE_TAG || true
}

# Catches process termination and cleans up podman artifacts
trap "teardown_podman" EXIT SIGINT SIGTERM

set -ex

# Build PR_CHECK Image
podman login -u="$QUAY_USER" -p="$QUAY_TOKEN" quay.io
podman build --pull --no-cache --force-rm -f ./Dockerfile  -t ${IMAGE_TAG} .

# Pass Jenkins dummy artifacts as it needs
# an xml output to consider the job a success.
# Comment out the code below if running locally
mkdir -p $WORKSPACE/artifacts
cat << EOF > $WORKSPACE/artifacts/junit-dummy.xml
<testsuite tests="1">
    <testcase classname="dummy" name="dummytest"/>
</testsuite>
EOF
