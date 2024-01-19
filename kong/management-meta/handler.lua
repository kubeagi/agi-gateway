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
local ngx = ngx


local ManagementMetaHandler = {
  PRIORITY = 9,
  VERSION = "1.1.0",
}
function ManagementMetaHandler:body_filter(conf)
  if conf then
    ngx.ctx.envId = conf.envId
    ngx.ctx.envName = conf.envName
    ngx.ctx.groupId = conf.groupId
    ngx.ctx.groupName = conf.groupName
    ngx.ctx.apiId = conf.apiId
    ngx.ctx.apiName = conf.apiName
    ngx.ctx.namespace = conf.namespace
  end
end
return ManagementMetaHandler
