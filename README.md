# DU Bundler

Utility to take code from multiple files and combine them into a paste-able Lua configuration for easy import into Dual Universe.

## Usage

To run this bundler, simply call the file directly, passing in the template file and (optionally) output file. If no output file is specified the filled in template will be printed to stdout, which may then be piped to `xclip -selection c` on linux or `clip.exe` on windows. For a concrete example, this is how the example template can be run:

```sh
./bundleTemplate.lua example/template.json
```

## Template Format

The template is basically the json representation of a controller that can be exported from the game with tags embedded in it to simplify template maintenance and make it easy to import files to the appropriate places. The tags are listed below, and for an example template view the example directory, starting with [example/template.json].

### Tags

Tags are delimited by `${}` and are formatted as `tagName [: arguments]`, where the tag name is case insensitive and tags that don't have arguments won't have the colon separator or anything listed after the tag name. For example, `${ARGS} : channel *` would resolve as an `ARGS` tag with arguments `channel` and `*`, as might be used to define an event handler in a receiver element.

Example tag usage may be found in the examples directory, or in `TestBundleTemplate.lua`, primarily in the "testTag<tag name>" and "testGetTagReplacement<tag name>" methods.

#### FILE

Format: `${file: directory/system.start.lua}`

This tag will read in the specified file, sanitize it for json, and embed it in place of the tag. File tags may be used recursively, so you can have a file tag pointing to a CSS file within a lua file, but all tag file paths must be relative to the template location.

Optional arguments, space-separated after file path/name: `${file: directory/system.start.lua argument}`

 * *minify* Attempt to compress the file specified, primarily by reducing whitespace. Currently supports SVG and CSS files.

#### ARGS

Format: `${args: channel *}`

The args tag will convert the listed arguments into a list json formatted arguments.

#### SLOTKEY

Format: `${slotkey: unit}`

This tag converts slot name into slot number, to simplify mapping of code onto named slots. This belongs in: `"slotKey":"${slotkey: unit}"` in the json file.

#### SLOTNAME

Format: `${slotname}`

This tag inserts the name of the slot that it's in. TODO more text

#### KEY

Format: `${key}`

There is no argument necessary for this tag, it simply picks the next sequential (and unused) handler key value. It goes in the `"key":"${key}"` section of the json for handler references.

#### CODE

Format: `${code: <lua goes here>}`

Code can be embedded directly in the template file using the code tag, for the cases where the code for a handler is simple and/or specific to the specific template where it's being used. Closing braces currently cannot be embedded in code blocks because it interferes with the regex matching for the tag itself.

#### DATE

Format: `${date}`

Intended for tagging bundled code by the publish date, this tag simply inserts the current date and time (UTC) in ISO-8601 format.