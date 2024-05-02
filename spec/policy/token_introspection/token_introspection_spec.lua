local TokenIntrospection = require('apicast.policy.token_introspection')
local TokensCache = require('apicast.policy.token_introspection.tokens_cache')
local format = string.format
local test_backend_client = require('resty.http_ng.backend.test')
local cjson = require('cjson')
describe("token introspection policy", function()
  describe("execute introspection", function()
    local context
    local test_backend
    local test_access_token = "test"
    local test_client_id = "client"
    local test_client_secret = "secret"
    local test_basic_auth = 'Basic '..ngx.encode_base64(test_client_id..':'..test_client_secret)

    local function assert_authentication_failed()
      assert.same(ngx.status, 403)
      assert.stub(ngx.say).was.called_with("auth failed")
      assert.stub(ngx.exit).was.called_with(403)
    end

    before_each(function()
      test_backend = test_backend_client.new()
      ngx.var = {}
      ngx.var.http_authorization = "Bearer "..test_access_token
      context = {
        service = {
          auth_failed_status = 403,
          error_auth_failed = "auth failed"
        }
      }
    end)

    describe('client_id+client_secret introspection auth type', function()
      local auth_type = "client_id+client_secret"
      local introspection_url = "http://example/token/introspection"
      local policy_config = {
        auth_type = auth_type,
        introspection_url = introspection_url,
        client_id = test_client_id,
        client_secret = test_client_secret
      }

      it('success with valid token', function()
        test_backend
          .expect{
            url = introspection_url,
            method = 'POST',
            headers = {
              ['Authorization'] = test_basic_auth
            }
          }
          .respond_with{
            status = 200,
            body = cjson.encode({
                active = true
            })
          }

        local token_policy = TokenIntrospection.new(policy_config)
        token_policy.http_client.backend = test_backend
        token_policy:access(context)
        assert.are.same(ngx.decode_args(test_backend.get_requests()[1].body),
            { token = "test", token_type_hint = "access_token" })
      end)

      it('failed with invalid token', function()
        test_backend
          .expect{
            url = introspection_url,
            method = 'POST',
            headers = {
              ['Authorization'] = test_basic_auth
            }
          }
          .respond_with{
            status = 200,
            body = cjson.encode({
                active = false
            })
          }
        stub(ngx, 'say')
        stub(ngx, 'exit')

        local token_policy = TokenIntrospection.new(policy_config)
        token_policy.http_client.backend = test_backend
        token_policy:access(context)
        assert_authentication_failed()

        assert.are.same(ngx.decode_args(test_backend.get_requests()[1].body),
            { token = "test", token_type_hint = "access_token" })
      end)

      it('failed with bad status code', function()
        test_backend
          .expect{
            url = introspection_url,
            method = 'POST',
            headers = {
              ['Authorization'] = test_basic_auth
            }
          }
          .respond_with{
            status = 404,
          }
        stub(ngx, 'say')
        stub(ngx, 'exit')

        local token_policy = TokenIntrospection.new(policy_config)
        token_policy.http_client.backend = test_backend
        token_policy:access(context)
        assert_authentication_failed()

        assert.are.same(ngx.decode_args(test_backend.get_requests()[1].body),
            { token = "test", token_type_hint = "access_token" })
      end)

      it('failed with null response', function()
        test_backend
          .expect{
            url = introspection_url,
            method = 'POST',
            headers = {
              ['Authorization'] = test_basic_auth
            }
          }
          .respond_with{
            status = 200,
            body = 'null'
          }
        stub(ngx, 'say')
        stub(ngx, 'exit')

        local token_policy = TokenIntrospection.new(policy_config)
        token_policy.http_client.backend = test_backend
        token_policy:access(context)
        assert_authentication_failed()

        assert.are.same(ngx.decode_args(test_backend.get_requests()[1].body),
            { token = "test", token_type_hint = "access_token" })
      end)

      it('failed with active null response', function()
        test_backend
          .expect{
            url = introspection_url,
            method = 'POST',
            headers = {
              ['Authorization'] = test_basic_auth
            }
          }
          .respond_with{
            status = 200,
            body = '{ "active": null }'
          }
        stub(ngx, 'say')
        stub(ngx, 'exit')

        local token_policy = TokenIntrospection.new(policy_config)
        token_policy.http_client.backend = test_backend
        token_policy:access(context)
        assert_authentication_failed()

        assert.are.same(ngx.decode_args(test_backend.get_requests()[1].body),
            { token = "test", token_type_hint = "access_token" })
      end)

      it('failed with missing active response', function()
        test_backend
          .expect{
            url = introspection_url,
            method = 'POST',
            headers = {
              ['Authorization'] = test_basic_auth
            }
          }
          .respond_with{
            status = 200,
            body = '{}'
          }
        stub(ngx, 'say')
        stub(ngx, 'exit')

        local token_policy = TokenIntrospection.new(policy_config)
        token_policy.http_client.backend = test_backend
        token_policy:access(context)
        assert_authentication_failed()

        assert.are.same(ngx.decode_args(test_backend.get_requests()[1].body),
            { token = "test", token_type_hint = "access_token" })
      end)

      it('failed with bad contents type', function()
        test_backend
          .expect{
            url = introspection_url,
            method = 'POST',
            headers = {
              ['Authorization'] = test_basic_auth
            }
          }
          .respond_with{
            status = 200,
            body = "<html></html>"
          }
        stub(ngx, 'say')
        stub(ngx, 'exit')

        local token_policy = TokenIntrospection.new(policy_config)
        token_policy.http_client.backend = test_backend
        token_policy:access(context)
        assert_authentication_failed()

        assert.are.same(ngx.decode_args(test_backend.get_requests()[1].body),
            { token = "test", token_type_hint = "access_token" })
      end)
    end)

    describe('use_3scale_oidc_issuer_endpoint auth type', function()
      local auth_type = "use_3scale_oidc_issuer_endpoint"
      local policy_config = {
        auth_type = auth_type,
      }

      it('when no oauth content in the context', function()
        context = {
          service = {
            auth_failed_status = 403,
            error_auth_failed = "auth failed"
          },
          proxy = {
          }
        }

        stub(ngx, 'say')
        stub(ngx, 'exit')

        local token_policy = TokenIntrospection.new(policy_config)
        token_policy.http_client.backend = test_backend
        token_policy:access(context)
        assert_authentication_failed()
      end)

      it('using deprecated token_introspection_endpoint', function()
        test_backend
          .expect{
            url = "http://example.com/token/introspection",
            method = 'POST',
            headers = {
              ['Authorization'] = test_basic_auth
            }
          }
          .respond_with{
            status = 200,
            body = cjson.encode({
                active = true
            })
          }
        context = {
          service = {
            auth_failed_status = 403,
            error_auth_failed = "auth failed",
            oidc = {
              issuer_endpoint = format('http://%s:%s@example.com/issuer/endpoint', test_client_id, test_client_secret)
            }
          },
          proxy = {
            oauth = {
              config = {
                token_introspection_endpoint = "http://example.com/token/introspection"
              }
            }
          }
        }

        stub(ngx, 'say')
        stub(ngx, 'exit')

        local token_policy = TokenIntrospection.new(policy_config)
        token_policy.http_client.backend = test_backend
        token_policy:access(context)
        assert.stub(ngx.exit).was_not.called_with(403)
        assert.are.same(ngx.decode_args(test_backend.get_requests()[1].body),
            { token = "test", token_type_hint = "access_token" })
      end)

      it('using introspection_endpoint', function()
        test_backend
          .expect{
            url = "http://example.com/token/introspection",
            method = 'POST',
            headers = {
              ['Authorization'] = test_basic_auth
            }
          }
          .respond_with{
            status = 200,
            body = cjson.encode({
                active = true
            })
          }
        context = {
          service = {
            auth_failed_status = 403,
            error_auth_failed = "auth failed",
            oidc = {
              issuer_endpoint = format('http://%s:%s@example.com/issuer/endpoint', test_client_id, test_client_secret)
            }
          },
          proxy = {
            oauth = {
              config = {
                introspection_endpoint = "http://example.com/token/introspection",
                --- deprecated field
                token_introspection_endpoint = "http://example.com/token/deprecated_introspection"
              }
            }
          }
        }

        stub(ngx, 'say')
        stub(ngx, 'exit')

        local token_policy = TokenIntrospection.new(policy_config)
        token_policy.http_client.backend = test_backend
        token_policy:access(context)
        assert.stub(ngx.exit).was_not.called_with(403)
        assert.are.same(ngx.decode_args(test_backend.get_requests()[1].body),
            { token = "test", token_type_hint = "access_token" })
      end)

    end)

    describe('when caching is enabled', function()
      local introspection_url = "http://example/token/introspection"
      local policy_config = {
        auth_type = "client_id+client_secret",
        introspection_url = introspection_url,
        client_id = test_client_id,
        client_secret = test_client_secret,
        max_ttl_tokens = 120,
        max_cached_tokens = 10
      }

      local test_token_info = { active = true }
      local test_tokens_cache

      local token_policy = TokenIntrospection.new(policy_config)

      describe('and the token is cached', function()
        setup(function()
          test_tokens_cache = TokensCache.new(60)
          test_tokens_cache:set(test_access_token, test_token_info)
        end)

        it('does not call the introspection endpoint', function()
          token_policy.tokens_cache = test_tokens_cache
          token_policy.http_client.backend = { post = function () end }
          local http_client_spy = spy.on(token_policy.http_client.backend, 'post')

          token_policy:access(context)

          assert.spy(http_client_spy).was_not_called()
        end)
      end)

      describe('and the token is not cached', function()
        setup(function()
          test_tokens_cache = TokensCache.new(60)
        end)

        it('calls the introspection endpoint and caches the result', function()
          test_backend
          .expect{
            url = introspection_url,
            method = 'POST',
            headers = { ['Authorization'] = test_basic_auth }
          }
          .respond_with{ status = 200, body = cjson.encode(test_token_info) }

          token_policy.tokens_cache = test_tokens_cache
          token_policy.http_client.backend = test_backend

          token_policy:access(context)

          assert.same(test_token_info, test_tokens_cache:get(test_access_token))
          assert.are.same(ngx.decode_args(test_backend.get_requests()[1].body),
              { token = "test", token_type_hint = "access_token" })
        end)
      end)
    end)

    after_each(function()
      test_backend.verify_no_outstanding_expectations()
    end)
  end)
end)
