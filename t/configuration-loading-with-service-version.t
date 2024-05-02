use Test::APIcast::Blackbox 'no_plan';

repeat_each(1);

run_tests();

__DATA__

=== TEST 1: load configuration with APICAST_SERVICE_${ID}_CONFIGURATION_VERSION
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}",
  'APICAST_SERVICE_2_CONFIGURATION_VERSION' => 42
)
--- upstream env
    location = /admin/api/services.json {
        echo '{ "services": [ { "service": { "id": 2 } } ] }';
    }
    location = /admin/api/services/2/proxy/configs/production/42.json {
        echo '
        {
            "proxy_config": {
                "content": {
                    "id": 2,
                    "backend_version": 1,
                    "proxy": {
                        "hosts": [ "localhost" ],
                        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
                        "proxy_rules": [
                            { "pattern": "/t", "http_method": "GET", "metric_system_name": "test","delta": 1 }
                        ]
                    }
                }
            }
        }';
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

=== TEST 2: load configuration with APICAST_SERVICE_${ID}_CONFIGURATION_VERSION with paginated service list
and paginated service list. This test is configured to provide 3 pages of services.
On each page, there is one service for which the version will be overriden.
The test will do one request to each valid service.
--- env eval
(
  'APICAST_SERVICE_1_CONFIGURATION_VERSION' => 42,
  'APICAST_SERVICE_500_CONFIGURATION_VERSION' => 42,
  'APICAST_SERVICE_1000_CONFIGURATION_VERSION' => 42,
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream env
location = /admin/api/services.json {
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

    local services_per_page = {}
    for i = (page - 1)*per_page + 1,math.min(page*per_page, 1256)
    do
      table.insert(services_per_page, {service = { id = i }})
    end

    require('luassert').True(#services_per_page <= per_page)

    local response = { services = services_per_page }
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say(require('cjson').encode(response))
  }
}

location ~ /admin/api/services/\d+/proxy/configs/production/.*.json {
  content_by_lua_block {
    local proxy_config = {
      content = { id = 1, backend_version = 1,
        proxy = {
          hosts = { 'other' },
          api_backend = 'http://test:$TEST_NGINX_SERVER_PORT/api/',
          backend = { endpoint = 'http://test:$TEST_NGINX_SERVER_PORT' },
          proxy_rules = { { pattern = '/', http_method = 'GET', metric_system_name = 'test', delta = 1 } }
        }
      }
    }

    if( ngx.var.uri == '/admin/api/services/1/proxy/configs/production/42.json' )
    then
      proxy_config.content.id = 1
      proxy_config.content.proxy.hosts = { 'one-1' }
    elseif( ngx.var.uri == '/admin/api/services/500/proxy/configs/production/42.json'  )
    then
      proxy_config.content.id = 501
      proxy_config.content.proxy.hosts = { 'one-501' }
    elseif( ngx.var.uri == '/admin/api/services/1000/proxy/configs/production/42.json'  )
    then
      proxy_config.content.id = 1001
      proxy_config.content.proxy.hosts = { 'one-1001' }
    end

    local response = { proxy_config = proxy_config }
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say(require('cjson').encode(response))
  }
}

location /api/ {
  echo 'yay, api backend';
}

--- backend
location /transactions/authrep.xml {
  content_by_lua_block { ngx.exit(200) }
}

--- timeout: 60s
--- pipelined_requests eval
["GET /?user_key=1","GET /?user_key=1","GET /?user_key=1","GET /?user_key=2"]
--- more_headers eval
["Host: one-1","Host: one-501","Host: one-1001","Host: two"]
--- response_body eval
["yay, api backend\n","yay, api backend\n","yay, api backend\n",""]
--- error_code eval
[200, 200, 200, 404]

=== TEST 3: load a config where only some of the services have an OIDC configuration
This is a regression test. APIcast crashed when loading a config where only
some of the services used OIDC.
The reason is that we created an array of OIDC configs with
size=number_of_services. Let's say we have 100 services and only the 50th has an
OIDC config. In this case, we created this Lua table:
{ [50] = oidc_config_here }.
The problem is that cjson raises an error when trying to convert a sparse array
like that into JSON. Using the default cjson configuration, the minimum number
of elements to reproduce the error is 11. So in this test, we create 11 services
and assign an OIDC config only to the last one. Check
https://www.kyne.com.au/~mark/software/lua-cjson-manual.html#encode_sparse_array
for more details.
Now we assign to _false_ the elements of the array that do not have an OIDC
config, so this test should not crash.
--- env eval
(
  'THREESCALE_DEPLOYMENT_ENV' => 'production',
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'APICAST_SERVICE_11_CONFIGURATION_VERSION' => 42,
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream env
location = /admin/api/services.json {
    echo '
    {
      "services":[
        { "service": { "id":1 } }, { "service": { "id":2 } }, { "service": { "id":3 } },
        { "service": { "id":4 } }, { "service": { "id":5 } }, { "service": { "id":6 } },
        { "service": { "id":7 } }, { "service": { "id":8 } }, { "service": { "id":9 } },
        { "service": { "id":10 } }, { "service": { "id":11 } }
      ]
    }';
}

location ~ /admin/api/services/([0-9]|10)/proxy/configs/production/latest.json {
echo '
{
  "proxy_config": {
    "content": { "id": 1, "backend_version": 1, "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api/",
        "backend": { "endpoint": "http://test:$TEST_NGINX_SERVER_PORT" },
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "test", "delta": 1 }
        ]
      }
    }
  }
}
';
}

location = /admin/api/services/11/proxy/configs/production/42.json {
echo '{ "proxy_config": { "content": { "proxy": { "oidc_issuer_endpoint": "http://test:$TEST_NGINX_SERVER_PORT/issuer/endpoint" } } } }';
}

location = /issuer/endpoint/.well-known/openid-configuration {
  content_by_lua_block {
    local base = "http://" .. ngx.var.host .. ':' .. ngx.var.server_port
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say(require('cjson').encode {
        issuer = 'https://example.com/auth/realms/apicast',
        id_token_signing_alg_values_supported = { 'RS256' },
        jwks_uri = base .. '/jwks',
    })
  }
}

location = /jwks {
  content_by_lua_block {
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say([[
        { "keys": [
            { "kty":"RSA","kid":"somekid",
              "n":"sKXP3pwND3rkQ1gx9nMb4By7bmWnHYo2kAAsFD5xq0IDn26zv64tjmuNBHpI6BmkLPk8mIo0B1E8MkxdKZeozQ","e":"AQAB" }
        ] }
    ]])
  }
}

location /api/ {
  echo 'yay, api backend';
}

--- backend
location /transactions/authrep.xml {
content_by_lua_block { ngx.exit(200) }
}

--- request
GET /?user_key=uk
--- error_code: 200
--- response_body
yay, api backend
