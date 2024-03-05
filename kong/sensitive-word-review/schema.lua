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
  name = "sensitive-word-review",
  fields = {
    { protocols = typedefs.protocols },
    { config = {
        type = "record",
        fields = {
          { addSensitiveWords = { type = "string", default = "0" }, },
          { supplier = { type = "string", default = "local" }, },
          { useInit = { type = "boolean",  default = false }, },
        },
    }, },
  }
}
