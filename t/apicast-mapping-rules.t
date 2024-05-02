use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: mapping rules when GET request has url params
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend",
        "proxy_rules": [
          {
            "pattern": "/{env}/video/encode?size={size}&speed=2x",
            "http_method": "GET",
            "metric_system_name": "hits",
            "delta": 2,
            "querystring_parameters": { "size": "{size}", "speed": "2x" }
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- upstream
  location /api-backend/ {
    echo 'yay, api backend';
  }
--- request
GET /staging/video/encode?size=100&speed=3x&user_key=foo&speed=2x
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]



=== TEST 2: mapping rules when POST request has url parms
url params in a POST call are taken into account when matching mapping rules.
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value" : "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
          {
            "pattern" : "/foo?bar=baz",
            "http_method" : "POST",
            "metric_system_name" : "bar",
            "delta" : 7,
            "querystring_parameters": { "bar": "baz" }
          }
        ]
      }
    }
  ]
}
--- upstream
  location /api-backend {
    echo 'yay, api backend';
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
POST /foo?bar=baz&user_key=somekey
--- more_headers
X-3scale-Debug: token-value
--- response_body
yay, api backend
--- error_code: 200
--- response_headers
X-3scale-matched-rules: /foo?bar=baz
X-3scale-usage: usage%5Bbar%5D=7
--- no_error_log
[error]



=== TEST 3: mapping rules when POST request has body params
request body params in a POST call are taken into account when matching mapping rules.
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value" : "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
          {
            "pattern" : "/foo?bar=baz",
            "http_method" : "POST",
            "metric_system_name" : "bar",
            "delta" : 7,
            "querystring_parameters": { "bar": "baz" }
          }
        ]
      }
    }
  ]
}
--- upstream
  location /api-backend {
    echo 'yay, api backend';
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
POST /foo?user_key=somekey
bar=baz
--- more_headers
Content-Type: application/x-www-form-urlencoded
X-3scale-Debug: token-value
--- response_body
yay, api backend
--- error_code: 200
--- response_headers
X-3scale-matched-rules: /foo?bar=baz
X-3scale-usage: usage%5Bbar%5D=7
--- no_error_log
[error]



=== TEST 4: mapping rules when POST request has body params and url params
Both body params and url params are taken into account when matching mapping
rules. When a param is both in the url and the body, the one in the body takes
precedence.
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value" : "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
          {
            "pattern" : "/foo?a_param=val1&another_param=val2",
            "http_method" : "POST",
            "metric_system_name" : "bar",
            "delta" : 7,
            "querystring_parameters": { "a_param": "val1", "another_param": "val2" }
          }
        ]
      }
    }
  ]
}
--- upstream
  location /api-backend {
    echo 'yay, api backend';
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
POST /foo?a_param=val3&another_param=val2&user_key=somekey
a_param=val1
--- more_headers
Content-Type: application/x-www-form-urlencoded
X-3scale-Debug: token-value
--- response_body
yay, api backend
--- error_code: 200
--- response_headers
X-3scale-matched-rules: /foo?a_param=val1&another_param=val2
X-3scale-usage: usage%5Bbar%5D=7
--- no_error_log
[error]



=== TEST 5: mapping rules with "last" attribute
Mapping rules can have a "last" attribute. When this attribute is set to true,
and the rule matches, it indicates that the matcher should stop processing the
rules that come after.
In the example, we have 4 rules:
- the first one matches and last = false, so the matcher will continue.
- the second has last = true but does not match, so the matcher will continue.
- the third one matches and has last = true so the matcher will stop here.
The usage is checked in the 3scale backend endpoint.
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value" : "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
          {
            "last": false,
            "id": 1,
            "http_method": "GET",
            "pattern": "/",
            "metric_system_name": "hits",
            "delta": 1
          },
          {
            "last": true,
            "id": 2,
            "http_method": "GET",
            "pattern": "/i_dont_match",
            "metric_system_name": "hits",
            "delta": 100
          },
          {
            "last": true,
            "id": 3,
            "http_method": "GET",
            "pattern": "/abc",
            "metric_system_name": "hits",
            "delta": 2
          },
          {
            "id": 4,
            "http_method": "GET",
            "pattern": "/abc/def",
            "metric_system_name": "hits",
            "delta": 10
          }
        ]
      }
    }
  ]
}
--- upstream
  location /api-backend {
    echo 'yay, api backend';
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local hits = tonumber(ngx.req.get_uri_args()["usage[hits]"])
      require('luassert').equals(3, hits) -- rule 1 + rule 3
    }
  }
--- request
GET /abc/def?user_key=uk
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]



=== TEST 6: request uri with special chars
Call with special chars and validate that are correctly matched.
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value" : "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
          {
            "pattern" : "/foo%20/bar/",
            "http_method" : "GET",
            "metric_system_name" : "hits",
            "delta" : 1
          }
        ]
      }
    }
  ]
}
--- upstream
  location /api-backend {
    echo 'yay, api backend';
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
GET /foo%20/bar/?user_key=foo
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]
