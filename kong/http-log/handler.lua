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
local BatchQueue = require "kong.tools.batch_queue"
local cjson = require "cjson"
local url = require "socket.url"
local http = require "resty.http"
local table_clear = require "table.clear"
local sandbox = require "kong.tools.sandbox".sandbox
local body_transformer = require "kong.plugins.response-transformer.body_transformer"
local is_json_body = body_transformer.is_json_body
local utils = require("kong.tools.utils")
local inflate_gzip = utils.inflate_gzip
local ngx = ngx

local kong = kong
local ngx = ngx
local encode_base64 = ngx.encode_base64
local tostring = tostring
local tonumber = tonumber
local concat = table.concat
local fmt = string.format
local pairs = pairs


local sandbox_opts = { env = { kong = kong, ngx = ngx } }


local queues = {} -- one queue per unique plugin config
local parsed_urls_cache = {}
local headers_cache = {}
local params_cache = {
  ssl_verify = false,
  headers = headers_cache,
}

local function read_json_body(body)
  if body then
    return cjson.decode(body)
  end
end
-- Parse host url.
-- @param `url` host url
-- @return `parsed_url` a table with host details:
-- scheme, host, port, path, query, userinfo
local function parse_url(host_url)
  local parsed_url = parsed_urls_cache[host_url]

  if parsed_url then
    return parsed_url
  end

  parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == "http" then
      parsed_url.port = 80
    elseif parsed_url.scheme == "https" then
      parsed_url.port = 443
    end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end

  parsed_urls_cache[host_url] = parsed_url

  return parsed_url
end


-- Sends the provided payload (a string) to the configured plugin host
-- @return true if everything was sent correctly, falsy if error
-- @return error message if there was an error
local function send_payload(self, conf, payload)
  local method = conf.method
  local timeout = conf.timeout
  local keepalive = conf.keepalive
  local content_type = conf.content_type
  local http_endpoint = conf.http_endpoint

  local parsed_url = parse_url(http_endpoint)
  local host = parsed_url.host
  local port = tonumber(parsed_url.port)

  local httpc = http.new()
  httpc:set_timeout(timeout)

  table_clear(headers_cache)
  if conf.headers then
    for h, v in pairs(conf.headers) do
      headers_cache[h] = v
    end
  end

  headers_cache["Host"] = parsed_url.host
  headers_cache["Content-Type"] = content_type
  headers_cache["Content-Length"] = #payload
  if parsed_url.userinfo then
    headers_cache["Authorization"] = "Basic " .. encode_base64(parsed_url.userinfo)
  end

  params_cache.method = method
  params_cache.body = payload
  params_cache.keepalive_timeout = keepalive

  local url = fmt("%s://%s:%d%s", parsed_url.scheme, parsed_url.host, parsed_url.port, parsed_url.path)

  -- note: `httpc:request` makes a deep copy of `params_cache`, so it will be
  -- fine to reuse the table here
  local res, err = httpc:request_uri(url, params_cache)
  if not res then
    return nil, "failed request to " .. host .. ":" .. tostring(port) .. ": " .. err
  end

  -- always read response body, even if we discard it without using it on success
  local response_body = res.body
  local success = res.status < 400
  local err_msg

  if not success then
    err_msg = "request to " .. host .. ":" .. tostring(port) ..
              " returned status code " .. tostring(res.status) .. " and body " ..
              response_body
  end

  return success, err_msg
end


local function json_array_concat(entries)
  return "[" .. concat(entries, ",") .. "]"
end


local function get_queue_id(conf)
  return fmt("%s:%s:%s:%s:%s:%s",
             conf.http_endpoint,
             conf.method,
             conf.content_type,
             conf.timeout,
             conf.keepalive,
             conf.retry_count,
             conf.queue_size,
             conf.flush_timeout)
end


local HttpLogHandler = {
  PRIORITY = 12,
  VERSION = "2.1.1",
}


function HttpLogHandler:log(conf)
  if conf.custom_fields_by_lua then
    local set_serialize_value = kong.log.set_serialize_value
    for key, expression in pairs(conf.custom_fields_by_lua) do
      set_serialize_value(key, sandbox(expression, sandbox_opts)())
    end
  end
  local message = kong.log.serialize()
  if conf and message then
    message.env_id = conf.envId
    message.env_name = conf.envName
    message.group_id = conf.groupId
    message.group_name = conf.groupName
    message.api_id = conf.apiId
    message.api_name = conf.apiName
    message.host = conf.host
    message.total_tokens = ngx.ctx.total_tokens
    message.prompt_tokens = ngx.ctx.prompt_tokens
    message.completion_tokens = ngx.ctx.completion_tokens
  end

  local entry = cjson.encode(message)

  local queue_id = get_queue_id(conf)
  local q = queues[queue_id]
  if not q then
    -- batch_max_size <==> conf.queue_size
    local batch_max_size = conf.queue_size or 1
    local process = function(entries)
      local payload = batch_max_size == 1
                      and entries[1]
                      or  json_array_concat(entries)
      return send_payload(self, conf, payload)
    end

    local opts = {
      retry_count    = conf.retry_count,
      flush_timeout  = conf.flush_timeout,
      batch_max_size = batch_max_size,
      process_delay  = 0,
    }

    local err
    q, err = BatchQueue.new(process, opts)
    if not q then
      kong.log.err("could not create queue: ", err)
      return
    end
    queues[queue_id] = q
  end

  q:add(entry)
end

function HttpLogHandler:body_filter(conf)
  local isLimit =kong.response.get_header("TokenLimit-Limit-Exe")
  if isLimit then
    return
  end
  local total_tokens = ngx.ctx.total_tokens
  local prompt_tokens = ngx.ctx.prompt_tokens
  local completion_tokens = ngx.ctx.completion_tokens
  if total_tokens and prompt_tokens and completion_tokens then
    return
  end
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
      end
      if json_body and type(json_body["usage"]) =="table" and json_body["usage"] ~= nil and type(json_body["usage"]["total_tokens"]) ~="table" and json_body["usage"]["total_tokens"] ~=nil and type(json_body["usage"]["input_tokens"]) ~="table"  and json_body["usage"]["input_tokens"] ~=nil and type(json_body["usage"]["output_tokens"]) ~="table"  and json_body["usage"]["output_tokens"] ~=nil then
        ngx.ctx.total_tokens =json_body["usage"]["total_tokens"]
        ngx.ctx.prompt_tokens = json_body["usage"]["input_tokens"]
        ngx.ctx.completion_tokens = json_body["usage"]["output_tokens"]
      end
      ngx.arg[1] = chunks
    else
      ctx.rt_body_chunks[ctx.rt_body_chunk_number] = chunk
      ctx.rt_body_chunk_number = ctx.rt_body_chunk_number + 1
      ngx.arg[1] = nil
    end
  end
end

return HttpLogHandler
