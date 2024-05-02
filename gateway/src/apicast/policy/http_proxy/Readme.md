# HTTP proxy policy

This policy allows users to define a HTTP proxy where the traffic will be send
over the defined proxy, the example traffic flow is the following:

```
   ,-.
   `-'
   /|\
    |            ,-------.          ,---------.          ,----------.
   / \           |Apicast|          |HTTPPROXY|          |APIBackend|
  User           `---+---'          `----+----'          `----------'
   |  GET /resource  |                   |                    |
   | --------------->|                   |                    |
   |                 |                   |                    |
   |                 |  Get /resource    |                    |
   |                 |------------------>|                    |
   |                 |                   |                    |
   |                 |                   |  Get /resource/    |
   |                 |                   | - - - - - - - - - >|
   |                 |                   |                    |
   |                 |                   |     response       |
   |                 |                   |<- - - - - - - - - -|
   |                 |                   |                    |
   |                 |     response      |                    |
   |                 |<------------------|                    |
   |                 |                   |                    |
   |                 |                   |                    |
   | <---------------|                   |                    |
  User           ,---+---.          ,----+----.          ,----------.
   ,-.           |Apicast|          |HTTPPROXY|          |APIBackend|
   `-'           `-------'          `---------'          `----------'
   /|\
    |
   / \
```

All APIcast traffic to 3scale backend will not use the proxy, due to this only
applies for the service and the communication between Apicast and API backend.

If you want to use all traffic through a Proxy, an HTTP_PROXY env var need to be
used.

## Configuration

The policy expect the URLS following the `http://[<username>[:<passwd>]@]<host>[:<port>]` format, e.g.:

```
"policy_chain": [
    {
      "name": "apicast.policy.apicast"
    },
    {
      "name": "apicast.policy.http_proxy",
      "configuration": {
          "all_proxy": "http://foo:bar@192.168.15.103:8888/",
          "https_proxy": "http://foo:bar@192.168.15.103:8888/",
          "http_proxy": "http://foo:bar@192.168.15.103:8888/"
      }
    }
]
```

- If http_proxy or https_proxy is not defined the all_proxy will be taken.
- The policy supports for proxy authentication via the `<username>` and `<passwd>` options.
- The `<username>` and `<passwd>` are optional, all other components are required.

## Caveats

- This policy will disable all load-balancing policies and traffic will be
  always send to the proxy. 
- In case of HTTP_PROXY, HTTPS_PROXY or ALL_PROXY parameters are defined, this
  policy will overwrite those values. 
- 3scale currently does not support connecting to an HTTP proxy via TLS. For this reason, the scheme of the HTTPS_PROXY value is restricted to http.


## Example Use case

This policy was designed to be able to apply more fined grained policies and
transformation using Apache Camel.

An example project can be found
[here](https://github.com/zregvart/camel-netty-proxy). This project is an HTTP
Proxy that transforms to uppercase all the response body given by the API
backend.
