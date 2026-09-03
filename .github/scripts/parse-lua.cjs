/*
 * This file is part of ZDecursive, an independently maintained rebuild of Decursive.
 *
 * Based on Decursive, Copyright (C) 2006-2026 John Wellesz
 * ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing
 *
 * This file is free software under GNU GPL version 3 or (at your option) any
 * later version. It is distributed without warranty. See ../../LICENSE.
 */

"use strict"

const fs = require("node:fs")

let luaparse
try {
  luaparse = require("luaparse")
} catch (error) {
  process.stderr.write("ERROR: luaparse is unavailable. Install pinned luaparse@0.3.1 or set NODE_PATH.\n")
  process.exit(2)
}

let failed = false
for (const filename of process.argv.slice(2)) {
  try {
    const source = fs.readFileSync(filename, "utf8")
    luaparse.parse(source, {
      comments: false,
      luaVersion: "5.1",
      locations: true,
      scope: false,
    })
  } catch (error) {
    process.stderr.write(`ERROR: Lua 5.1 parse failed for ${filename}: ${error.message}\n`)
    failed = true
  }
}

process.exit(failed ? 1 : 0)
