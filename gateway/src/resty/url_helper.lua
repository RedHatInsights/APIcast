local tonumber = tonumber
local format = string.format

local resty_url = require('resty.url')
local core_base = require('resty.core.base')
local str_find = string.find
local str_sub = string.sub
local new_tab = core_base.new_tab

local _M = {}

function _M.split_path(path)
    if not path then return end

    local start = str_find(path, '?', 1, true)

    if start then
        return str_sub(path, 1, start - 1), str_sub(path, start + 1)
    else
        return path
    end
end



function _M.parse_url(url)
    local parsed, err = resty_url.split(url)

    if err then return nil, err end

    local uri = new_tab(0, 6)

    uri.scheme = parsed[1]
    uri.user = parsed[2]
    uri.password = parsed[3]
    uri.host = parsed[4]
    uri.port = tonumber(parsed[5])

    uri.path, uri.query = _M.split_path(parsed[6])

    return uri
end

-- absolute_url formats an absolute URI from a table containing the fields: scheme, host, port and path
-- From https://datatracker.ietf.org/doc/html/rfc7230#section-5.3.2
-- a client MUST send the target URI in absolute-form as the request-target
-- An example absolute-form of request-line would be:
-- GET http://www.example.org/pub/WWW/TheProject.html HTTP/1.1
-- @param uri the table
-- @return absolute URI
function _M.absolute_url(uri)
    assert(type(uri) == 'table', 'the value of uri is not table')
    local port = uri.port
    local default_port = resty_url.default_port(uri.scheme)

    local host = uri.host
    if port and port ~= default_port then
        host = format('%s:%s', uri.host, port)
    end

    return format('%s://%s%s',
            uri.scheme,
            host,
            uri.path or '/'
    )
end

return _M
