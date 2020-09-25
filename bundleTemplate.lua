#!/usr/bin/env lua
--- Reads in a DU code deployment template and embeds the referenced files into the template.

----------
-- create methods for manipulating text
----------
local BundleTemplate = {}
_G.BundleTemplate = BundleTemplate

local TAG_KEY = "key"
local TAG_SLOT_KEY = "slotkey"
local TAG_SLOT_NAME = "slotname"
local TAG_ARGS = "args"
local TAG_FILE = "file"
local TAG_CODE = "code"

function BundleTemplate:new(templateFile)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    if templateFile then
        o.template = templateFile
        o.path = string.match(templateFile, "(.*[/\\])[^/\\]+%.%w+")
    else
        o.template = ""
        o.path = ""
    end
    if not o.path or string.len(o.path) == 0 then
        o.path = "./"
    end

    return o
end

--- Sanitize a block of code.
function BundleTemplate.sanitizeCode(code)
    local sanitized = code
    sanitized = string.gsub(sanitized, "\\", "\\\\")
    sanitized = string.gsub(sanitized, "\"", "\\\"")
    sanitized = string.gsub(sanitized, "%c", "\\n")
    return sanitized
end

--- Escape regex characters from the text to be replaced.
function BundleTemplate.sanitizeSubText(text)
    local sanitized = text
    sanitized = string.gsub(sanitized, "%-", "%%-")
    sanitized = string.gsub(sanitized, "%(", "%%(")
    sanitized = string.gsub(sanitized, "%)", "%%)")
    sanitized = string.gsub(sanitized, "%*", "%%*")
    return sanitized
end

--- Escape regex characters from the text to be filled in.
function BundleTemplate.sanitizeSubReplace(text)
    local sanitized = text
    sanitized = string.gsub(sanitized, "%%", "%%%%")
    return sanitized
end

--- Get the sanitized contents of a file.
function BundleTemplate:getSanitizedFile(fileName)
    -- look for inputFile relative to template path
    local templateContentFile = self.path..fileName
    -- read content
    local inputHandle = io.open(templateContentFile, "rb")
    if not inputHandle then
        error("File not found: "..templateContentFile)
    end
    local inputFileContents = io.input(inputHandle):read("*all")
    inputHandle:close()

    return BundleTemplate.sanitizeCode(inputFileContents)
end

--- Create the formatted string of argument definitions.
local ARGS_FORMAT = '{"%s":"%s"}'
function BundleTemplate.buildArgs(handlerArgs)
    local formattedArgs = ""
    for argValue in string.gmatch(handlerArgs, "[^,%s]+") do
        if string.len(formattedArgs) > 0 then
            formattedArgs = formattedArgs..","
        end
        local argLabel = "value"
        if argValue == "*" then
            argLabel = "variable"
        end
        formattedArgs = formattedArgs..string.format(ARGS_FORMAT, argLabel, argValue)
    end
    return formattedArgs
end

--- Extract slot numbers.
local SLOT_PATTERN = '"(-?%d)":{"name":"([a-zA-Z0-9 ]+)"'
function BundleTemplate:mapSlotValues(jsonText)
    self.slotNameNumberMap = {}
    self.slotNumberNameMap = {}
    for slotNumber,slotName in string.gmatch(jsonText, SLOT_PATTERN) do
        self.slotNameNumberMap[slotName] = slotNumber
        self.slotNumberNameMap[slotNumber] = slotName
    end
end

local HANDLER_PATTERN_SLOT_KEY = '"code":"(.-)","filter":{"args":%[.-%],"signature":"[%w()]+","slotKey":"([%w${: -]+)}?"},"key":"[%d${key}]+"}'
local SLOT_KEY_TAG_PATTERN = "${"..TAG_SLOT_KEY.."%s*:%s*"
function BundleTemplate:findSlotName(jsonText)
    for slotCode,slotKey in string.gmatch(jsonText, HANDLER_PATTERN_SLOT_KEY) do
        -- act on first instance that includes the slot name tag in the code block
        if string.find(slotCode, "${"..TAG_SLOT_NAME.."}") then
            local slotNumber
            local _, slotKeyTagEnd = string.find(string.lower(slotKey), SLOT_KEY_TAG_PATTERN)
            if slotKeyTagEnd then
                slotNumber = string.sub(slotKey, slotKeyTagEnd + 1)
            else
                slotNumber = self.slotNumberNameMap[slotKey]
            end
            return slotNumber
        end
    end
    error("Failed to find "..TAG_SLOT_NAME.." tag.")
end

--- Extract used handler keys.
local KEY_PATTERN = '"key":"(%d+)"'
function BundleTemplate.getUsedHandlerKeys(jsonText)
    local usedKeys = {}
    for key in string.gmatch(jsonText, KEY_PATTERN) do
        usedKeys[key] = true
    end
    return usedKeys
end

--- Find the next unused key.
function BundleTemplate:getNextHandlerKey()
    local i = 0
    local nextKey = tostring(i)
    while self.usedKeys[nextKey] do
        i = i + 1
        nextKey = tostring(i)
    end

    self.usedKeys[nextKey] = true

    return nextKey
end

--- Process a tag.
local TAG_ARGUMENT_PATTERN = "(%S+)%s*:%s*(.*)"
function BundleTemplate:getTagReplacement(fileContents, tag)
    -- tags without arguments
    if string.lower(tag) == TAG_KEY then
        if not self.usedKeys then
            self.usedKeys = BundleTemplate.getUsedHandlerKeys(fileContents)
        end
        return self:getNextHandlerKey()
    elseif string.lower(tag) == TAG_SLOT_NAME then
        if not self.slotNumberNameMap then
            self:mapSlotValues(fileContents)
        end
        return self:findSlotName(fileContents)
    end

    -- tags with arguments
    local keyword, argument = string.match(tag, TAG_ARGUMENT_PATTERN)
    if keyword then
        keyword = string.lower(keyword)
    end

    if keyword == TAG_SLOT_KEY then
        if not self.slotNameNumberMap then
            self:mapSlotValues(fileContents)
        end
        return self.slotNameNumberMap[argument]
    elseif keyword == TAG_ARGS then
        return BundleTemplate.buildArgs(argument)
    elseif keyword == TAG_FILE then
        return self:getSanitizedFile(argument)
    elseif keyword == TAG_CODE then
        return BundleTemplate.sanitizeCode(argument)
    end
    return ""
end

--- Replace the next tag with the appropriate value.
local TAG_PATTERN = "${(.-)}"
function BundleTemplate:replaceTag(fileContents)
    local tag = string.match(fileContents, TAG_PATTERN)

    local toReplace = BundleTemplate.sanitizeSubText("${"..tag.."}")
    local replace = self:getTagReplacement(fileContents, tag)
    replace = BundleTemplate.sanitizeSubReplace(replace)
    local count
    fileContents, count = string.gsub(fileContents, toReplace, replace, 1)
    if count ~= 1 then
        error("Failed to replace: "..toReplace)
    end
    return fileContents
end

--- Replace all tags with the appropriate values.
function BundleTemplate:processTemplate()
    -- look for inputFile relative to current working directory
    -- read content
    local inputHandle = io.open(self.template, "rb")
    if not inputHandle then
        error("File not found: "..self.template)
    end
    local fileContents = io.input(inputHandle):read("*all")
    inputHandle:close()

    -- recursively find tags to replace
    while string.find(fileContents, TAG_PATTERN) do
        fileContents = self:replaceTag(fileContents)
    end

    return fileContents
end

----------
-- Process file
----------

-- parse arguments
if not arg[1] or arg[1] == "--help" or arg[1] == "-h" then
    print("Expected arguments: inputFile [outputFile]")
    print("If outputFile is not provided will stream results to stdout.")
    -- TODO better help display, more detailed argument handling
    return
end

local inputFile = arg[1]
local outputFile = arg[2]

local bundler = BundleTemplate:new(inputFile)
local output = bundler:processTemplate()

-- output to file if specified, stdout otherwise
if outputFile and outputFile ~= "" then
    local outputHandle, error = io.open(outputFile, "w")
    if error then
        print(error)
    else
        io.output(outputHandle):write(output)
        outputHandle:close()
    end
else
    print(output)
end
