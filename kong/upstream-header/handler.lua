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
local kong = kong
local set_headers = kong.service.request.set_headers
local ngx = ngx
local decode_base64 = ngx.decode_base64
local UpstreamHeaderHandler = {
  VERSION  = "1.3.0",
  PRIORITY = 801,
}


function UpstreamHeaderHandler:access(conf)
  if conf.upstream_headers == nil or #conf.upstream_headers == 0 then
    return
  end
  local headers = {}
  for i = 1, #conf.upstream_headers do
    headers[conf.upstream_headers[i].header_key] = decode_base64(conf.upstream_headers[i].header_value)
  end
  set_headers(headers)
end


return UpstreamHeaderHandler
