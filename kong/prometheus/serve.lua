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
local lapis = require "lapis"
local prometheus = require "kong.plugins.prometheus.exporter"


local kong = kong


local app = lapis.Application()


app.default_route = function(self)
  local path = self.req.parsed_url.path:match("^(.*)/$")

  if path and self.app.router:resolve(path, self) then
    return

  elseif self.app.router:resolve(self.req.parsed_url.path .. "/", self) then
    return
  end

  return self.app.handle_404(self)
end


app.handle_404 = function(self) -- luacheck: ignore 212
  local body = '{"message":"Not found"}'
  ngx.status = 404
  ngx.header["Content-Type"] = "application/json; charset=utf-8"
  ngx.header["Content-Length"] = #body + 1
  ngx.say(body)
end


app:match("/", function()
  kong.response.exit(200, "Kong Prometheus exporter, visit /metrics")
end)


app:match("/metrics", function()
  prometheus:collect()
end)


return {
  prometheus_server = function()
    return lapis.serve(app)
  end,
}
