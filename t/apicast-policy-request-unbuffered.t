use lib 't';
use Test::APIcast::Blackbox 'no_plan';

sub large_body {
  my $res = "";
  for (my $i=0; $i <= 1024; $i++) {
    $res = $res . "1111111 1111111 1111111 1111111\n";
  }
  return $res;
}

$ENV{'LARGE_BODY'} = large_body();

require("policies.pl");

run_tests();

__DATA__

=== TEST 1: request_unbuffered policy with big file
--- configuration
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "request_unbuffered",
            "version": "builtin",
            "configuration": {}
          },
          {
            "name": "apicast",
            "version": "builtin",
            "configuration": {}
          }
        ]
      }
    }
  ]
}
--- backend
location /transactions/authrep.xml {
  content_by_lua_block {
    ngx.exit(200)
  }
}
--- upstream
server_name test-upstream.lvh.me;
  location / {
    echo_read_request_body;
    echo_request_body;
  }
--- request eval
"POST /?user_key= \n" . $ENV{LARGE_BODY}
--- response_body eval chomp
$ENV{LARGE_BODY}
--- error_code: 200
--- grep_error_log eval
qr/a client request body is buffered to a temporary file/
--- grep_error_log_out
a client request body is buffered to a temporary file
--- no_error_log
[error]



=== TEST 2: with small chunked request
--- configuration
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "request_unbuffered",
            "version": "builtin",
            "configuration": {}
          },
          {
            "name": "apicast",
            "version": "builtin",
            "configuration": {}
          }
        ]
      }
    }
  ]
}
--- backend
location /transactions/authrep.xml {
  content_by_lua_block {
    ngx.exit(200)
  }
}
--- upstream
server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      assert = require('luassert')

      -- Nginx will read the entire body in one chunk, the upstream request will not be chunked
      -- and Content-Length header will be added.
      local content_length = ngx.req.get_headers()["Content-Length"]
      local encoding = ngx.req.get_headers()["Transfer-Encoding"]
      assert.equal('12', content_length)
      assert.falsy(encoding, "chunked")
    }
    echo_read_request_body;
    echo_request_body;
  }
--- more_headers
Transfer-Encoding: chunked
--- request eval
"POST /test?user_key=value
7\r
hello, \r
5\r
world\r
0\r
\r
"
--- response_body chomp
hello, world
--- error_code: 200
--- no_error_log
[error]



=== TEST 3: With big chunked request
--- configuration
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "request_unbuffered",
            "version": "builtin",
            "configuration": {}
          },
          {
            "name": "apicast",
            "version": "builtin",
            "configuration": {}
          }
        ]
      }
    }
  ]
}
--- backend
location /transactions/authrep.xml {
  content_by_lua_block {
    ngx.exit(200)
  }
}
--- upstream
server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      assert = require('luassert')
      local content_length = ngx.req.get_headers()["Content-Length"]
      local encoding = ngx.req.get_headers()["Transfer-Encoding"]
      assert.equal('chunked', encoding)
      assert.falsy(content_length)
    }
    echo_read_request_body;
    echo_request_body;
  }
--- more_headers
Transfer-Encoding: chunked
--- request eval
$::data = '';
for (my $i = 0; $i < 16384; $i++) {
    my $c = chr int rand 128;
    $::data .= $c;
}
my $s = "POST https://localhost/test?user_key=value
".
sprintf("%x\r\n", length $::data).
$::data
."\r
0\r
\r
";
open my $out, '>/tmp/out.txt' or die $!;
print $out $s;
close $out;
$s
--- response_body eval
$::data
--- error_code: 200
--- grep_error_log eval
qr/a client request body is buffered to a temporary file/
--- grep_error_log_out
a client request body is buffered to a temporary file
--- no_error_log
[error]
