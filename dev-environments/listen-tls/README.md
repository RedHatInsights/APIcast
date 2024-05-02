# Making APIcast listen on HTTPS

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

## Testing

```sh
curl --resolve example.com:8443:127.0.0.1 -v --cacert cert/rootCA.pem "https://example.com:8443/?user_key=123"
```

## Clean env

```sh
make clean
```
