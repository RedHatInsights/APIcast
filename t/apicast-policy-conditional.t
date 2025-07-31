use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: Conditional policy calls its chain when the condition is true
In order to test this, we define a conditional policy that only runs the
phase_logger policy when the request path is /log.
We know that the policy outputs "running phase: some_phase" for each of the
phases it runs, so we can use that to verify it was executed.
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.conditional",
            "configuration": {
              "condition": {
                "operations": [
                  {
                    "left": "{{ uri }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "/log",
                    "right_type": "plain"
                  }
                ]
              },
              "policy_chain": [
                {
                  "name": "apicast.policy.phase_logger"
                }
              ]
            }
          },
          {
            "name": "apicast.policy.echo"
          }
        ]
      }
    }
  ]
}
--- request
GET /log
--- response_body
GET /log HTTP/1.1
--- error_code: 200
--- no_error_log
[error]
--- error_log chomp
running phase: rewrite

=== TEST 2: Conditional policy does not call its chain when the condition is false
In order to test this, we define a conditional policy that only runs the
phase_logger policy when the request path is /log.
We know that the policy outputs "running phase: some_phase" for each of the
phases it runs, so we can use that to verify that it was not executed.
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.conditional",
            "configuration": {
              "condition": {
                "operations": [
                  {
                    "left": "{{ uri }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "/log",
                    "right_type": "plain"
                  }
                ]
              },
              "policy_chain": [
                {
                  "name": "apicast.policy.phase_logger"
                }
              ]
            }
          },
          {
            "name": "apicast.policy.echo"
          }
        ]
      }
    }
  ]
}
--- request
GET /
--- response_body
GET / HTTP/1.1
--- error_code: 200
--- no_error_log
[error]
running phase: rewrite

=== TEST 3: Combine several operations in the condition
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.conditional",
            "configuration": {
              "condition": {
                "operations": [
                  {
                    "left": "{{ uri }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "/log",
                    "right_type": "plain"
                  },
                  {
                    "left": "{{ service.id }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "42",
                    "right_type": "plain"
                  }
                ],
                "combine_op": "and"
              },
              "policy_chain": [
                {
                  "name": "apicast.policy.phase_logger"
                }
              ]
            }
          },
          {
            "name": "apicast.policy.echo"
          }
        ]
      }
    }
  ]
}
--- request
GET /log
--- response_body
GET /log HTTP/1.1
--- error_code: 200
--- no_error_log
[error]
--- error_log chomp
running phase: rewrite

=== TEST 4: conditional policy combined with upstream policy
This test shows that the conditional policy can be used in combination with the
upstream one to change the upstream according to an HTTP request header.
We define the upstream policy so it redirects the request to the upstream
defined in the config below. The echo policy is included at the end of the
chain, so if the test fails, we'll notice because we'll get the answer from the
echo policy instead of our upstream.
--- upstream
  location / {
     echo 'yay, api backend';
  }
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.conditional",
            "configuration": {
              "condition": {
                "operations": [
                  {
                    "left": "{{ headers['Upstream'] }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "test_upstream",
                    "right_type": "plain"
                  }
                ]
              },
              "policy_chain": [
                {
                  "name": "apicast.policy.upstream",
                  "configuration": {
                    "rules": [
                      {
                        "regex": "/",
                        "url": "http://test:$TEST_NGINX_SERVER_PORT"
                      }
                    ]
                  }
                }
              ]
            }
          },
          {
            "name": "apicast.policy.echo"
          }
        ]
      }
    }
  ]
}
--- request
GET /
--- more_headers
Upstream: test_upstream
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]



=== TEST 5: conditional policy combined with on-failed policy
This test shows that conditional policies can be used in conjunction with an
on-failed policy that will return a 419 when one or more policies in the chain
fail to load. In this test, we will attempt to load an example policy that
does not exist.
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.conditional",
            "configuration": {
              "condition": {
                "operations": [
                  {
                    "left": "{{ uri }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "/",
                    "right_type": "plain"
                  }
                ]
              },
              "policy_chain": [
                {
                  "name": "example",
                  "version": "1.0",
                  "configuration": {}
                },
                {
                  "name": "on_failed",
                  "version": "builtin",
                  "configuration": {
                    "error_status_code": 419
                  }
                }
              ]
            }
          },
          {
            "name": "apicast.policy.echo"
          }
        ]
      }
    }
  ]
}
--- request
GET /
--- error_code: 419
--- no_error_log
[error]



=== TEST 6: conditional policy combined with on-failed policy
With this test, the on-failed policy only triggers if the condition is met
(request path match "/get").
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.conditional",
            "configuration": {
              "condition": {
                "operations": [
                  {
                    "left": "{{ uri }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "/get",
                    "right_type": "plain"
                  }
                ]
              },
              "policy_chain": [
                {
                  "name": "example",
                  "version": "1.0",
                  "configuration": {}
                },
                {
                  "name": "on_failed",
                  "version": "builtin",
                  "configuration": {
                    "error_status_code": 419
                  }
                }
              ]
            }
          },
          {
            "name": "apicast.policy.echo"
          }
        ]
      }
    }
  ]
}
--- pipelined_requests eval
["GET /","GET /get"]
--- response_body eval
["GET / HTTP/1.1\n",""]
--- error_code eval
[200, 419]
--- no_error_log
[error]
