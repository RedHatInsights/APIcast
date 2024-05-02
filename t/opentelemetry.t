use lib 't';
use Test::APIcast::Blackbox 'no_plan';

$ENV{OPENTELEMETRY} = '1';
$ENV{OPENTELEMETRY_CONFIG} = 't/fixtures/otel.toml';

repeat_each(1);
run_tests();

__DATA__
=== TEST 1: OpenTelemetry
Request passing through APIcast should publish OpenTelemetry info.
--- configuration
    {
        "services": [
        {
            "proxy": {
                "policy_chain": [
                    {
                        "name": "apicast.policy.upstream",
                        "configuration": {
                            "rules": [ { "regex": "/", "url": "http://echo" } ]
                        }
                    }
                ]
            }
        }
        ]
    }
--- request
GET /a_path?
--- response_body eval
qr/traceparent: /
--- error_code: 200
--- no_error_log
[error]
--- tcp_listen: 4317
--- tcp_reply
--- wait: 10
