# PROXY with upstream using TLSv1.3

APIcast --> tiny proxy (connect to 443 but no cert installed) --> upstream (TLSv1.3)

APIcast configured with TLSv1.3 powered upstream through a proxy. TLS termination endpoint is `socat`.

APicast starts SSL tunnel (via HTTP CONNECT method) against proxy to access upstream configured with TLSv1.3

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

Traffic between the proxy and upstream can be inspected looking at logs from `example.com` service

```
docker compose -p https-proxy-upstream-tlsv13 logs -f example.com
```

Proxy can be inspected looking at logs from `proxy` service

```
docker compose -p https-proxy-upstream-tlsv13 logs -f proxy
```

## Testing

`GET` request

```sh
curl --resolve get.example.com:8080:127.0.0.1 -v "http://get.example.com:8080/?user_key=123"
```

`POST` request

```sh
curl --resolve post.example.com:8080:127.0.0.1 -v -X POST "http://post.example.com:8080/?user_key=123"
```

## Clean env

```sh
make clean
```
