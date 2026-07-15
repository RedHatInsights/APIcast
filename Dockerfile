FROM registry.access.redhat.com/hi/core-runtime:2.42-openssl-fips-builder AS base

USER root

ARG OPENRESTY_RPM_VERSION="1.29.2.5-1.el9"
ARG LUAROCKS_VERSION="3.12.0"

LABEL summary="The 3scale API gateway (APIcast) is an OpenResty application, which consists of two parts: NGINX configuration and Lua files." \
      description="APIcast is not a standalone API gateway therefore it needs connection to the 3scale API management platform. The container includes OpenResty and uses LuaRocks to install dependencies (rocks are installed in the application folder)." \
      io.k8s.description="APIcast is not a standalone API gateway therefore it needs connection to the 3scale API management platform. The container includes OpenResty and uses LuaRocks to install dependencies (rocks are installed in the application folder)." \
      io.k8s.display-name="3scale API gateway (APIcast)" \
      io.openshift.expose-services="8080:apicast" \
      io.openshift.tags="integration, nginx, lua, openresty, api, gateway, 3scale, rhamp" \
      maintainer="3scale-engineering@redhat.com" \
      com.redhat.component="3scale-amp-apicast-gateway-container" \
      name="3scale-amp2/apicast-gateway-rhel9" \
      version="1.22.0" \
      vendor="Red Hat, Inc." \
      release="1" \
      url="https://github.com/3scale/APIcast" \
      distribution-scope="private"

WORKDIR /tmp

ENV AUTO_UPDATE_INTERVAL=0 \
    # The $HOME is not set by default, but some applications needs this variable
    HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH \
    PLATFORM="el9"

RUN dnf update -y --no-best

RUN dnf install -y dnf5-plugins

RUN dnf5 config-manager addrepo --from-repofile=http://packages.dev.3sca.net/dev_packages_3sca_net.repo

RUN dnf install -y --allowerasing --setopt=tsflags=nodocs \
        openresty-opentelemetry-${OPENRESTY_RPM_VERSION} \
        gzip \
        openssl-devel git gcc sed make tar \
        openresty-${OPENRESTY_RPM_VERSION} \
        luarocks-${LUAROCKS_VERSION} \
        opentracing-cpp-devel-1.3.0 \
        libopentracing-cpp1-1.3.0 \
        perl-interpreter && \
    mkdir -p "$HOME" && \
    dnf clean all -y

# Try to install jaegertracing if available (optional for Jaeger tracing support)
RUN dnf install -y --skip-unavailable jaegertracing-cpp-client || true

COPY site_config.lua /usr/share/lua/5.1/luarocks/site_config.lua
COPY config-*.lua /usr/local/openresty/config-5.1.lua

ENV PATH="./lua_modules/bin:/usr/local/openresty/luajit/bin/:${PATH}" \
    LUA_PATH="./lua_modules/share/lua/5.1/?.lua;./lua_modules/share/lua/5.1/?/init.lua;/usr/lib64/lua/5.1/?.lua;/usr/share/lua/5.1/?.lua" \
    LUA_CPATH="./lua_modules/lib/lua/5.1/?.so;;" \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/app-root/lib"

RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/pintsized/lua-resty-http-0.17.1-0.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/kikito/router-2.1-0.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/kikito/inspect-3.1.1-0.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/cdbattags/lua-resty-jwt-0.2.0-0.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/lua-resty-url-0.3.5-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/lua-resty-env-0.4.0-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/liquid-0.2.0-2.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/tieske/date-2.2-2.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/tieske/penlight-1.13.1-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/mpeterv/argparse-0.6.0-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/lua-resty-execvp-0.1.1-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/hisham/luafilesystem-1.8.0-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/lua-resty-jit-uuid-0.0.7-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/knyar/nginx-lua-prometheus-0.20181120-2.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/hamish/lua-resty-iputils-0.3.0-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/golgote/net-url-0.9-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/membphis/lua-resty-ipmatcher-0.6.1-0.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/fffonion/lua-resty-openssl-1.5.1-1.src.rock

RUN dnf -y remove --noautoremove openssl-devel git luarocks && \
    dnf -y autoremove && \
    rm -rf /var/cache/dnf && \
    dnf clean all -y && \
    rm -rf ./*

COPY gateway/. /opt/app-root/src/

RUN mkdir -p /opt/app-root/src/logs && \
    useradd -u 1001 -r -g 0 -d ${HOME} -s /sbin/nologin -c "Default Application User" default && \
    rm -r /usr/local/openresty/nginx/logs && \
    ln -s /opt/app-root/src/logs /usr/local/openresty/nginx/logs && \
    ln -s /dev/stdout /opt/app-root/src/logs/access.log && \
    ln -s /dev/stderr /opt/app-root/src/logs/error.log && \
    mkdir -p /usr/local/share/lua/ && \
    chmod g+w /usr/local/share/lua/ && \
    mkdir -p /usr/local/openresty/nginx/{client_body_temp,fastcgi_temp,proxy_temp,scgi_temp,uwsgi_temp} && \
    chown -R 1001:0 /opt/app-root /usr/local/share/lua/ /usr/local/openresty/nginx/{client_body_temp,fastcgi_temp,proxy_temp,scgi_temp,uwsgi_temp}

RUN ln --verbose --symbolic /opt/app-root/src/bin /opt/app-root/bin && \
    ln --verbose --symbolic /opt/app-root/src/http.d /opt/app-root/http.d && \
    ln --verbose --symbolic --force /etc/ssl/certs/ca-bundle.crt "/opt/app-root/src/conf" && \
    chmod --verbose g+w "${HOME}" "${HOME}"/* "${HOME}/http.d" && \
    chown -R 1001:0 /opt/app-root

RUN ln --verbose --symbolic /opt/app-root/src /opt/app-root/app && \
    ln --verbose --symbolic /opt/app-root/bin /opt/app-root/scripts

# Runtime
FROM registry.access.redhat.com/hi/core-runtime:2.42-openssl-fips

COPY --from=base /usr/local/openresty /usr/local/openresty
COPY --from=base /usr/local/share/lua /usr/local/share/lua
COPY --from=base /usr/local/lib64/lua /usr/local/lib64/lua
COPY --from=base /opt/app-root /opt/app-root
COPY --from=base /etc/passwd /etc/passwd
COPY --from=base /etc/group /etc/group

WORKDIR /opt/app-root/app

COPY --from=base /usr/bin/sed /usr/bin/sed
COPY --from=base /usr/bin/perl /usr/bin/perl
COPY --from=base /usr/share/perl5 /usr/share/perl5
COPY --from=base /usr/lib64/lua /usr/lib64/lua
COPY --from=base /usr/lib64/libcrypt.so.2* /usr/lib64/

USER 1001

ENV LUA_CPATH "./?.so;/usr/lib64/lua/5.1/?.so;/usr/lib64/lua/5.1/loadall.so;/usr/local/lib64/lua/5.1/?.so"
ENV LUA_PATH "/usr/lib64/lua/5.1/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/*/?.lua;;"
ENV PATH="/opt/app-root/bin:/opt/app-root/src/bin:/usr/local/openresty/bin:${PATH}"

WORKDIR /opt/app-root
ENTRYPOINT ["container-entrypoint"]
CMD ["scripts/run"]
