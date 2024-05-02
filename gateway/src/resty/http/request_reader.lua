local httpc = require "resty.resolver.http"
local ngx_req = ngx.req

local _M = {
}

local cr_lf = "\r\n"

local function test_expect(sock)
  local expect = ngx_req.get_headers()["Expect"]

  if expect == "" or ngx_req.http_version == 1.0 then
    return true
  end

  if expect and expect:lower() == "100-continue" then
    local _, err = sock:send("HTTP/1.1 100 Continue\r\n\r\n")
    if err then
        ngx.log(ngx.ERR, "failed to handle expect header, err: ", err)
        return false, err
    end
  end
  return true
end

-- chunked_reader return a body reader that translates the data read from
-- lua-resty-http client_body_reader to HTTP "chunked" format before returning it
--
-- The chunked reader return nil when the final 0-length chunk is read
local function chunked_reader(sock, chunksize)
    chunksize = chunksize or 65536
    local eof = false
    local reader = httpc:get_client_body_reader(chunksize, sock)
    if not reader then
        return nil
    end

    -- If Expect: 100-continue is sent upstream, lua-resty-http will only call
    -- _send_body after receiving "100 Continue". So it's safe to process the
    -- Expect header and send "100 Continue" downstream here.
    local ok, err = test_expect(sock)
    if not ok then
      return nil, err
    end

    return function()
        if eof then
            return nil
        end

        local buffer, err = reader()
        if err then
            return nil, err
        end
        if buffer then
            local chunk = string.format("%x\r\n", #buffer) .. buffer .. cr_lf
            return chunk
        else
            eof = true
            return "0\r\n\r\n"
        end
    end
end

function _M.get_client_body_reader(sock, chunksize, is_chunked)
    if is_chunked then
        return chunked_reader(sock, chunksize)
    else
        return httpc:get_client_body_reader(chunksize, sock)
    end
end

return _M
