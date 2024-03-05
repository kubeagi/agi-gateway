--Copyright 2024 agi-gateway.
--
--Licensed under the Apache License, Version 2.0 (the "License");
--you may not use this file except in compliance with the License.
--You may obtain a copy of the License at
--
--http://www.apache.org/licenses/LICENSE-2.0
--
--Unless required by applicable law or agreed to in writing, software
--distributed under the License is distributed on an "AS IS" BASIS,
--WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--See the License for the specific language governing permissions and
--limitations under the License.
local timestamp = require "kong.tools.timestamp"
local policies = require "kong.plugins.token-limiting.policies"
local utils = require("kong.tools.utils")
local inflate_gzip = utils.inflate_gzip
local deflate_gzip = utils.deflate_gzip

local kong = kong
local ngx = ngx
local max = math.max
local time = ngx.time
local floor = math.floor
local pairs = pairs
local error = error
local tostring = tostring
local timer_at = ngx.timer.at

local concat = table.concat
local lower = string.lower
local find = string.find
local cjson = require "cjson.safe"
local BasePlugin = require "kong.plugins.base_plugin"

local kong_service_request_get_header = kong.request.get_header
local EMPTY = {}
local EXPIRATION = require "kong.plugins.token-limiting.expiration"


local TOKENLIMIT_LIMIT     = "TokenLimit-Limit"
local TOKENLIMIT_REMAINING = "TokenLimit-Remaining"
local TOKENLIMIT_RESET     = "TokenLimit-Reset"
local RETRY_AFTER         = "Retry-After"
local TOKENLIMIT_LIMIT_EXE     = "TokenLimit-Limit-Exe"

local X_TOKENLIMIT_LIMIT = {
  second = "X-TokenLimit-Limit-Second",
  minute = "X-TokenLimit-Limit-Minute",
  hour   = "X-TokenLimit-Limit-Hour",
  day    = "X-TokenLimit-Limit-Day",
  month  = "X-TokenLimit-Limit-Month",
  year   = "X-TokenLimit-Limit-Year",
  total   = "X-TokenLimit-Limit-Total",
}

local X_TOKENLIMIT_REMAINING = {
  second = "X-TokenLimit-Remaining-Second",
  minute = "X-TokenLimit-Remaining-Minute",
  hour   = "X-TokenLimit-Remaining-Hour",
  day    = "X-TokenLimit-Remaining-Day",
  month  = "X-TokenLimit-Remaining-Month",
  year   = "X-TokenLimit-Remaining-Year",
  total   = "X-TokenLimit-Remaining-Total",
}


--local TokenLimitingHandler = {}
local TokenLimitingHandler = BasePlugin:extend()

function TokenLimitingHandler:new()
  TokenLimitingHandler.super.new(self, "TokenLimiting")
end

TokenLimitingHandler.PRIORITY = 901
TokenLimitingHandler.VERSION = "2.4.0"

local function is_json_body(content_type)
  return content_type and find(lower(content_type), "application/json", nil, true)
end

local function read_json_body(body)
  if body then
    return cjson.decode(body)
  end
end

local function get_identifier(conf)
  local identifier

  if conf.limit_by == "service" then
    identifier = (kong.router.get_service() or
                  EMPTY).id
  elseif conf.limit_by == "consumer" then
    identifier = (kong.client.get_consumer() or
                  kong.client.get_credential() or
                  EMPTY).id

  elseif conf.limit_by == "credential" then
    identifier = (kong.client.get_credential() or
                  EMPTY).id

  elseif conf.limit_by == "header" then
    identifier = kong.request.get_header(conf.header_name)

  elseif conf.limit_by == "path" then
    local req_path = kong.request.get_path()
    if req_path == conf.path then
      identifier = req_path
    end
  end

  return identifier or kong.client.get_forwarded_ip()
end


local function get_usage(conf, identifier, current_timestamp, limits,current_request)
  local usage = {}
  local stop
  if conf.total and conf.total >0 then
    local current_usage, err = policies[conf.policy].usage(conf, identifier, "total", current_timestamp)
    if err then
      return nil, nil, err
    end

    -- What is the current usage for the configured limit name?
    local remaining = conf.total - current_usage - current_request
    -- Recording usage
    usage["total"] = {
      limit = conf.total,
      remaining = remaining,
    }

    if remaining <= 0 then
      stop = "total"
    end
    return usage, stop
  end
  for period, limit in pairs(limits) do
    local current_usage, err = policies[conf.policy].usage(conf, identifier, period, current_timestamp)
    if err then
      return nil, nil, err
    end

    -- What is the current usage for the configured limit name?
    local remaining = limit - current_usage - current_request
    -- Recording usage
    usage[period] = {
      limit = limit,
      remaining = remaining,
    }

    if remaining <= 0 then
      stop = period
    end
  end

  return usage, stop
end


local function increment(premature, conf, ...)
  if premature then
    return
  end

  policies[conf.policy].increment(conf, ...)
end


function TokenLimitingHandler:access(conf)
  local tokeCount = kong_service_request_get_header("x-request-token-count")
  if tokeCount == nil or tokeCount==0 then
    return
  end
  local current_timestamp = time() * 1000

  -- Consumer is identified by ip address or authenticated_credential id
  local identifier = get_identifier(conf)
  local fault_tolerant = conf.fault_tolerant

  -- Load current metric for configured period
  local limits = {
    second = conf.second,
    minute = conf.minute,
    hour = conf.hour,
    day = conf.day,
    month = conf.month,
    year = conf.year,
    total = conf.total,
  }

  local usage, stop, err = get_usage(conf, identifier, current_timestamp, limits, tokeCount)
  if err then
    if not fault_tolerant then
      return error(err)
    end

    kong.log.err("failed to get usage: ", tostring(err))
  end
  if usage then
    -- Adding headers
    local reset
    local headers
    if not conf.hide_client_headers then
      headers = {}
      local timestamps
      local limit
      local window
      local remaining
      for k, v in pairs(usage) do
        local current_limit = v.limit
        local current_window = EXPIRATION[k]
        local current_remaining = v.remaining
        if stop == nil or stop == k then
          current_remaining = current_remaining - tokeCount
        end
        current_remaining = max(0, current_remaining)

        if not limit or (current_remaining < remaining)
                     or (current_remaining == remaining and
                         current_window > window)
        then
          limit = current_limit
          window = current_window
          remaining = current_remaining

          if not timestamps then
            timestamps = timestamp.get_timestamps(current_timestamp)
          end
          if conf.total and conf.total>0 then
            reset = 9999999
          else
            reset = max(1, window - floor((current_timestamp - timestamps[k]) / 1000))
          end
        end

        headers[X_TOKENLIMIT_LIMIT[k]] = current_limit
        headers[X_TOKENLIMIT_REMAINING[k]] = current_remaining
      end

      headers[TOKENLIMIT_LIMIT] = limit
      headers[TOKENLIMIT_REMAINING] = remaining
      headers[TOKENLIMIT_RESET] = reset
    end

    -- If limit is exceeded, terminate the request
    if stop then
      headers = headers or {}
      headers[RETRY_AFTER] = reset
      headers[TOKENLIMIT_LIMIT_EXE] = "true"
      return kong.response.error(429, "API token limit exceeded", headers)
    end

    if headers then
      kong.response.set_headers(headers)
    end
  end

  --local ok, err = timer_at(0, increment, conf, limits, identifier, current_timestamp, 1)
  --if not ok then
  --  kong.log.err("failed to create timer: ", err)
  --end
end


function TokenLimitingHandler:body_filter(conf)
  local isLimit =kong.response.get_header(TOKENLIMIT_LIMIT_EXE)
  if isLimit then
    return
  end
  TokenLimitingHandler.super.body_filter(self)
  if is_json_body(kong.response.get_header("Content-Type")) then
    local ctx = ngx.ctx
    local chunk, eof = ngx.arg[1], ngx.arg[2]

    ctx.rt_body_chunks = ctx.rt_body_chunks or {}
    ctx.rt_body_chunk_number = ctx.rt_body_chunk_number or 1

    if eof then
      local chunks = concat(ctx.rt_body_chunks)
      local encode = kong.response.get_header("content-encoding")
      local json_body
      if encode and encode == "gzip" then
        local inflateGzip = inflate_gzip(chunks)
        json_body = read_json_body(inflateGzip)
      else
        json_body = read_json_body(chunks)
      end
      if json_body and type(json_body["usage"]) =="table" and json_body["usage"] ~= nil and type(json_body["usage"]["total_tokens"]) ~="table" and json_body["usage"]["total_tokens"] ~=nil and type(json_body["usage"]["prompt_tokens"]) ~="table"  and json_body["usage"]["prompt_tokens"] ~=nil and type(json_body["usage"]["completion_tokens"]) ~="table"  and json_body["usage"]["completion_tokens"] ~=nil then
        ngx.ctx.total_tokens =json_body["usage"]["total_tokens"]
        ngx.ctx.prompt_tokens = json_body["usage"]["prompt_tokens"]
        ngx.ctx.completion_tokens = json_body["usage"]["completion_tokens"]
        local current_timestamp = time() * 1000
        -- Consumer is identified by ip address or authenticated_credential id
        local identifier = get_identifier(conf)
        local limits = {
          second = conf.second,
          minute = conf.minute,
          hour = conf.hour,
          day = conf.day,
          month = conf.month,
          year = conf.year,
          total = conf.total,
        }
        local ok, err = timer_at(0, increment, conf, limits, identifier, current_timestamp, json_body["usage"]["total_tokens"])
        if not ok then
          kong.log.err("failed to create timer: ", err)
        end
      end

      if json_body and type(json_body["usage"]) =="table" and json_body["usage"] ~= nil and type(json_body["usage"]["total_tokens"]) ~="table" and json_body["usage"]["total_tokens"] ~=nil and type(json_body["usage"]["input_tokens"]) ~="table"  and json_body["usage"]["input_tokens"] ~=nil and type(json_body["usage"]["output_tokens"]) ~="table"  and json_body["usage"]["output_tokens"] ~=nil then
        ngx.ctx.total_tokens =json_body["usage"]["total_tokens"]
        ngx.ctx.prompt_tokens = json_body["usage"]["input_tokens"]
        ngx.ctx.completion_tokens = json_body["usage"]["output_tokens"]
        local current_timestamp = time() * 1000
        -- Consumer is identified by ip address or authenticated_credential id
        local identifier = get_identifier(conf)
        local limits = {
          second = conf.second,
          minute = conf.minute,
          hour = conf.hour,
          day = conf.day,
          month = conf.month,
          year = conf.year,
          total = conf.total,
        }
        local ok, err = timer_at(0, increment, conf, limits, identifier, current_timestamp, json_body["usage"]["total_tokens"])
        if not ok then
          kong.log.err("failed to create timer: ", err)
        end
      end
      ngx.arg[1] = chunks

    else
      ctx.rt_body_chunks[ctx.rt_body_chunk_number] = chunk
      ctx.rt_body_chunk_number = ctx.rt_body_chunk_number + 1
      ngx.arg[1] = nil
    end
  end
end
return TokenLimitingHandler
