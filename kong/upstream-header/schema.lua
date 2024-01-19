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
local pl_template = require "pl.template"
local tx = require "pl.tablex"
local typedefs = require "kong.db.schema.typedefs"
local validate_header_name = require("kong.tools.utils").validate_header_name

local upstream_param_array_record = {
  type = "record",
  fields = {
    { header_key = {
      type = "string",
      required = true,
    }, },
    { header_value = {
      type = "string",
      required = true,
    }, },
  },
}

local upstream_headers_array = {
  type = "array",
  default = {},
  elements = upstream_param_array_record,
}

return {
  name = "upstream-header",
  fields = {
    { config = {
        type = "record",
        fields = {
          { upstream_headers  = upstream_headers_array },
        }
      },
    },
  }
}
