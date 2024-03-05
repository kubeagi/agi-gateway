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
local Deque = require "kong.plugins.sensitive-word-review.Deque"
local Utility = require "kong.plugins.sensitive-word-review.Utility"
local ACTrie = Lplus.Class("ACTrie")
local def = ACTrie.define

def.field("table").trie = nil
def.field("table").fail = nil
def.field("table").idx = nil
def.field("table").depth = nil
def.field("number").tot = 0

def.static("=>", ACTrie).CreateACTrie = function()
    local actrie = ACTrie()
    actrie:Init()
    return actrie
end

def.method().Init = function(self)
    self.trie = {}
    self.fail = {}
    self.idx = {}
    self.depth = {}
    self.tot = 0
end

def.method("string", "number").Insert = function(self, sourceStr, id)
    if self.trie then
        local u = 0
        sourceStr = string.gsub(sourceStr, " ", "")
        local divideStr = Utility.GetDivideStringList(sourceStr)
        local len = #divideStr
        self.depth[u] = 0
        for i = 1, len do
            divideStr[i] = string.lower(divideStr[i])
            if not self.trie[u] or not self.trie[u][divideStr[i]] then
                if not self.trie[u] then
                    self.trie[u] = {}
                end
                self.tot = self.tot + 1
                self.trie[u][divideStr[i]] = self.tot
            end
            u = self.trie[u][divideStr[i]]
            self.depth[u] = i
        end
        self.idx[u] = id
    end
end

def.method().BuildFail = function(self)
    if self.trie then
        -- 设置根节点的fail
        self.fail[0] = nil
        local deque = Deque.new()
        for k, v in pairs(self.trie[0]) do
            Deque.PushBack(deque, v)
            self.fail[v] = 0
        end
        while Deque.Count(deque) > 0 do
            local front = Deque.PopFront(deque)
            if front and self.trie[front] then
                for ch, nodeID in pairs(self.trie[front]) do
                    if not self.fail[front] then
                        self.fail[front] = 0
                    end
                    if not self.trie[self.fail[front]] then
                        self.trie[self.fail[front]] = {}
                    end
                    if not self.trie[self.fail[front]][ch] then
                        local currentFail = self.fail[front]
                        local failNodeChID = nil
                        -- 构造fail
                        while true do
                            currentFail = self.fail[currentFail]
                            if currentFail then
                                if self.trie[currentFail] then
                                    failNodeChID = self.trie[currentFail][ch]
                                    if failNodeChID then
                                        self.fail[nodeID] = failNodeChID
                                        break
                                    end
                                end
                            else
                                -- 指向根节点
                                self.fail[nodeID] = 0
                                break
                            end
                        end
                    else
                        self.fail[nodeID] = self.trie[self.fail[front]][ch]
                    end
                    Deque.PushBack(deque, nodeID)
                end
            end
        end
    end
end

def.method("string", "=>", "boolean","string").IsContainBlockedWord = function(self, sourceStr)
    local isContain = false
    local illegalText = ""
    local illegalTextTable = {}
    if sourceStr ~= nil and sourceStr ~= "" then
        sourceStr = string.gsub(sourceStr, " ", "")
        local divideStr = Utility.GetDivideStringList(sourceStr)
        --print(divideStr)
        if divideStr then
            local len = #divideStr
            for i = 1, len do
                divideStr[i] = string.lower(divideStr[i])
            end
            local nodeID = 0

            if self.trie then
                for i = 1, len do
                    nodeID = self.trie[0][divideStr[i]]
                    local matchCount = 0
                    while nodeID and nodeID ~= 0 do

                        matchCount = matchCount + 1
                        if self.idx and self.idx[nodeID] then
                            illegalText = divideStr[i] .. illegalText
                            table.insert(illegalTextTable, illegalText)
                            illegalText = ""
                            isContain = true
                        end
                        if self.trie[nodeID] then
                            for key, value in pairs(self.trie[nodeID]) do
                                if key ~= nil then
                                    illegalText = illegalText .. key
                                end
                            end
                            nodeID = self.trie[nodeID][divideStr[i + matchCount]] or 0
                        else
                            break
                        end
                    end
                end
            end
        end
    end
    return isContain,table.concat(illegalTextTable, ",")
end

def.method("string", "=>", "string","string").FilterBlockedWords = function(self, sourceStr)
    local divideChars = Utility.GetDivideStringList(sourceStr)
    local illegalTextResult = ""
    local ans = ""
    local len = #divideChars
    local nodeID = 0
    local matchStartPos = {}
    local matchEndPos = {}
    local currentCh = ""
    for i = 1, len do
        currentCh = string.lower(divideChars[i])
        while nodeID ~= 0 and (not self.trie[nodeID] or not self.trie[nodeID][currentCh]) do
            nodeID = self.fail[nodeID]
        end
        nodeID = self.trie[nodeID] and self.trie[nodeID][currentCh] or 0
        local checkNodeID = nodeID
        local startPos = 0
        while checkNodeID and checkNodeID ~= 0 do
            if self.idx[checkNodeID] then
                if not matchEndPos[i] then
                    matchEndPos[i] = 1
                else
                    matchEndPos[i] = matchEndPos[i] + 1
                end
                startPos = i - self.depth[checkNodeID] + 1
                if not matchStartPos[startPos] then
                    matchStartPos[startPos] = 1
                else
                    matchStartPos[startPos] = matchStartPos[startPos] + 1
                end
            end
            checkNodeID = self.fail[checkNodeID]

        end
    end
    local stackDepth = 0
    local illegalText = ""
    local illegalTextTable = {}
    for i = 1, len do
        if matchStartPos[i] then
            stackDepth = stackDepth + matchStartPos[i]
        end
        if stackDepth > 0 then
            illegalText = illegalText .. divideChars[i]
            divideChars[i] = "*"
        end
        if matchEndPos[i] then
            table.insert(illegalTextTable, illegalText)
            illegalText = ""
            stackDepth = stackDepth - matchEndPos[i]
        end
    end
    illegalTextResult = table.concat(illegalTextTable, ",")
    ans = table.concat(divideChars)
    --print("asa",table.concat(illegalTextTable, ","))
    return illegalTextResult,ans
end

ACTrie.Commit()
--_G.ACTrie = ACTrie

--local blockWordsFileName = "block_words_data.lua"
--local block_words_data = dofile(blockWordsFileName)
--local len = #block_words_data
--print(string.format("屏蔽词库共有%d词条", len))
--local testStr = "我爱傻毕 吃饭  的事情大概大家都知道，我爱摸鱼的事情我觉得大家也都清楚的 二货"
--print("被检查词条长度", #GetDivideStringList(testStr))
--local ACTrie = ACTrie.CreateACTrie()
--if block_words_data then
--    local len = #block_words_data
--    for i = 1, len do
--        ACTrie:Insert(block_words_data[i], i)
--    end
--end
--ACTrie:BuildFail()
--local isContainResult,illegalText = ACTrie:IsContainBlockedWord(testStr)
--print("isContainResult",isContainResult)
--print("illegalText",illegalText)
--local acResult = ACTrie:FilterBlockedWords(testStr)
--print(acResult)

return ACTrie