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
    json = [[{"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slotKey:slot1}"},"key":"${key}"}]]
    expected = "0"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- multiple lines, multiple calls
    bundler = _G.BundleTemplate:new()
    json = [[
        {"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slotKey:slot1}"},"key":"${key}"}
        {"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slotKey:slot1}"},"key":"${key}"}
    ]]
    expected = "0"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)
    json = [[
        {"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slotKey:slot1}"},"key":"0"}
        {"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slotKey:slot1}"},"key":"${key}"}
    ]]
    expected = "1"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- existing key on first call
    bundler = _G.BundleTemplate:new()
    json = [[
        {"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slotKey:slot1}"},"key":"0"}
        {"code":"code","filter":{"args":[],"signature":"pressed()","slotKey":"${slotKey:slot1}"},"key":"${key}"}
    ]]
    expected = "1"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- verify capitalization is ignored
    tag = "Key"
    bundler = _G.BundleTemplate:new()
    json = [[${key}]]
    expected = "0"
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
    bundler:mapSlotValues(json)
    actual = bundler.slotNameNumberMap
    lu.assertEquals(actual, expected)

    -- customized list, cover numbered slots and special slots
    json = [[
        "8":{"name":"the core","type":{"events":[],"methods":[]}},
        "9":{"name":"container","type":{"events":[],"methods":[]}},
        "-1":{"name":"unit","type":{"events":[],"methods":[]}},
    ]]
    expected = {container = "9", unit = "-1"}
    expected["the core"] = "8"
    bundler:mapSlotValues(json)
    actual = bundler.slotNameNumberMap
    lu.assertEquals(actual, expected)
end

function _G.TestBundleTemplate.testGetTagReplacementSlot()
    local bundler
    local json, tag, expected, actual

    -- create lookup table and verify it's used
    bundler = _G.BundleTemplate:new()
    tag = "slotKey:slot8"
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
    tag = "slotkey:unit"
    json = ""
    expected = "-1"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- verify tag parser handles spaces within argument while ignoring spaces around colon
    bundler = _G.BundleTemplate:new()
    tag = "slotkey : the core"
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
    json = [[{"code":"code","filter":{"args":[${args}],"signature":"pressed()","slotKey":"${slotKey:s1}"},"key":"0"}]]
    expected = ""
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- single wildcard argument
    bundler = _G.BundleTemplate:new()
    tag = "args:*"
    json = [[{"code":"code","filter":{"args":[${args:*}],"signature":"pressed()","slotKey":"${slotKey:s1}"},"key":"0"}]]
    expected = '{"variable":"*"}'
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- single value argument
    bundler = _G.BundleTemplate:new()
    tag = "args:variableName"
    json = [[{"code":"code","filter":{"args":[${args:*}],"signature":"pressed()","slotKey":"${slotKey:s1}"},"key":"0"}]]
    expected = '{"value":"variableName"}'
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- single value argument with capitalized tag to ensure variable name isn't lowercased during parsing
    bundler = _G.BundleTemplate:new()
    tag = "ARGS:variableName"
    json = [[{"code":"code","filter":{"args":[${args:*}],"signature":"pressed()","slotKey":"${slotKey:s1}"},"key":"0"}]]
    expected = '{"value":"variableName"}'
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

--- Verify markup minifier removes characters appropriately.
function _G.TestBundleTemplate.testMinifyMarkup()
    local bundler = _G.BundleTemplate:new()
    local markup, expected, actual

    -- trailing space before tag closing
    markup = [[<line x1="0" y1="108" x2="1920" y2="108" />]]
    expected = [[<line x1="0" y1="108" x2="1920" y2="108"/>]]
    actual = bundler.minifyMarkup(markup)
    lu.assertEquals(actual, expected)
    markup = [[<g id="panel" >]]
    expected = [[<g id="panel">]]
    actual = bundler.minifyMarkup(markup)
    lu.assertEquals(actual, expected)

    -- whitespace/newlines between tags
    markup = [[<line x1="0" y1="0" x2="1920" y2="0"/>
    <line x1="0" y1="108" x2="1920" y2="108"/>]]
    expected = [[<line x1="0" y1="0" x2="1920" y2="0"/><line x1="0" y1="108" x2="1920" y2="108"/>]]
    actual = bundler.minifyMarkup(markup)
    lu.assertEquals(actual, expected)

    -- embedded style element
    markup = [[style="font-style : normal ; fill : #bbbbbb ; "]]
    expected = [[style="font-style:normal;fill:#bbbbbb;"]]
    actual = bundler.minifyMarkup(markup)
    lu.assertEquals(actual, expected)

    -- comment
    markup = [[<div><!-- comment block --></div>]]
    expected = [[<div></div>]]
    actual = bundler.minifyMarkup(markup)
    lu.assertEquals(actual, expected)

    -- comment isn't too greedy
    markup = [[<div><!-- comment block -->text<!-- comment block --></div>]]
    expected = [[<div>text</div>]]
    actual = bundler.minifyMarkup(markup)
    lu.assertEquals(actual, expected)
end

--- Verify css minifier removes characters appropriately.
function _G.TestBundleTemplate.testMinifyCss()
    local bundler = _G.BundleTemplate:new()
    local css, expected, actual

    -- whitespace/newlines between elements
    css = [[text {
        text-transform:none;
        font-family:helvetica;
        font-weight:normal;
    }]]
    expected = [[text{text-transform:none;font-family:helvetica;font-weight:normal;}]]
    actual = bundler.minifyCss(css)
    lu.assertEquals(actual, expected)

    -- whitespace around colons
    css = [[text{text-transform : none;font-family : helvetica;font-weight : normal;}]]
    expected = [[text{text-transform:none;font-family:helvetica;font-weight:normal;}]]
    actual = bundler.minifyCss(css)
    lu.assertEquals(actual, expected)

    -- whitespace before brace
    css = [[text {text-transform:none;font-family:helvetica;font-weight:normal;}]]
    expected = [[text{text-transform:none;font-family:helvetica;font-weight:normal;}]]
    actual = bundler.minifyCss(css)
    lu.assertEquals(actual, expected)

    -- whitespace around tags
    css = [[
        text {text-transform:none;}
        .widgetBackground {opacity:0.1;}
    ]]
    expected = [[text{text-transform:none;}.widgetBackground{opacity:0.1;}]]
    actual = bundler.minifyCss(css)
    lu.assertEquals(actual, expected)
end

function _G.TestBundleTemplate.testGetTagReplacementFile()
    local bundler
    local json, tag, expected, actual

    -- simple file
    bundler = _G.BundleTemplate:new("example/template.json")
    tag = "file:slot1.pressed1.lua"
    json = '{"code":"${file:slot1.pressed1.lua}","filter":{"args":[],"signature":"pressed()","slotKey":"0"},"key":"0"}'
    expected = "pressedCount = pressedCount + 1\\nassert(slot1.getState() == 1) -- toggles before calling handlers\\n"..
        "assert(pressedCount == 1) -- should only ever be called once, when the user presses the button"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- non-minified svg
    bundler = _G.BundleTemplate:new("example/template.json")
    tag = "file:image.svg"
    json = '{"code":"${file:image.svg}","filter":{"args":[],"signature":"pressed()","slotKey":"0"},"key":"0"}'
    expected = "<svg xmlns=\\\"http://www.w3.org/2000/svg\\\" version=\\\"1.1\\\" viewBox=\\\"0 0 3200 3200\\\" >\\n"..
        "  <text id=\\\"label\\\" y=\\\"3600\\\" x=\\\"100\\\" style=\\\"font-size:800px;\\\"   >Text</text>\\n"..
        "</svg>"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- minified svg
    bundler = _G.BundleTemplate:new("example/template.json")
    tag = "file:image.svg minify"
    json = '{"code":"${file:image.svg minify}","filter":{"args":[],"signature":"pressed()","slotKey":"0"},"key":"0"}'
    expected = "<svg xmlns=\\\"http://www.w3.org/2000/svg\\\" version=\\\"1.1\\\" viewBox=\\\"0 0 3200 3200\\\">"..
        "<text id=\\\"label\\\" y=\\\"3600\\\" x=\\\"100\\\" style=\\\"font-size:800px;\\\">Text</text>"..
        "</svg>"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- non-minified css
    bundler = _G.BundleTemplate:new("example/template.json")
    tag = "file:style.css"
    json = '{"code":"${file:style.css}","filter":{"args":[],"signature":"pressed()","slotKey":"0"},"key":"0"}'
    expected = "\\ntext {\\n    text-transform: none;\\n    font-family: helvetica;\\n    font-weight: normal;\\n}"..
        "\\n.widgetBackground {\\n    opacity: 0.1;\\n    fill: #222222;\\n}\\n"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)

    -- minified css
    bundler = _G.BundleTemplate:new("example/template.json")
    tag = "file:style.css minify"
    json = '{"code":"${file:style.css minify}","filter":{"args":[],"signature":"pressed()","slotKey":"0"},"key":"0"}'
    expected = "text{text-transform:none;font-family:helvetica;font-weight:normal;}"..
        ".widgetBackground{opacity:0.1;fill:#222222;}"
    actual = bundler:getTagReplacement(json, tag)
    lu.assertEquals(actual, expected)
end

function _G.TestBundleTemplate.testFindSlotName()
    local bundler = _G.BundleTemplate:new()
    local json, expected, actual

    -- basic case: has mapping for number
    expected = "slot1"
    bundler.slotNumberNameMap = {}
    bundler.slotNumberNameMap["0"] = "slot1"
    json = [[{"code":"${slotname}","filter":{"args":[],"signature":"start()","slotKey":"0"},"key":"${key}"}]]
    actual = bundler:findSlotName(json)
    lu.assertEquals(actual, expected)

    -- basic case: has mapping for negative number
    expected = "unit"
    bundler.slotNumberNameMap = {}
    bundler.slotNumberNameMap["-1"] = "unit"
    json = [[{"code":"${slotname}","filter":{"args":[],"signature":"start()","slotKey":"-1"},"key":"${key}"}]]
    actual = bundler:findSlotName(json)
    lu.assertEquals(actual, expected)

    -- simple case: has a slotkey tag with the name in it
    expected = "slot1"
    bundler.slotNumberNameMap = {}
    json = [[{"code":"${slotname}","filter":{"args":[],"signature":"start()","slotKey":"${slotkey:slot1}"},"key":"0"}]]
    actual = bundler:findSlotName(json)
    lu.assertEquals(actual, expected)

    -- has a capitalized SlotKey tag with a case-sensitive name in it
    expected = "Slot1"
    bundler.slotNumberNameMap = {}
    json = [[{"code":"${slotname}","filter":{"args":[],"signature":"start()","slotKey":"${SlotKey:Slot1}"},"key":"0"}]]
    actual = bundler:findSlotName(json)
    lu.assertEquals(actual, expected)

    -- has a capitalized SlotKey tag with a case-sensitive name in it with spaces
    expected = "Slot1"
    bundler.slotNumberNameMap = {}
    json = [[
        {"code":"${slotname}","filter":{"args":[],"signature":"start()","slotKey":"${SlotKey :  Slot1}"},"key":"0"}]]
    actual = bundler:findSlotName(json)
    lu.assertEquals(actual, expected)

    -- two handlers, has a slotkey tag with the name in it
    expected = "slot1"
    bundler.slotNumberNameMap = {}
    json = [[
        {"code":"pressedCount = pressedCount + 1","filter":{"args":[],"signature":"pressed()","slotKey":"0"},"key":"0"},
        {"code":"${slotname}","filter":{"args":[],"signature":"start()","slotKey":"${slotkey:slot1}"},"key":"0"}
    ]]
    actual = bundler:findSlotName(json)
    lu.assertEquals(actual, expected)
end

function _G.TestBundleTemplate.testConstructor()
    local bundler, expected

    -- path with filename
    expected = "example/template.json"
    bundler = _G.BundleTemplate:new(expected)
    lu.assertEquals(bundler.template, expected)
    lu.assertEquals(bundler.path, "example/")

    -- path with simple filename
    expected = "./template.json"
    bundler = _G.BundleTemplate:new(expected)
    lu.assertEquals(bundler.template, expected)
    lu.assertEquals(bundler.path, "./")

    -- filename without path - template in current working directory
    expected = "template.json"
    bundler = _G.BundleTemplate:new(expected)
    lu.assertEquals(bundler.template, expected)
    lu.assertEquals(bundler.path, "./")
end

--- Verify various special characters are handled in tag and replace text.
function _G.TestBundleTemplate.testReplaceTag()
    local bundler = _G.BundleTemplate:new()
    local json, replaceText, expectedTag, actualTag, expectedResult, actualResult

    -- replace tag handling with mock that returns a specific string
    bundler.getTagReplacement = function(_, _, tag)
        actualTag = tag
        return replaceText
    end

    -- % in replace text
    json = "${file:test}"
    expectedTag = "file:test"
    replaceText = "this has a % in it"
    expectedResult = replaceText
    actualResult = bundler:replaceTag(json)
    lu.assertEquals(actualTag, expectedTag)
    lu.assertEquals(actualResult, expectedResult)

    -- - in file name
    json = "${file:test-stuff}"
    expectedTag = "file:test-stuff"
    replaceText = "code goes here"
    expectedResult = replaceText
    actualResult = bundler:replaceTag(json)
    lu.assertEquals(actualTag, expectedTag)
    lu.assertEquals(actualResult, expectedResult)

    -- * in replace text
    json = "${args:*}"
    expectedTag = "args:*"
    replaceText = '{"variable":"*"}'
    expectedResult = replaceText
    actualResult = bundler:replaceTag(json)
    lu.assertEquals(actualTag, expectedTag)
    lu.assertEquals(actualResult, expectedResult)
end

--- Verify code replacement works properly.
function _G.TestBundleTemplate.testCodeTag()
    local bundler = _G.BundleTemplate:new()
    local json, actual, expected

    -- no changes to sanitize code
    json = [[${code: local test = 1}]]
    expected = [[local test = 1]]
    actual = bundler:replaceTag(json)
    lu.assertEquals(actual, expected)

    -- minimal changes: escape quotes
    json = [[${code: system.print("hello world")}]]
    expected = [[system.print(\"hello world\")]]
    actual = bundler:replaceTag(json)
    lu.assertEquals(actual, expected)

    -- multi-line code
    json = [[${code:
-- slot assignments
slots.databank = slot1
slots.databank2 = slot10
}]]
    expected = [[-- slot assignments\nslots.databank = slot1\nslots.databank2 = slot10\n]]
    actual = bundler:replaceTag(json)
    lu.assertEquals(actual, expected)

    -- colon in code block
    json = [[${code:_G.agController:updateState()}]]
    expected = [[_G.agController:updateState()]]
    actual = bundler:replaceTag(json)
    lu.assertEquals(actual, expected)
end

os.exit(lu.LuaUnit.run())