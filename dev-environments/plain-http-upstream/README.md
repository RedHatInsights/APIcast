# Plain HTTP 1.1 upstream

APIcast --> upstream plain HTTP 1.1 upstream

APIcast configured with plain HTTP 1.1 upstream server equipped with traffic rely agent (socat)

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
docker compose -p plain-http-upstream logs -f example.com
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
