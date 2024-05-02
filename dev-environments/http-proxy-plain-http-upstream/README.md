# PROXY with upstream using plain HTTP 1.1

APIcast --> tiny proxy (connect to 443 but no cert installed) --> upstream (plain HTTP 1.1)

APIcast configured with plain HTTP 1.1 upstream through a proxy.

## Run the gateway

Running local `apicast-test` docker image

```sh
make gateway
```

Running custom apicast image

```sh
make gateway IMAGE_NAME=quay.io/3scale/apicast:latest
```

Traffic between APIcast and the proxy can be inspected looking at logs from `proxy` service

```
docker compose -p http-proxy-plain-http-upstream logs -f proxy
```

Proxy logs from `actual.proxy` service

```
docker compose -p http-proxy-plain-http-upstream logs -f actual.proxy
```

Traffic between the proxy and upstream can be inspected looking at logs from `example.com` service

```
docker compose -p http-proxy-plain-http-upstream logs -f example.com
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
