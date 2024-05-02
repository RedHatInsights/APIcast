use Test::APIcast::Blackbox 'no_plan';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: load empty configuration
should just say service is not found
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream
location /admin/api/account/proxy_configs/production.json {
  content_by_lua_block {
    local expected = { host = 'localhost', version = 'latest', page = '1', per_page = '500' }
    require('luassert').same(expected, ngx.req.get_uri_args(0))

    ngx.say(require('cjson').encode({}))
  }
}
--- request: GET /t
--- error_code: 404
--- error_log
service not found for host localhost
using lazy configuration loader

=== TEST 2: load invalid configuration
should just say service is not found
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream
location /admin/api/account/proxy_configs/production.json {
    echo '';
}
--- request: GET /t
--- error_code: 404
--- error_log
service not found for host localhost
using lazy configuration loader

=== TEST 3: load valid configuration
should correctly route the request
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream env
location = /admin/api/account/proxy_configs/production.json {
  content_by_lua_block {
    local expected = { host = 'localhost', version = 'latest', page = '1', per_page = '500' }
    require('luassert').same(expected, ngx.req.get_uri_args(0))

    local response = {
      proxy_configs = {
        {
          proxy_config = {
            content = {
              id = 1, backend_version = 1,
              proxy = {
                hosts = { 'localhost' },
                api_backend = 'http://test:$TEST_NGINX_SERVER_PORT/',
                proxy_rules = {
                  { pattern = '/t', http_method = 'GET', metric_system_name = 'test', delta = 1 }
                }
              }
            }
          }
        }
      }
    }

    ngx.say(require('cjson').encode(response))
  }
}

location /t {
    echo "all ok";
}
--- backend
location /transactions/authrep.xml {
  content_by_lua_block {
    ngx.exit(200)
  }
}
--- request
GET /t?user_key=fake
--- error_code: 200
--- error_log
using lazy configuration loader
--- no_error_log
[error]

=== TEST 4: load invalid json
To validate that process does not died with invalid config
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream
location ~ /admin/(.+) {
    echo '{Hello, world}';
}
--- request
GET /t?user_key=fake
--- error_code: 404
--- no_error_log
[error]

=== TEST 5: load invalid oidc target url
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream env
    location = /admin/api/account/proxy_configs/production.json {
        echo '
        {
            "proxy_configs" : [{
                "proxy_config": {
                    "content": {
                        "id": 1,
                        "backend_version": "oauth",
                        "proxy": {
                            "hosts": [ "localhost" ],
                            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
                            "service_id": 2555417794444,
                            "oidc_issuer_endpoint": "www.fgoodl/adasd",
                            "authentication_method": "oidc",
                            "service_backend_version": "oauth",
                            "proxy_rules": [
                                { "pattern": "/t", "http_method": "GET", "metric_system_name": "test","delta": 1 }
                            ]
                        }
                    }
                }
            }]
        }';
    }
--- backend
    location /transactions/authrep.xml {
      content_by_lua_block {
        ngx.exit(200)
      }
    }
--- request
GET /t?user_key=fake
--- error_code: 401
--- error_log
using lazy configuration loader
OIDC url is not valid, uri:
--- no_error_log
[error]

=== TEST 6: Load paginated proxy config list
This test is configured to provide 3 pages of proxy configs.
The test will try requests with hostnames existing a different pages
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'APICAST_SERVICE_CACHE_SIZE' => '2000',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream env
location /admin/api/account/proxy_configs/production.json {
  content_by_lua_block {
    local args = ngx.req.get_uri_args(0)
    local page = 1
    if args.page then
      page = tonumber(args.page)
    end
    local per_page = 500
    if args.per_page then
      per_page = tonumber(args.per_page)
    end

    -- this test is designed for pages of 500 items
    require('luassert').equals(500, per_page)
    require('luassert').is_true(1 <= page and page < 4)

    local function build_proxy_config(service_id, host)
      return { proxy_config = {
        content = { id = service_id, backend_version = 1,
          proxy = {
            hosts = { host },
            api_backend = 'http://test:$TEST_NGINX_SERVER_PORT/api/',
            backend = { endpoint = 'http://test:$TEST_NGINX_SERVER_PORT' },
            proxy_rules = { { pattern = '/', http_method = 'GET', metric_system_name = 'test', delta = 1 } }
          }
        }
      }}
    end

    local configs_per_page = {}

    for i = (page - 1)*per_page + 1,math.min(page*per_page, 1256)
    do
      table.insert(configs_per_page, build_proxy_config(i, 'one-'..tostring(i)))
    end

    local response = { proxy_configs = configs_per_page }
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say(require('cjson').encode(response))
  }
}

location /api/ {
  echo 'yay, api backend';
}

--- timeout: 25s
--- backend
location /transactions/authrep.xml {
  content_by_lua_block { ngx.exit(200) }
}

--- pipelined_requests eval
["GET /?user_key=1","GET /?user_key=1","GET /?user_key=1"]
--- more_headers eval
["Host: one-1","Host: one-501","Host: one-1001"]
--- response_body eval
["yay, api backend\n","yay, api backend\n","yay, api backend\n"]
--- error_code eval
[200, 200, 200]
