use Test::APIcast::Blackbox 'no_plan';

our $private_key = `cat t/fixtures/rsa.pem`;
our $public_key = `cat t/fixtures/rsa.pub`;

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: multi service configuration limited to specific service
--- env eval
("APICAST_SERVICES_LIST", "42,21")
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

=== TEST 2: multi service configuration limited with Regexp Filter and service list
--- env eval
(
"APICAST_SERVICES_FILTER_BY_URL", "^on*",
"APICAST_SERVICES_LIST", "21"
)
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
      "backend_version": 1,
      "proxy": {
        "hosts": [
          "two"
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/two",
        "proxy_rules": [
          {
            "http_method": "GET",
            "delta": 1,
            "metric_system_name": "one",
            "pattern": "/"
          }
        ]
      },
      "id": 21
    },
    {
      "proxy": {
        "hosts": [
          "three"
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
  location / {
     echo 'yay, api backend';
  }

  location /two {
     echo 'yay, api backend two';
  }

--- pipelined_requests eval
["GET /?user_key=1","GET /?user_key=2", "GET /?user_key=3"]
--- more_headers eval
["Host: one", "Host: two", "Host: three"]
--- response_body eval
["yay, api backend\n", "yay, api backend two\n", ""]
--- error_code eval
[200, 200, 404]


=== TEST 3: Verify that OIDC is working when filter services.
Related to issues THREESCALE-6042
--- env eval
(
  "APICAST_SERVICES_LIST", "42"
)
--- configuration env eval
use JSON qw(to_json);

to_json({
  services => [
  {
    id => 12,
    backend_version => '1',
    proxy => {
        api_backend => "http://test:$TEST_NGINX_SERVER_PORT/",
        hosts => ["null.com"],
        proxy_rules => [
          { pattern => '/', http_method => 'GET', metric_system_name => 'hits', delta => 1  }
        ]
    }
  },
  {
    id => 24,
    backend_version => 'oauth',
    backend_authentication_type => 'provider_key',
    backend_authentication_value => 'fookey',
    proxy => {
        authentication_method => 'oidc',
        oidc_issuer_endpoint => 'https://example.com/auth/realms/apicast_zero',
        api_backend => "http://test:$TEST_NGINX_SERVER_PORT/",
        hosts => ["zero"],
        proxy_rules => [
          { pattern => '/', http_method => 'GET', metric_system_name => 'hits', delta => 1  }
        ]
    }
  },
  {
    id => 42,
    backend_version => 'oauth',
    backend_authentication_type => 'provider_key',
    backend_authentication_value => 'fookey',
    proxy => {
        authentication_method => 'oidc',
        oidc_issuer_endpoint => 'https://example.com/auth/realms/apicast_one',
        api_backend => "http://test:$TEST_NGINX_SERVER_PORT/",
        hosts => ["one"],
        proxy_rules => [
          { pattern => '/', http_method => 'GET', metric_system_name => 'hits', delta => 1  }
        ]
    }
  }
  ],
  oidc => [
  {service_id => 12},
  {
    service_id => 24,
    issuer => 'https://example.com/auth/realms/apicast_zero',
    config => { id_token_signing_alg_values_supported => [ 'RS256' ] },
    keys => { somekid => { pem => $::public_key, alg => 'RS256' } },
  },
  {
    service_id => 42,
    issuer => 'https://example.com/auth/realms/apicast_one',
    config => { id_token_signing_alg_values_supported => [ 'RS256' ] },
    keys => { somekid => { pem => $::public_key, alg => 'RS256' } },
  }]
});
--- upstream
  location /test {
    echo "yes";
  }
--- backend
  location = /transactions/oauth_authrep.xml {
    content_by_lua_block {
      local expected = "provider_key=fookey&service_id=42&usage%5Bhits%5D=1&app_id=appid"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
--- request: GET /test
--- error_code: 200
--- more_headers eval
use Crypt::JWT qw(encode_jwt);
my $jwt = encode_jwt(payload => {
  aud => 'something',
  azp => 'appid',
  sub => 'someone',
  iss => 'https://example.com/auth/realms/apicast_one',
  exp => time + 3600 }, key => \$::private_key, alg => 'RS256', extra_headers => { kid => 'somekid' });
"Authorization: Bearer $jwt\r\nHost: one";
--- no_error_log
[error]

=== TEST 4: service list filter with paginated proxy config list
This test is configured to provide 3 pages of proxy configs. On each page, there is only one service
which is valid according to the filter by service list. The test will do one request to each valid service.
--- env eval
(
  'THREESCALE_DEPLOYMENT_ENV' => 'production',
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'APICAST_SERVICES_LIST' => '1,501,1001',
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
["GET /?user_key=1","GET /?user_key=1","GET /?user_key=1","GET /?user_key=2"]
--- more_headers eval
["Host: one-1","Host: one-501","Host: one-1001","Host: one-2"]
--- response_body eval
["yay, api backend\n","yay, api backend\n","yay, api backend\n",""]
--- error_code eval
[200, 200, 200, 404]
