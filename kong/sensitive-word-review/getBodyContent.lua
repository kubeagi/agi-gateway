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
local ngx = ngx
local cjson = require "cjson.safe"
local kong = kong

local function parse_json(body)
    if body then
        local status, res = pcall(cjson.decode, body)
        if status then
            return res
        end
    end
end

function getRequestContent()
    local rawbody = kong.request.get_raw_body()
    local body = parse_json(rawbody)
    local msg = body["messages"]
    if msg == nil or msg == "" or #msg<1 then
        return nil
    end
    local str = ""
    for i = 1, #msg do
        if msg[i] ~= nil and type(msg[i]) == 'table' and msg[i].content ~=nil and type(msg[i].content) == 'string' then
            str = str .. msg[i].content
        end
    end
    return str
end
return {
    getRequestContent        = getRequestContent,
}
