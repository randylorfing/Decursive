/*
 * This file is part of ZDecursive, an independently maintained rebuild of Decursive.
 *
 * Based on Decursive, Copyright (C) 2006-2026 John Wellesz
 * ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing
 *
 * This file is free software under GNU GPL version 3 or (at your option) any
 * later version. It is distributed without warranty. See ../LICENSE.
 */

"use strict"

const fs = require("node:fs")
const fengari = require("fengari")
const { luaopen_js } = require("fengari-interop")

const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari
const state = lauxlib.luaL_newstate()
lualib.luaL_openlibs(state)
lauxlib.luaL_requiref(state, to_luastring("js"), luaopen_js, 1)
lua.lua_pop(state, 1)

global.__zdecursiveTestFS = fs

function runBuffer(source, name) {
  const bytes = to_luastring(source)
  let status = lauxlib.luaL_loadbuffer(state, bytes, bytes.length, to_luastring(name))
  if (status === lua.LUA_OK) {
    status = lua.lua_pcall(state, 0, lua.LUA_MULTRET, 0)
  }
  if (status !== lua.LUA_OK) {
    const message = lua.lua_tostring(state, -1)
    process.stderr.write(`${message ? to_jsstring(message) : "unknown Lua error"}\n`)
    process.exit(1)
  }
}

runBuffer(`
local js = require "js"
local fs = js.global.__zdecursiveTestFS

io.open = function(path, mode)
  if mode ~= nil and mode ~= "r" and mode ~= "rb" then
    return nil, "test runner supports read-only files"
  end
  local ok, data = pcall(function()
    return js.tostring(fs:readFileSync(path, "utf8"))
  end)
  if not ok then
    return nil, data
  end
  local file = {_data = data}
  function file:read(format)
    if format == nil or format == "*a" then
      return self._data
    end
    error("test runner supports only *a reads")
  end
  function file:close()
    return true
  end
  return file
end
`, "@zdecursive-test-prelude")

const target = process.argv[2]
if (!target) {
  process.stderr.write("usage: node tests/run-fengari.cjs <test.lua>\n")
  process.exit(2)
}

runBuffer(fs.readFileSync(target, "utf8"), `@${target}`)
