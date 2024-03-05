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
local pghandler = require "kong.plugins.sensitive-word-review.pghandler"
local ngx = ngx

function findSensitiveWords(conf,str)
    --if row and row.value ~= null then
    --  return row.value
    --end
    local initSensitiveWords = ngx.shared.initSensitiveWords
    if initSensitiveWords == nil then
        if conf.useInit and conf.useInit == true then
            local row, err = pghandler.find("init")
            if err then
                return nil, err
            end
            initSensitiveWords = row.value
            ngx.shared.initSensitiveWords = row.value
        else
            initSensitiveWords = ''
            ngx.shared.initSensitiveWords = ''
        end
    end
    local addSensitiveWords = ngx.shared.addSensitiveWords
    if addSensitiveWords == nil then
        ngx.shared.addSensitiveWords = conf.addSensitiveWords
    end
    local ACTrie = ngx.shared.ACTrie
    if ACTrie == nil or conf.addSensitiveWords ~= addSensitiveWords then
        ngx.shared.addSensitiveWords = conf.addSensitiveWords
        local words = initSensitiveWords
        if conf.addSensitiveWords ~= "0" then
            words = words .. "," .. conf.addSensitiveWords
        end
        local block_words_data = {}
        block_words_data = require "kong.plugins.sensitive-word-review.ReadIlleagal".ReadIlleagalWord(words).words
        ACTrie = require "kong.plugins.sensitive-word-review.ACTrie".CreateACTrie()
        if block_words_data then
            local len = #block_words_data
            for i = 1, len do
                ACTrie:Insert(block_words_data[i], i)
            end
        end
        ACTrie:BuildFail()
        ngx.shared.ACTrie = ACTrie
    end
    local acResult,test12 = ACTrie:FilterBlockedWords(str)
    return acResult,test12
end
return {
    findSensitiveWords        = findSensitiveWords,
}
