#!/usr/bin/env lua
--- Tests on bundleTemplate.lua.

local lu = require("luaunit")

-- Cache global arguments value, set argument to make call to dofile run properly, then restore global context.
-- NOTE: This expects the tests/results directory to exist before being called.
local originalArguments = _G.arg
_G.arg = {"example/template.json", "tests/results/output.json"}
dofile("bundleTemplate.lua")
_G.arg = originalArguments

_G.TestBundleTemplate = {}

function _G.TestBundleTemplate.testGetUsedHandlerKeys()
    local bundler = _G.BundleTemplate:new()
    local json, expected, actual

    -- single entry
    json = [[
        {"code":"pressedCount = pressedCount + 1","filter":{"args":[],"signature":"pressed()","slotKey":"0"},"key":"1"}
    ]]
    expected = {}
    expected["1"] = true
    actual = bundler.getUsedHandlerKeys(json)
    lu.assertEquals(actual, expected)

    -- 6 sequential entries
    json = [[
        {"code":"pressedCount = pressedCount + 1","filter":{"args":[],"signature":"pressed()","slotKey":"0"},"key":"0"},
        {"code":"pressedCount = pressedCount + 1","filter":{"args":[],"signature":"pressed()","slotKey":"0"},"key":"1"},
        {"code":"releasedCnt = releasedCnt + 1","filter":{"args":[],"signature":"released()","slotKey":"0"},"key":"2"},
        {"code":"releasedCnt = releasedCnt + 1","filter":{"args":[],"signature":"released()","slotKey":"0"},"key":"3"},
        {"code":"assert","filter":{"args":[],"signature":"start()","slotKey":"-1"},"key":"4"},
        {"code":"assert(slot1.getState() == 0)","filter":{"args":[],"signature":"stop()","slotKey":"-1"},"key":"5"}
    ]]
    expected = {}
    expected["0"] = true
    expected["1"] = true
    expected["2"] = true
    expected["3"] = true
    expected["4"] = true
    expected["5"] = true
    actual = bundler.getUsedHandlerKeys(json)
    lu.assertEquals(actual, expected)

    -- 5 non-sequential entries
    json = [[
        {"code":"pressedCount = pressedCount + 1","filter":{"args":[],"signature":"pressed()","slotKey":"0"},"key":"0"},
        {"code":"pressedCount = pressedCount + 1","filter":{"args":[],"signature":"pressed()","slotKey":"0"},"key":"1"},
        {"code":"releasedCnt = releasedCnt + 1","filter":{"args":[],"signature":"released()","slotKey":"0"},"key":"2"},
        {"code":"releasedCnt = releasedCnt + 1","filter":{"args":[],"signature":"released()","slotKey":"0"},"key":"3"},
        {"code":"assert(slot1.getState() == 0)","filter":{"args":[],"signature":"stop()","slotKey":"-1"},"key":"5"}
    ]]
    expected = {}
    expected["0"] = true
    expected["1"] = true
    expected["2"] = true
    expected["3"] = true
    expected["5"] = true
    actual = bundler.getUsedHandlerKeys(json)
    lu.assertEquals(actual, expected)
end

function _G.TestBundleTemplate.testGetNextHandlerKey()
    local bundler = _G.BundleTemplate:new()
    local expectedKey, actualKey, expectedList

    -- no entries
    bundler.usedKeys = {}
    expectedKey, expectedList = "0", {}
    expectedList["0"] = true
    actualKey = bundler:getNextHandlerKey()
    lu.assertEquals(actualKey, expectedKey)
    lu.assertEquals(bundler.usedKeys, expectedList)

    -- conflicting entries
    bundler.usedKeys = {}
    bundler.usedKeys["0"] = true
    expectedKey, expectedList = "1", {}
    expectedList["0"] = true
    expectedList["1"] = true
    actualKey = bundler:getNextHandlerKey()
    lu.assertEquals(actualKey, expectedKey)
    lu.assertEquals(bundler.usedKeys, expectedList)

    -- non-conflicting entries
    bundler.usedKeys = {}
    bundler.usedKeys["1"] = true
    expectedKey, expectedList = "0", {}
    expectedList["0"] = true
    expectedList["1"] = true
    actualKey = bundler:getNextHandlerKey()
    lu.assertEquals(actualKey, expectedKey)
    lu.assertEquals(bundler.usedKeys, expectedList)
end

function _G.TestBundleTemplate.testGetTagReplacementKey()
    local bundler
    local json, tag, expected, actual

    tag = "key"

    -- simplest possible case
    bundler = _G.BundleTemplate:new()
    json = [[${key}]]
    expected = "0"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- full line
    bundler = _G.BundleTemplate:new()
    json = [[{"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slot:slot1}"},"key":"${key}"}]]
    expected = "0"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- multiple lines, multiple calls
    bundler = _G.BundleTemplate:new()
    json = [[
        {"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slot:slot1}"},"key":"${key}"}
        {"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slot:slot1}"},"key":"${key}"}
    ]]
    expected = "0"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)
    json = [[
        {"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slot:slot1}"},"key":"0"}
        {"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slot:slot1}"},"key":"${key}"}
    ]]
    expected = "1"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- existing key on first call
    bundler = _G.BundleTemplate:new()
    json = [[
        {"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slot:slot1}"},"key":"0"}
        {"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slot:slot1}"},"key":"${key}"}
    ]]
    expected = "1"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)
end

function _G.TestBundleTemplate.testMapSlotValues()
    local bundler = _G.BundleTemplate:new()
    local json, expected, actual

    -- default list, cover numbered slots and special slots
    json = [[
        "8":{"name":"slot9","type":{"events":[],"methods":[]}},
        "9":{"name":"slot10","type":{"events":[],"methods":[]}},
        "-1":{"name":"unit","type":{"events":[],"methods":[]}},
    ]]
    expected = {slot9 = "8", slot10 = "9", unit = "-1"}
    actual = bundler.mapSlotValues(json)
    lu.assertEquals(actual, expected)

    -- customized list, cover numbered slots and special slots
    json = [[
        "8":{"name":"the core","type":{"events":[],"methods":[]}},
        "9":{"name":"container","type":{"events":[],"methods":[]}},
        "-1":{"name":"unit","type":{"events":[],"methods":[]}},
    ]]
    expected = {container = "9", unit = "-1"}
    expected["the core"] = "8"
    actual = bundler.mapSlotValues(json)
    lu.assertEquals(actual, expected)
end

function _G.TestBundleTemplate.testGetTagReplacementSlot()
    local bundler
    local json, tag, expected, actual

    -- create lookup table and verify it's used
    bundler = _G.BundleTemplate:new()
    tag = "slot:slot8"
    json = [[
        "7":{"name":"slot8","type":{"events":[],"methods":[]}},
        "8":{"name":"the core","type":{"events":[],"methods":[]}},
        "9":{"name":"container","type":{"events":[],"methods":[]}},
        "-1":{"name":"unit","type":{"events":[],"methods":[]}},
    ]]
    expected = "7"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)
    -- verify uses cached slot names - can't look up again
    tag = "slot:unit"
    json = ""
    expected = "-1"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- verify tag parser handles spaces within argument while ignoring spaces around colon
    bundler = _G.BundleTemplate:new()
    tag = "slot : the core"
    json = [[
        "7":{"name":"slot8","type":{"events":[],"methods":[]}},
        "8":{"name":"the core","type":{"events":[],"methods":[]}},
        "9":{"name":"container","type":{"events":[],"methods":[]}},
        "-1":{"name":"unit","type":{"events":[],"methods":[]}},
    ]]
    expected = "8"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)
end

function _G.TestBundleTemplate.testBuildArgs()
    local bundler = _G.BundleTemplate:new()
    local expected, actual

    expected = '{"variable":"*"}'
    actual = bundler.buildArgs("*")
    lu.assertEquals(actual, expected)

    expected = '{"value":"STOPPED"}'
    actual = bundler.buildArgs("STOPPED")
    lu.assertEquals(actual, expected)

    expected = '{"variable":"*"},{"variable":"*"}'
    actual = bundler.buildArgs("* *")
    lu.assertEquals(actual, expected)

    -- verify comma works for separator
    expected = '{"variable":"*"},{"variable":"*"}'
    actual = bundler.buildArgs("*,*")
    lu.assertEquals(actual, expected)

    -- verify comma + space works for separator
    expected = '{"variable":"*"},{"variable":"*"}'
    actual = bundler.buildArgs("*, *")
    lu.assertEquals(actual, expected)

    expected = '{"value":"channel"},{"variable":"*"}'
    actual = bundler.buildArgs("channel *")
    lu.assertEquals(actual, expected)

    expected = '{"value":"channel"},{"value":"message"}'
    actual = bundler.buildArgs("channel message")
    lu.assertEquals(actual, expected)
end

function _G.TestBundleTemplate.testGetTagReplacementArgs()
    local bundler
    local json, tag, expected, actual

    -- no args needed
    bundler = _G.BundleTemplate:new()
    tag = "args"
    json = [[{"code":"code","filter":{"args":[${args}],"signature":"pressed()","slotKey":"${slot:slot1}"},"key":"0"}]]
    expected = ""
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- single wildcard argument
    bundler = _G.BundleTemplate:new()
    tag = "args:*"
    json = [[{"code":"code","filter":{"args":[${args:*}],"signature":"pressed()","slotKey":"${slot:slot1}"},"key":"0"}]]
    expected = '{"variable":"*"}'
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- multiple arguments
    bundler = _G.BundleTemplate:new()
    tag = "args: channel message"
    json = [[{"code":"","filter":{"args":[${args: channel message}],"signature":"pressed()","slotKey":"0"},"key":"0"}]]
    expected = '{"value":"channel"},{"value":"message"}'
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- multiple arguments, mixed types
    bundler = _G.BundleTemplate:new()
    tag = "args: channel *"
    json = [[{"code":"code","filter":{"args":[${args: channel *}],"signature":"pressed()","slotKey":"0"},"key":"0"}]]
    expected = '{"value":"channel"},{"variable":"*"}'
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)
end

--- Verify code is properly sanitized.
function _G.TestBundleTemplate.testSanitizeCode()
    local bundler = _G.BundleTemplate:new()
    local code, expected, actual

    -- no change
    code = "local var = 7"
    expected = code
    actual = bundler.sanitizeCode(code)
    lu.assertEquals(actual, expected)

    -- escape backslash
    code = "local var = '\\'"
    expected = "local var = '\\\\'"
    actual = bundler.sanitizeCode(code)
    lu.assertEquals(actual, expected)

    -- escape quotes
    code = 'local var = "string"'
    expected = 'local var = \\"string\\"'
    actual = bundler.sanitizeCode(code)
    lu.assertEquals(actual, expected)

    -- escape newline
    code = [[
local var = 7
system.print(var)]]
    expected = "local var = 7\\nsystem.print(var)"
    actual = bundler.sanitizeCode(code)
    lu.assertEquals(actual, expected)
end

function _G.TestBundleTemplate.testGetTagReplacementFile()
    local bundler
    local json, tag, expected, actual

    -- simple file
    bundler = _G.BundleTemplate:new("example/template.json")
    tag = "file:slot1.pressed1.lua"
    json = '{"code":"${file:slot1.pressed1.lua}","filter":{"args":[],"signature":"pressed()","slotKey":"0"},"key":"0"}'
    expected = "pressedCount = pressedCount + 1\\nassert(slot1.getState() == 1) -- toggles before calling handlers\\nassert(pressedCount == 1) -- should only ever be called once, when the user presses the button"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)
end

os.exit(lu.LuaUnit.run())