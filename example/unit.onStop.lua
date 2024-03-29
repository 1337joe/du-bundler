assert(slot1.isDown() == 0)
assert(pressedCount == 2, "Pressed count should be 2: " .. pressedCount)
assert(releasedCount == 2)

-- multi-part script, can't just print success because end of script was reached
if string.find(unit.getWidgetData(), '"showScriptError":false') then
    system.print("Success")
else
    system.print("Failed")
end
