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
local Lplus = require "kong.plugins.sensitive-word-review.Lplus"
local ReadIlleagal = Lplus.Class("ReadIlleagal")

local def = ReadIlleagal.define

def.field("table").words = nil

def.static("string","=>", ReadIlleagal).ReadIlleagalWord = function(config)
    local readIlleagal = ReadIlleagal()
    readIlleagal:Init(config)
    return readIlleagal
end

def.method("string").Init = function(self,config)
    local lines = {}
    local delimiterWord = ","
    if string.find(config, ",") then
        for matchWord in (config..delimiterWord):gmatch("(.-)"..delimiterWord) do
            table.insert(lines, matchWord)
        end
    end
    self.words = lines
end
ReadIlleagal.Commit()
--_G.ReadIlleagal = ReadIlleagal
--local eeadIlleagalWord = ReadIlleagal.ReadIlleagalWord()
--for i, arr in ipairs(eeadIlleagalWord.words) do
--    print("第" .. i .. "行：" .. arr)
--end
return ReadIlleagal

-- 打开要读取的文件
--function getIlleagalWord()
--
--    local file = io.open("illegal.txt", "r") -- 这里需要替换为真正的文件名或路径
--    if not file then
--        print("无法打开文件！")
--    else
--        local lines = {} -- 存放每一行的数组
--
--        local delimiter = "|"
--        local delimiterWord = ","
--        for line in file:lines() do
--
--            for match in (line..delimiter):gmatch("(.-)"..delimiter) do
--                if string.find(match, ",") then
--                    for matchWord in (match..delimiterWord):gmatch("(.-)"..delimiterWord) do
--                        table.insert(lines, matchWord)
--                    end
--                else
--                end
--
--            end
--        end
--        print(type(lines))
--        file:close() -- 关闭文件
--        return lines
--        ---- 输出结果
--        --for i, arr in ipairs(lines) do
--        --    print("第" .. i .. "行：" .. arr)
--        --end
--    end
--end
