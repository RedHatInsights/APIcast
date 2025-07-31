# Conditional Policy

- [**Description**](#description)
- [**Conditions**](#conditions)
- [**Example config**](#example-config)

## NOTE
This is policy is not available in the admin portal UI, however, you still be
able to configure it via 3scale [Product CR](https://github.com/3scale/3scale-operator/blob/master/doc/product-reference.md#user-content-policyconfigspec)

## Description

The conditional policy is a bit different from the rest because it contains a
chain of policies. It defines a condition that is evaluated on each nginx phase
(access, rewrite, log, etc.). When that condition is true, the conditional
policy runs that phase for each of the policies that it contains in its chain.

Let's see an example:

```
APIcast --> Caching --> Conditional --> Upstream

                             |
                             v

                          Headers

                             |
                             v

                       URL Rewriting

```

Let's assume that the conditional policy defines the following condition: `the
request method is POST`. In that case, when the request is a POST, the order of
execution for each phase is:
1) APIcast
2) Caching
3) Headers
4) URL Rewriting
5) Upstream

When the request is not a POST, the order of execution for each phase is:
1) APIcast
2) Caching
3) Upstream

NOTE: when one or more policies in conditional chain are invalid, APIcast will
skip the invalid policy and load the next policy in the chain, which may lead
to unexpected behavior. If you want to terminate the chain, add an `on_failed`
policy to the chain.

## Conditions

The condition that determines whether to run the policies in the chain of the
conditional policy can be expressed with JSON, and it uses liquid templating.
This is an example that checks whether the request path is `/example_path`:

```json
{
  "left": "{{ uri }}",
  "left_type": "liquid",
  "op": "==",
  "right": "/example_path",
  "right_type": "plain"
}
```

Notice that both the left and right operands can be evaluated either as liquid or
as plain strings. The latter is the default.

We can combine operations with `and` or `or`. This config checks the same as
the one above plus the value of the `Backend` header:

```json
{
  "operations": [
    {
      "left": "{{ uri }}",
      "left_type": "liquid",
      "op": "==",
      "right": "/example_path",
      "right_type": "plain"
    },
    {
      "left": "{{ headers['Backend'] }}",
      "left_type": "liquid",
      "op": "==",
      "right": "test_upstream",
      "right_type": "plain"
    }
  ],
  "combine_op": "and"
}
```

These are the variables supported in liquid:
* uri
* host
* remote_addr
* headers['Some-Header']

The updated list of variables can be found [here](../ngx_variable.lua)


## Example config

This is an example configuration. It executes the upstream policy only when
the `Backend` header of the request is `staging`:

```json
{
   "name":"conditional",
   "version":"builtin",
   "configuration":{
      "condition":{
         "operations":[
            {
               "left":"{{ headers['Backend'] }}",
               "left_type":"liquid",
               "op":"==",
               "right":"staging"
            }
         ]
      },
      "policy_chain":[
         {
            "name":"upstream",
            "version": "builtin",
            "configuration":{
               "rules":[
                  {
                     "regex":"/",
                     "url":"http://my_staging_environment"
                  }
               ]
            }
         }
      ]
   }
}

```

With `on-failed` policy

```json
{
   "name":"conditional",
   "version":"builtin",
   "configuration":{
      "condition":{
         "operations":[
            {
               "left":"{{ headers['Backend'] }}",
               "left_type":"liquid",
               "op":"==",
               "right":"staging"
            }
         ]
      },
      "policy_chain":[
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
}

```
