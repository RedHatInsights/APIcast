-- Request Unbuffered policy
-- This policy will disable request buffering

local policy = require('apicast.policy')
local _M = policy.new('request_unbuffered')

local new = _M.new

--- Initialize a buffering
-- @tparam[opt] table config Policy configuration.
function _M.new(config)
  local self = new(config)
  return self
end

function _M:export()
  return {
    request_unbuffered = true,
  }
end

return _M
