releasedCount = releasedCount + 1
assert(releasedCount == 2) -- called second in released handler list

unit.exit() -- run stop to report final result
