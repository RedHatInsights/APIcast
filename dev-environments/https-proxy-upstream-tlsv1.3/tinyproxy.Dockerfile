FROM alpine:3@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

LABEL summary="Forward proxy based on tinyproxy for development purposes" \
      description="Forward proxy based on tinyproxy for development purposes" \
      io.k8s.description="Forward proxy based on tinyproxy for development purposes" \
      io.k8s.display-name="Forward Proxy (Tinyproxy)" \
      io.openshift.tags="tinyproxy, proxy" \
      maintainer="3scale-engineering@redhat.com"

RUN apk --no-cache add tinyproxy
ENTRYPOINT ["/usr/bin/tinyproxy"]
CMD ["-d"]
