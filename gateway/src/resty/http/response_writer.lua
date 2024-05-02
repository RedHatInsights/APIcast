local fmt = string.format
local str_lower = string.lower

local _M = {
}

local cr_lf = "\r\n"

-- http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.5.1
local HOP_BY_HOP_HEADERS = {
    ["connection"]          = true,
    ["keep-alive"]          = true,
    ["proxy-authenticate"]  = true,
    ["proxy-authorization"] = true,
    ["te"]                  = true,
    ["trailers"]            = true,
    ["transfer-encoding"]   = true,
    ["upgrade"]             = true,
    ["content-length"]      = true, -- Not strictly hop-by-hop, but Nginx will deal
                                    -- with this (may send chunked for example).
}

local function send(socket, data)
    if not data or data == '' then
        ngx.log(ngx.DEBUG, 'skipping sending nil')
        return
    end

    return socket:send(data)
end

-- write_response writes response body reader to sock in the HTTP/1.x server response format,
-- The connection is closed if send() fails or when returning a non-zero
function _M.send_response(sock, response, chunksize)
    local bytes, err
    chunksize = chunksize or 65536

    if not response then
        ngx.log(ngx.ERR, "no response provided")
        return
    end

    if not sock then
        return nil, "socket not initialized yet"
    end

    -- Status line
    -- TODO: get HTTP version from request
    local status = fmt("HTTP/%d.%d %03d %s\r\n", 1, 1, response.status, response.reason)
    bytes, err = send(sock, status)
    if not bytes then
        return nil, "failed to send status line, err: " .. (err or "unknown")
    end

     -- Filter out hop-by-hop headeres
     for k, v in pairs(response.headers) do
        if not HOP_BY_HOP_HEADERS[str_lower(k)] then
            local header = fmt("%s: %s\r\n", k, v)
            bytes, err = sock:send(header)
            if not bytes then
              return nil, "failed to send status line, err: " .. (err or "unknown")
            end
        end
     end

    -- End-of-header
    bytes, err = send(sock, cr_lf)
    if not bytes then
        return nil, "failed to send status line, err: " .. (err or "unknown")
    end

    -- Write body
    local reader = response.body_reader
    repeat
        local chunk, read_err

        chunk, read_err = reader(chunksize)
        if read_err then
            return nil, "failed to read response body, err: " .. (err or "unknown")
        end

        if chunk then
            bytes, err = send(sock, chunk)
            if not bytes then
                return nil, "failed to send response body, err: " .. (err or "unknown")
            end
        end
    until not chunk

    return true, nil
end

return _M
