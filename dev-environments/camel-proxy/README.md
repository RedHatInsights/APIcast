# Camel PROXY

Development environment to test integration between APIcast and proxies built
on top of [Camel framework](https://camel.apache.org/components/4.0.x/netty-http-component.html)

This dev environment uses [Camel Netty Proxy example](https://github.com/zregvart/camel-netty-proxy).
Any request that is received using the HTTP PROXY protocol,
i.e specifying the absolute form for the request target will be forwarded to the
target service with the HTTP body converted to uppercase.

Both `http_proxy` and `https_proxy` scenarios are setup.

`http_proxy` use case: APIcast --> camel "uppercase" proxy --> upstream (plain HTTP/1.1)

`https_proxy` use case: APIcast --> camel "uppercase" proxy --> upstream (TLS)

## Create the SSL Certificates

```sh
make certs
```

## Run the gateway

Running local `apicast-test` docker image

```sh
make gateway
```

Running custom apicast image

```sh
make gateway IMAGE_NAME=quay.io/3scale/apicast:latest
```

## Testing `http_proxy` use case: APIcast --> camel proxy --> upstream (plain HTTP/1.1)

```sh
curl --resolve http-proxy.example.com:8080:127.0.0.1 -v "http://http-proxy.example.com:8080/?user_key=123"
```

Expected result:

<details>

```
 Added http-proxy.example.com:8080:127.0.0.1 to DNS cache
* Hostname http-proxy.example.com was found in DNS cache
*   Trying 127.0.0.1:8080...
* Connected to http-proxy.example.com (127.0.0.1) port 8080 (#0)
> GET /?user_key=123 HTTP/1.1
> Host: http-proxy.example.com:8080
> User-Agent: curl/7.81.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Server: openresty
< Date: Fri, 02 Feb 2024 10:12:56 GMT
< Content-Type: application/json
< Content-Length: 254
< Connection: keep-alive
< Access-Control-Allow-Credentials: true
< Access-Control-Allow-Origin: *
<
{
  "ARGS": {
    "USER_KEY": "123"
  },
  "HEADERS": {
    "ACCEPT": "*/*",
    "CONNECTION": "KEEP-ALIVE",
    "HOST": "EXAMPLE.COM",
    "USER-AGENT": "CURL/7.81.0"
  },
  "ORIGIN": "172.21.0.2",
  "URL": "HTTP://EXAMPLE.COM/GET?USER_KEY=123"
}
* Connection #0 to host http-proxy.example.com left intact
```

</details>

Traffic between APIcast and the camel proxy can be inspected looking at logs from `proxy.socat` service

```
docker compose -p camel-proxy logs -f proxy.socat
```

Traffic between the camel proxy and upstream can be inspected looking at logs from `example.com` service

```
docker compose -p camel-proxy logs -f example.com
```

Camel proxy can be inspected looking at logs from `camel.proxy` service

```
docker compose -p camel-proxy logs -f camel.proxy
```

## Testing `https_proxy` use case: APIcast --> camel proxy --> upstream (TLS)

> TLS Upstream based on service with trusted (well known) CA certificate. `https://echo-api.3scale.net:443`

> Failed trying to setup connection between camel proxy and service with self-signed cert.

> TODO: upstream service running in docker compose env with a self signed cert and import that self signed certificate in the java keystore to be validated by camel.

```sh
curl --resolve https-proxy.example.com:8080:127.0.0.1 -v "http://https-proxy.example.com:8080/?user_key=123"
```

Expected result:

<details>

```
* Added https-proxy.example.com:8080:127.0.0.1 to DNS cache
* Hostname https-proxy.example.com was found in DNS cache
*   Trying 127.0.0.1:8080...
* Connected to https-proxy.example.com (127.0.0.1) port 8080 (#0)
> GET /?user_key=123 HTTP/1.1
> Host: https-proxy.example.com:8080
> User-Agent: curl/7.81.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Date: Fri, 02 Feb 2024 10:17:33 GMT
< Content-Type: application/json
< Transfer-Encoding: chunked
< Connection: keep-alive
< x-envoy-upstream-service-time: 0
< vary: Origin
< x-3scale-echo-api: echo-api/1.0.3
< x-content-type-options: nosniff
< server: envoy
<
{
  "METHOD": "GET",
  "PATH": "/",
  "ARGS": "USER_KEY=123",
  "BODY": "",
  "HEADERS": {
    "HTTP_VERSION": "HTTP/1.1",
    "HTTP_HOST": "ECHO-API.3SCALE.NET:443",
    "HTTP_ACCEPT": "*/*",
    "HTTP_USER_AGENT": "CURL/7.81.0",
    "HTTP_X_FORWARDED_FOR": "81.61.128.254",
    "HTTP_X_FORWARDED_PROTO": "HTTPS",
    "HTTP_X_ENVOY_EXTERNAL_ADDRESS": "81.61.128.254",
    "HTTP_X_REQUEST_ID": "F0463914-3C0B-4CA3-9E61-5E40C01DBFD3",
    "HTTP_X_ENVOY_EXPECTED_RQ_TIMEOUT_MS": "15000"
  },
  "UUID": "500CA72C-A106-4BFB-91F5-0C2D2D78CF05"
* Connection #0 to host https-proxy.example.com left intact
```

</details>

Camel proxy can be inspected looking at logs from `tls.camel.proxy` service

```
docker compose -p camel-proxy logs -f tls.camel.proxy
```

## Clean env

```sh
make clean
```
