-- Bundled: ${date}

assert(slot1.getClass() == "ManualButtonUnit")

-- ensure initial state, set up globals
pressedCount = 0
releasedCount = 0

-- prep for user interaction
assert(slot1.isDown() == 0)

system.print("please enable and disable the button")
