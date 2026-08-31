"use strict"

// The upstream fengari-node-cli executable reports Lua failures but exits 0.
// This tiny repository runner preserves the same trusted Fengari runtime while
// returning a reliable process status for CI and local failure self-tests.
const fengari = require("fengari")
const fs = require("fs")
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari

const scriptPath = process.argv[2]
if (!scriptPath) {
    process.stderr.write("usage: node run-fengari.js <script.lua> [args...]\n")
    process.exit(2)
}

const state = lauxlib.luaL_newstate()
lualib.luaL_openlibs(state)

lua.lua_pushcfunction(state, function (luaState) {
    const path = to_jsstring(lauxlib.luaL_checkstring(luaState, 1))
    try {
        lua.lua_pushstring(luaState, to_luastring(fs.readFileSync(path, "utf8")))
        return 1
    } catch (error) {
        lua.lua_pushnil(luaState)
        lua.lua_pushstring(luaState, to_luastring(String(error)))
        return 2
    }
})
lua.lua_setglobal(state, to_luastring("readfile"))

lua.lua_createtable(state, process.argv.length - 3, 1)
lua.lua_pushstring(state, to_luastring(scriptPath))
lua.lua_seti(state, -2, 0)
for (let index = 3; index < process.argv.length; index += 1) {
    lua.lua_pushstring(state, to_luastring(process.argv[index]))
    lua.lua_seti(state, -2, index - 2)
}
lua.lua_setglobal(state, to_luastring("arg"))

let status = lauxlib.luaL_loadfile(state, to_luastring(scriptPath))
if (status === lua.LUA_OK) status = lua.lua_pcall(state, 0, lua.LUA_MULTRET, 0)
if (status !== lua.LUA_OK) {
    const message = lua.lua_tostring(state, -1)
    process.stderr.write((message ? to_jsstring(message) : "unknown Lua failure") + "\n")
    process.exit(1)
}
