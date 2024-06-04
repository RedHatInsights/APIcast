local _M = {
  VERSION = '0.0.1'
}

local ngx_now = ngx.now

local len = string.len
local sub = string.sub
local errlog = require('ngx.errlog')

local open = io.open
local unpack = unpack
local pl_utils = require "pl.utils"

function _M.timer(name, fun, ...)
  local start = ngx_now()
  ngx.log(ngx.INFO, 'benchmark start ' .. name .. ' at ' .. start)
  local ret = { fun(...) }
  local time = ngx_now() - start
  ngx.log(ngx.INFO, 'benchmark ' .. name .. ' took ' .. time)
  return unpack(ret)
end

function _M.read_file(file)
  local handle, err = open(file, 'r')
  if not handle then return nil, err end
  local output, read_err = handle:read("*a")
  handle:close()
  if not output then
    return nil, read_err
  end
  return output
end

local max_log_line_len = 4096-96 -- 96 chars for our error message

function _M.system(command)
  command = '(' .. command ..')'
  ngx.log(ngx.DEBUG, 'os execute ', command)
  local success, retcode, stdout, stderr = pl_utils.executeex(command)

  -- os.execute returns exit code as first return value on OSX
  -- even though the documentation says otherwise (true/false)
  if success == 0 or success == true then
    local max = len(stderr)
    if max > 0 then
      errlog.raw_log(ngx.WARN, 'os execute stderr:')

      for start=0, max , max_log_line_len do
        errlog.raw_log(ngx.WARN, sub(stderr, start, start + max_log_line_len - 1))
      end
    end

    return stdout
  else
    return stdout, stderr, retcode or success
  end
end

function _M.to_hash(table)
  local t = {}

  if not table then
    return t
  end

  for i = 1, #table do
    t[table[i]] = true
  end

  return t
end

return _M
