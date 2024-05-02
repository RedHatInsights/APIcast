use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: large header (the header exceed the size of one buffer)
Default configuration for large_client_header_buffers: 4 8k
--- configuration env
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream

  location / {
    content_by_lua_block {
        ngx.print(ngx.req.raw_header())
    }
  }
--- more_headers eval
my $s = "User-Agent: curl\nBah: bah\n";
$s .= "Accept: */*\n";
$s .= "Large-Header: " . "ABCDEFGH" x 1024 . "\n";
$s
--- request
GET /?user_key=value
--- error_code: 400
--- no_error_log



=== TEST 2: large header with APICAST_LARGE_CLIENT_HEADER_BUFFERS set to 4 12k
--- env eval
(
  'APICAST_LARGE_CLIENT_HEADER_BUFFERS' => '4 12k',
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
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream

  location / {
    content_by_lua_block {
        ngx.print(ngx.req.raw_header())
    }
  }
--- more_headers eval
my $s = "User-Agent: curl\nBah: bah\n";
$s .= "Accept: */*\n";
$s .= "Large-Header: " . "ABCDEFGH" x 1024 . "\n";
$s
--- request
GET /?user_key=value
--- response_body eval
"GET /?user_key=value HTTP/1.1\r
X-Real-IP: 127.0.0.1\r
Host: test:$ENV{TEST_NGINX_SERVER_PORT}\r
User-Agent: curl\r
Bah: bah\r
Accept: */*\r
Large-Header: " . ("ABCDEFGH" x 1024) . "\r\n\r\n"
--- error_code: 200
--- no_error_log



=== TEST 3: large request line that exceed default header buffer
--- configuration env
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream

  location / {
    content_by_lua_block {
        ngx.print(ngx.req.raw_header())
    }
  }
--- more_headers eval
my $s = "User-Agent: curl\nBah: bah\n";
$s .= "Accept: */*\n";
$s .= "Large-Header: " . "ABCDEFGH" x 1024 . "\n";
$s
--- request eval
"GET /?user_key=value&foo=" . ("ABCDEFGH" x 1024)
--- error_code: 414
--- error_log
client sent too long URI while reading client request line



=== TEST 4: large request line with APICAST_LARGE_CLIENT_HEADER_BUFFERS set to "4 12k"
--- env eval
(
  'APICAST_LARGE_CLIENT_HEADER_BUFFERS' => '4 12k',
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
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream

  location / {
    content_by_lua_block {
        ngx.print(ngx.req.raw_header())
    }
  }
--- more_headers eval
my $s = "User-Agent: curl\nBah: bah\n";
$s .= "Accept: */*\n";
$s .= "Large-Header: " . "ABCDEFGH" x 1024 . "\n";
$s
--- request eval
"GET /?user_key=value&foo=" . ("ABCDEFGH" x 1024)
--- error_code: 200
--- no_error_log
