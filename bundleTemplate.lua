#!/usr/bin/env lua
--- Reads in a DU code deployment template and embeds the referenced files into the template.

----------
-- create methods for manipulating text
----------
local BundleTemplate = {}
_G.BundleTemplate = BundleTemplate

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

-- get sanitized file text
function BundleTemplate:getSanitizedFile(fileName)
    -- look for inputFile relative to template path
    local templateContentFile = self.path..fileName
    -- read content
    local inputHandle = io.open(templateContentFile, "rb")
    if not inputHandle then
        error("File not found: "..templateContentFile)
    end
    local fileContents = io.input(inputHandle):read("*all")
    inputHandle:close()

    return BundleTemplate.sanitizeCode(fileContents)
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
function BundleTemplate.mapSlotValues(jsonText)
    local slotMapping = {}
    for slotNumber,slotName in string.gmatch(jsonText, SLOT_PATTERN) do
        slotMapping[slotName] = slotNumber
    end
    return slotMapping
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

local TAG_KEY = "key"
local TAG_SLOT = "slot"
local TAG_ARGS = "args"
local TAG_FILE = "file"

--- Process a tag.
local TAG_ARGUMENT_PATTERN = "(%S+)%s*:%s*(.*)"
function BundleTemplate:getTagReplacement(fileContents, tag)
    -- tags without arguments
    if tag == TAG_KEY then
        if not self.usedKeys then
            self.usedKeys = BundleTemplate.getUsedHandlerKeys(fileContents)
        end
        local nextKey
        nextKey = self:getNextHandlerKey()
        return nextKey
    end

    -- tags with arguments
    local keyword, argument = string.match(tag, TAG_ARGUMENT_PATTERN)
    if keyword == TAG_SLOT then
        if not self.slotMap then
            self.slotMap = BundleTemplate.mapSlotValues(fileContents)
        end
        return self.slotMap[argument]
    elseif keyword == TAG_ARGS then
        return BundleTemplate.buildArgs(argument)
    elseif keyword == TAG_FILE then
        return self:getSanitizedFile(argument)
    end
    return ""
end

--- Replace all tags with the appropriate values.
local TAG_PATTERN = "${(.-)}"
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
        local tag = string.match(fileContents, TAG_PATTERN)

        local replace = self:getTagReplacement(fileContents, tag)
        fileContents = string.gsub(fileContents, "${"..tag.."}", replace, 1)
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
