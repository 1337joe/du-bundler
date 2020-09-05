releasedCount = releasedCount + 1
assert(slot1.getState() == 0) -- toggled before calling handlers
assert(releasedCount == 1) -- should only ever be called once, when the user releases the button
