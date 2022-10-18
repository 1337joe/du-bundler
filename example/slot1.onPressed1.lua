pressedCount = pressedCount + 1
assert(slot1.isDown() == 1) -- toggles before calling handlers
assert(pressedCount == 1) -- should only ever be called once, when the user presses the button