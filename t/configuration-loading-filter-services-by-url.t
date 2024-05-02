use Test::APIcast::Blackbox 'no_plan';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: multi service configuration limited with Regexp Filter
--- env eval
("APICAST_SERVICES_FILTER_BY_URL", "^on*")
--- configuration
{
  "services": [
    {
      "backend_version": 1,
      "proxy": {
        "hosts": [
          "one"
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          {
            "http_method": "GET",
            "delta": 1,
            "metric_system_name": "one",
            "pattern": "/"
          }
        ]
      },
      "id": 42
    },
    {
      "proxy": {
        "hosts": [
          "two"
        ]
      },
      "id": 11
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- upstream
  location ~ / {
     echo 'yay, api backend';
  }
--- pipelined_requests eval
["GET /?user_key=1","GET /?user_key=2"]
--- more_headers eval
["Host: one", "Host: two"]
--- response_body eval
["yay, api backend\n", ""]
--- error_code eval
[200, 404]

=== TEST 2: Regexp Filter with paginated proxy config list
This test is configured to provide 3 pages of proxy configs. On each page, there is one service "one-*"
which is valid according to the filter by url. The test will do one request to each valid service.
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'APICAST_SERVICES_FILTER_BY_URL' => "^one*",
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

    local host_map = { [1] = 'one-1', [501] = 'one-501', [1001] = 'one-1001' }

    for i = (page - 1)*per_page + 1,math.min(page*per_page, 1256)
    do
      local host = host_map[i] or 'two'
      table.insert(configs_per_page, build_proxy_config(i, host))
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
["GET /?user_key=1","GET /?user_key=1","GET /?user_key=1","GET /?user_key=2"]
--- more_headers eval
["Host: one-1","Host: one-501","Host: one-1001","Host: two"]
--- response_body eval
["yay, api backend\n","yay, api backend\n","yay, api backend\n",""]
--- error_code eval
[200, 200, 200, 404]
