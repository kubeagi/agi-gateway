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
require "kong.tools.utils" -- ffi.cdefs


local ffi = require "ffi"
local cjson = require "cjson"
local system_constants = require "lua_system_constants"
local sandbox = require "kong.tools.sandbox".sandbox
local body_transformer = require "kong.plugins.response-transformer.body_transformer"
local is_json_body = body_transformer.is_json_body
local utils = require("kong.tools.utils")
local inflate_gzip = utils.inflate_gzip
local concat = table.concat
local ngx = ngx
local kong = kong


local O_CREAT = system_constants.O_CREAT()
local O_WRONLY = system_constants.O_WRONLY()
local O_APPEND = system_constants.O_APPEND()
local S_IRUSR = system_constants.S_IRUSR()
local S_IWUSR = system_constants.S_IWUSR()
local S_IRGRP = system_constants.S_IRGRP()
local S_IROTH = system_constants.S_IROTH()


local oflags = bit.bor(O_WRONLY, O_CREAT, O_APPEND)
local mode = ffi.new("int", bit.bor(S_IRUSR, S_IWUSR, S_IRGRP, S_IROTH))


local sandbox_opts = { env = { kong = kong, ngx = ngx } }


local C = ffi.C

local function read_json_body(body)
  if body then
    return cjson.decode(body)
  end
end
-- fd tracking utility functions
local file_descriptors = {}

-- Log to a file.
-- @param `conf`     Configuration table, holds http endpoint details
-- @param `message`  Message to be logged
local function log(conf, message)
  if conf and message then
    message.envId = conf.envId
    message.envName = conf.envName
    message.groupId = conf.groupId
    message.groupName = conf.groupName
    message.apiId = conf.apiId
    message.apiName = conf.apiName
    message.host = conf.host
    message.total_tokens = ngx.ctx.total_tokens
    message.prompt_tokens = ngx.ctx.prompt_tokens
    message.completion_tokens = ngx.ctx.completion_tokens
  end
  local msg = cjson.encode(message) .. "\n"
  local fd = file_descriptors[conf.path]

  if fd and conf.reopen then
    -- close fd, we do this here, to make sure a previously cached fd also
    -- gets closed upon dynamic changes of the configuration
    C.close(fd)
    file_descriptors[conf.path] = nil
    fd = nil
  end

  if not fd then
    fd = C.open(conf.path, oflags, mode)
    if fd < 0 then
      local errno = ffi.errno()
      kong.log.err("failed to open the file: ", ffi.string(C.strerror(errno)))

    else
      file_descriptors[conf.path] = fd
    end
  end

  C.write(fd, msg, #msg)
end


local FileLogHandler = {
  PRIORITY = 9,
  VERSION = "2.1.0",
}


function FileLogHandler:log(conf)
  if conf.custom_fields_by_lua then
    local set_serialize_value = kong.log.set_serialize_value
    for key, expression in pairs(conf.custom_fields_by_lua) do
      set_serialize_value(key, sandbox(expression, sandbox_opts)())
    end
  end

  local message = kong.log.serialize()
  log(conf, message)
end

function FileLogHandler:body_filter(conf)
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

return FileLogHandler
