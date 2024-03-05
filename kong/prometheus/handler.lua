local basic_serializer = require "kong.plugins.log-serializers.basic"
local body_transformer = require "kong.plugins.response-transformer.body_transformer"
local is_json_body = body_transformer.is_json_body
local ngx = ngx
local concat = table.concat
local lower = string.lower
local cjson = require "cjson"
local prometheus = require "kong.plugins.prometheus.exporter"
local kong = kong
local utils = require("kong.tools.utils")
local inflate_gzip = utils.inflate_gzip

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
local function read_json_body(body)
  if body then
    return cjson.decode(body)
  end
end
prometheus.init()


local PrometheusHandler = {
  PRIORITY = 13,
  VERSION  = "1.6.0",
}

function PrometheusHandler.init_worker()
  prometheus.init_worker()
end


function PrometheusHandler.log(self, conf)
  local message = kong.log.serialize()

  local serialized = {}
  if conf.per_consumer and message.consumer ~= nil then
    serialized.consumer = message.consumer.username
  end
  local total_tokens = ngx.ctx.total_tokens
  local prompt_tokens = ngx.ctx.prompt_tokens
  local completion_tokens = ngx.ctx.completion_tokens
  local envId = ngx.ctx.envId
  local envName = ngx.ctx.envName
  local groupId = ngx.ctx.groupId
  local groupName = ngx.ctx.groupName
  local apiId = ngx.ctx.apiId
  local apiName = ngx.ctx.apiName
  local namespace = ngx.ctx.namespace
  if total_tokens and total_tokens>0 then
    serialized.total_tokens = total_tokens
  end
  if prompt_tokens and prompt_tokens>0 then
    serialized.prompt_tokens = prompt_tokens
  end
  if completion_tokens and completion_tokens>0 then
    serialized.completion_tokens = completion_tokens
  end
  local headers = ngx.resp.get_headers()
  if headers and headers["x-request-model"] then
    serialized.model = headers["x-request-model"]
  end
  if envId  then
    serialized.envId = envId
  end
  if envName then
    serialized.envName = envName
  end
  if groupId then
    serialized.groupId = groupId
  end
  if groupName then
    serialized.groupName = groupName
  end
  if apiId then
    serialized.apiId = apiId
  end
  if apiName then
    serialized.apiName = apiName
  end
  if namespace then
    serialized.namespace = namespace
  end
  prometheus.log(message, serialized)
end

function PrometheusHandler:body_filter(conf)
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


return PrometheusHandler
