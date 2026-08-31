"use strict"

const fs = require("fs")
const path = require("path")
const fengari = require("fengari")
const { lua, lauxlib, to_luastring, to_jsstring } = fengari

const roots = process.argv.slice(2)
if (roots.length === 0) {
    process.stderr.write("usage: node parse-lua-tree.js <file-or-directory> [...]\n")
    process.exit(2)
}

function collect(target, result) {
    const stat = fs.statSync(target)
    if (stat.isDirectory()) {
        for (const entry of fs.readdirSync(target)) collect(path.join(target, entry), result)
    } else if (target.toLowerCase().endsWith(".lua")) {
        result.push(target)
    }
}

const files = []
for (const root of roots) collect(root, files)
files.sort()

let failed = false
for (const file of files) {
    const state = lauxlib.luaL_newstate()
    const status = lauxlib.luaL_loadfile(state, to_luastring(file))
    if (status !== lua.LUA_OK) {
        const message = lua.lua_tostring(state, -1)
        process.stderr.write(file + ": " + (message ? to_jsstring(message) : "unknown parse error") + "\n")
        failed = true
    }
}

if (failed) process.exit(1)
process.stdout.write("PASS: parsed " + files.length + " Lua files\n")
