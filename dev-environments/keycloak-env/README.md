# Using 3scale API Gateway with OpenID Connect

User (jwt) -> APIcast --> upstream plain HTTP 1.1 upstream

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
docker compose -p keycloak-env logs -f example.com
```

## Keycloak provisioning

```sh
make keycloak-data
```

Admin web app available at `http://127.0.0.1:9090`, user: `admin`, pass: `adminpass`.

Access to the Keycloak CLI

```sh
docker compose -p keycloak-env exec keycloak /bin/bash
```
Use the CLI

```sh
/opt/keycloak/bin/kcadm.sh --help
```

## Testing

### Get JWT

As user `bob` with password `p`, get a JWT for the `my-client` client.

```sh
export ACCESS_TOKEN=$(make token)
```

### Run request

```sh
curl -v --resolve stg.example.com:8080:127.0.0.1 -H "Authorization: Bearer ${ACCESS_TOKEN}" "http://stg.example.com:8080"
```

## Clean env

```sh
make clean
```
