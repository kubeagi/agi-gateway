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
local wordFilter = require "kong.plugins.sensitive-word-review.wordFilter"
local getBodyContent = require "kong.plugins.sensitive-word-review.getBodyContent"
local ngx = ngx
local kong = kong
local concat = table.concat
local lower = string.lower
local find = string.find
local cjson = require "cjson.safe"
local utils = require("kong.tools.utils")
local inflate_gzip = utils.inflate_gzip

local SensitiveWordReviewHandler = {
  PRIORITY = 9,
  VERSION = "1.1.0",
}
local function is_json_body(content_type)
  return content_type and find(lower(content_type), "application/json", nil, true)
end

local function read_json_body(body)
  if body then
    return cjson.decode(body)
  end
end

function SensitiveWordReviewHandler:body_filter(conf)
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
      local flag = false
      if json_body and json_body["choices"] ~= nil and type(json_body["choices"]) =="table" and #json_body["choices"] >0 then
        for i = 1, #json_body["choices"] do
          if json_body["choices"][i] ~= nil and type(json_body["choices"][i]) == 'table' and json_body["choices"][i].text ~=nil and type(json_body["choices"][i].text) == 'string' then
            local acResult,test12 = wordFilter.findSensitiveWords(conf,json_body["choices"][i].text)
            if acResult ~=nil and acResult ~= "" then
              json_body["choices"][i].text = test12
              flag = true
            end
          end
        end
        if flag then
          return kong.response.set_raw_body(cjson.encode(json_body))
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

function SensitiveWordReviewHandler:access(conf)
  local words = getBodyContent.getRequestContent()
  if words == nil or words == "" then
    return
  end
  local acResult,test12 = wordFilter.findSensitiveWords(conf,words)
  if acResult ~=nil and acResult ~= "" then
    local status = 422
    return kong.response.error(status, "request have illegal text")
  end
end
function SensitiveWordReviewHandler:log(conf)
  ngx.shared.ACTrie =nil
end
return SensitiveWordReviewHandler
