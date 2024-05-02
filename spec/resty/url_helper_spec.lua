local _M = require 'resty.url_helper'


describe('URL parser', function()
  describe('.absolute_url', function()
    local absolute_url = _M.absolute_url
    local config = '{}'

    it('when port is specified and does not match default port for http', function()
      local uri = {
        scheme = "http",
        host = "example.com",
        port = 8080,
        path = "/some/path",
      }

      assert.same('http://example.com:8080/some/path',
        absolute_url(uri))
    end)

    it('when port is specified and matches default port for http', function()
      local uri = {
        scheme = "http",
        host = "example.com",
        port = 80,
        path = "/some/path",
      }

      assert.same('http://example.com/some/path',
        absolute_url(uri))
    end)

    it('when port is specified and does not match default port for https', function()
      local uri = {
        scheme = "https",
        host = "example.com",
        port = 8443,
        path = "/some/path",
      }

      assert.same('https://example.com:8443/some/path',
        absolute_url(uri))
    end)

    it('when port is specified and matches default port for https', function()
      local uri = {
        scheme = "https",
        host = "example.com",
        port = 443,
        path = "/some/path",
      }

      assert.same('https://example.com/some/path',
        absolute_url(uri))
    end)

    it('when port is not specified for http', function()
      local uri = {
        scheme = "http",
        host = "example.com",
        path = "/some/path",
      }

      assert.same('http://example.com/some/path',
        absolute_url(uri))
    end)

    it('when port is not specified for https', function()
      local uri = {
        scheme = "https",
        host = "example.com",
        path = "/some/path",
      }

      assert.same('https://example.com/some/path',
        absolute_url(uri))
    end)

    it('when uri is nil, asserts', function()
      local uri = nil
      local res, err = pcall(absolute_url, uri)

      assert.is_falsy(res)
      assert.is_truthy(err)
    end)

    it('when uri is not a table, asserts', function()
      local uri = "some string"
      local res, err = pcall(absolute_url, uri)
      assert.is_falsy(res)
      assert.is_truthy(err)

      uri = 1
      local res, err = pcall(absolute_url, uri)
      assert.is_falsy(res)
      assert.is_truthy(err)
    end)
  end)
end)
