# APICast Request Unbuffered

## Description

When enable this policy will dymanically sets the [`proxy_request_buffering: off`](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_request_buffering
) directive per service.

## Technical details

By default, NGINX reads the entire request body into memory or buffers large requests to disk before forwarding them to the upstream server. Reading bodies can become expensive, especially when sending requests containing large payloads.

For example, when the client sends 10GB, NGINX will buffer the entire 10GB to disk before sending anything to the upstream server.

When the `request_unbuffered` is in the chain, request buffering is disabled, sending the request body to the proxied server immediately upon receiving it. This can help minimize time spent sending data to a service and disk I/O for requests with big body. However, there are caveats and corner cases applied, [**Caveats**](#caveats)

The policy also provides a consistent behavior across multiple scenarios like:

```
- APIcast <> upstream HTTP 1.1 plain
- APIcast <> upstream TLS
- APIcast <> HTTP Proxy (env var) <> upstream HTTP 1.1 plain
- APIcast <> HTTP Proxy (policy) <> upstream HTTP 1.1 plain
- APIcast <> HTTP Proxy (camel proxy) <> upstream HTTP 1.1 plain
- APIcast <> HTTP Proxy (env var) <> upstream TLS
- APIcast <> HTTP Proxy (policy) <> upstream TLS
- APIcast <> HTTP Proxy (camel proxy) <> upstream TLS
```

## Why don't we also support disable response buffering?

The response buffering is enabled by default in NGINX (the [`proxy_buffering: on`]() directive). It does this to shield the backend against slow clients ([slowloris attack](https://en.wikipedia.org/wiki/Slowloris_(computer_security))).

If the `proxy_buffering` is disabled, the upstream server keeps the connection open until all data is received by the client. NGINX [advises](https://www.nginx.com/blog/avoiding-top-10-nginx-configuration-mistakes/#proxy_buffering-off) against disabling `proxy_buffering` as it will potentially waste upstream server resources.

## Why does upstream receive a "Content-Length" header when the original request is sent with "Transfer-Encoding: chunked"

For a request with "small" body that fits into [`client_body_buffer_size`](https://nginx.org/en/docs/http/ngx_http_core_module.html#client_body_buffer_size) and with header "Transfer-Encoding: chunked", NGINX will always read and know the length of the body. Then it will send the request to upstream with the "Content-Length" header.

If a client uses chunked transfer encoding with HTTP/1.0, NGINX will always buffer the request body

## Example configuration

```
"policy_chain": [
    {
        "name": "request_unbuffered",
        "version": "builtin",
    },
    {
      "name": "apicast.policy.apicast"
    }
]
```

Use with Proxy policy

```
"policy_chain": [
    {
        "name": "request_unbuffered",
        "version": "builtin",
    },
    {
      "name": "apicast.policy.http_proxy",
      "configuration": {
          "all_proxy": "http://foo:bar@192.168.15.103:8888/",
          "https_proxy": "http://192.168.15.103:8888/",
          "http_proxy": "http://192.168.15.103:8888/"
      }
    }
]
```

Use with Camel Proxy policy

```
"policy_chain": [
    {
        "name": "request_unbuffered",
        "version": "builtin",
    },
    {
      "name": "apicast.policy.camel",
      "configuration": {
          "http_proxy": "http://192.168.15.103:8080/",
          "https_proxy": "http://192.168.15.103:8443/",
          "all_proxy": "http://192.168.15.103:8080/"
      }
    }
]
```

## Caveats

- APIcast allows defining of mapping rules based on request content. For example, `POST /some_path?a_param={a_value}` will match a request like `POST "http://apicast_host:8080/some_path"` with a form URL-encoded body like: `a_param=abc`, requests with `Content-type: application/x-www-form-urlencoded` will always be buffered regardless of the
  `request_unbuffered` policy is enabled or not.
- Disable request buffering could potentially expose the backend to [slowloris attack](https://en.wikipedia.org/wiki/Slowloris_(computer_security)). Therefore, we recommend to only use this policy when needed.
