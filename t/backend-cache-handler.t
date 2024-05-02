use lib 't';
use Test::APIcast::Blackbox 'no_plan';

repeat_each(1); # Can't be two as the second call would hit the cache
run_tests();

__DATA__

=== TEST 1: resilient backend will keep calls through without backend connection
When backend returns server error the call will be let through.
--- env random_port eval
(
  'APICAST_BACKEND_CACHE_HANDLER' => 'resilient'
)
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- backend
  access_by_lua_block {
    require('apicast.proxy').shared_cache():set('42:foo:usage%5Bhits%5D=2', 200)
  }

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(502) }
  }
--- upstream
  location /api-backend/ {
     echo 'yay, api backend';
  }
--- request eval
["GET /test?user_key=foo", "GET /foo?user_key=foo"]
--- response_body eval
["yay, api backend\x{0a}", "yay, api backend\x{0a}" ]
--- error_code eval
[ 200, 200 ]


=== TEST 2: strict backend will remove cache after not successful status
When backend returns server error the next call will be reauthorized.
In order to test this, we returns 200 on the first call, and
502 on the rest. We need to test that the first call is authorized, the
second is too because it will be cached, and the third will not be authorized
because the cache was cleared in the second call.
--- env eval
(
  'APICAST_BACKEND_CACHE_HANDLER' => 'strict'
)
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local test_counter = ngx.shared.test_counter or 0
      if test_counter == 0 then
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(200)
      else
        ngx.exit(502)
      end
    }
  }
--- upstream
  location /api-backend/ {
     echo 'yay, api backend';
  }
--- request eval
["GET /test?user_key=foo", "GET /foo?user_key=foo", "GET /?user_key=foo"]
--- response_body eval
["yay, api backend\x{0a}", "yay, api backend\x{0a}", "Authentication failed"]
--- error_code eval
[ 200, 200, 403 ]
