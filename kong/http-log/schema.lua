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
local typedefs = require "kong.db.schema.typedefs"
local url = require "socket.url"

return {
  name = "http-log",
  fields = {
    { protocols = typedefs.protocols },
    { config = {
        type = "record",
        fields = {
          -- NOTE: any field added here must be also included in the handler's get_queue_id method
          { http_endpoint = typedefs.url({ required = true }) },
          { method = { type = "string", default = "POST", one_of = { "POST", "PUT", "PATCH" }, }, },
          { content_type = { type = "string", default = "application/json", one_of = { "application/json" }, }, },
          { timeout = { type = "number", default = 10000 }, },
          { keepalive = { type = "number", default = 60000 }, },
          { retry_count = { type = "integer", default = 10 }, },
          { queue_size = { type = "integer", default = 1 }, },
          { flush_timeout = { type = "number", default = 2 }, },
          { headers = typedefs.headers {
            keys = typedefs.header_name {
              match_none = {
                {
                  pattern = "^[Hh][Oo][Ss][Tt]$",
                  err = "cannot contain 'Host' header",
                },
                {
                  pattern = "^[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Ll][Ee][nn][Gg][Tt][Hh]$",
                  err = "cannot contain 'Content-Length' header",
                },
                {
                  pattern = "^[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]$",
                  err = "cannot contain 'Content-Type' header",
                },
              },
            },
          } },
          { custom_fields_by_lua = typedefs.lua_code },
          { envId = { type = "string", default = "0" }, },
          { envName = { type = "string", default = "0" }, },
          { groupId = { type = "string", default = "0" }, },
          { groupName = { type = "string", default = "0" }, },
          { apiId = { type = "string", default = "0" }, },
          { apiName = { type = "string", default = "0" }, },
          { host = { type = "string", default = "0" }, },
        },
        custom_validator = function(config)
          -- check no double userinfo + authorization header
          local parsed_url = url.parse(config.http_endpoint)
          if parsed_url.userinfo and config.headers then
            for hname, hvalue in pairs(config.headers) do
              if hname:lower() == "authorization" then
                return false, "specifying both an 'Authorization' header and user info in 'http_endpoint' is not allowed"
              end
            end
          end
          return true
        end,
      },
    },
  },
}
