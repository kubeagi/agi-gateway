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


return {
  name = "file-log",
  fields = {
    { protocols = typedefs.protocols },
    { config = {
        type = "record",
        fields = {
          { path = { type = "string",
                     required = true,
                     match = [[^[^*&%%\`]+$]],
                     err = "not a valid filename",
          }, },
          { reopen = { type = "boolean", required = true, default = false }, },
          { custom_fields_by_lua = typedefs.lua_code },
          { envId = { type = "string", default = "0" }, },
          { envName = { type = "string", default = "0" }, },
          { groupId = { type = "string", default = "0" }, },
          { groupName = { type = "string", default = "0" }, },
          { apiId = { type = "string", default = "0" }, },
          { apiName = { type = "string", default = "0" }, },
          { host = { type = "string", default = "0" }, },
        },
    }, },
  }
}
