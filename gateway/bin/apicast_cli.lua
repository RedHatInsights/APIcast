#!/usr/bin/env resty
-- This Lua helper is going to be executed by resty to detect if lua-rover is available.
-- And if so then run setup and lock down load paths to what is defined in the Roverfile + openresty libraries.
local ok, setup = pcall(require, 'rover.setup')
local re = require('ngx.re')

local function default_resty_path()
    local handle = io.popen([[/usr/bin/env -i resty -e 'print(package.path)']])
    local result = handle:read("*l")
    handle:close()
    return result
end

-- get the default package.path and strip out paths for shared code
local function default_package_path()
    local sep = ';'
    local filtered = {}
    local LUA_DEFAULT_PATH = default_resty_path()
    local contains = function(str, pattern) return str:find(pattern, 1, true) end
    local paths = re.split(LUA_DEFAULT_PATH or '', sep, 'oj')

    for i=1,#paths do
        local path = paths[i]

        if not contains(path, '/site/') and
           not contains(path, '/share/') and
           path:find('^/') then
            table.insert(filtered, path)
        end
    end

    return table.concat(filtered, sep)
end

if ok then
    setup()
    -- Use not only rover paths but also code shipped with OpenResty.
    -- Rover sets it up to Roverfile defined dependencies only.
    -- But APIcast needs to access libraries distributed with OpenResty.
    package.path = package.path ..';' .. default_package_path()
    -- Load APIcast and dependencies
    require('apicast.executor')
else
    package.path = './src/?.lua;' .. package.path
end

require('apicast.cli')(arg)
