package = "du-bundler"
version = "scm-0"
source = {
   url = "git+https://github.com/1337joe/du-bundler.git",
   branch = "main",
}
description = {
   summary = "Utility to combine multiple files into a paste-able Lua configuration for easy import into Dual Universe.",
   detailed = "Utility to combine multiple files into a paste-able Lua configuration for easy import into Dual Universe.",
   homepage = "https://github.com/1337joe/du-mocks",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {},
   copy_directories = {},
   install = {
      bin = {
         ["du-bundler"] = "src/du-bundler.lua",
      }
   },
}
