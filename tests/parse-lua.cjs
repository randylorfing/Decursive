// Uses the locally installed Lua 5.1 parser; never installs dependencies.
const fs = require('node:fs');
const path = require('node:path');
const lua = require('luaparse');
let count = 0;
function scan(dir) {
  for (const item of fs.readdirSync(dir, {withFileTypes: true})) {
    const name = path.join(dir, item.name);
    if (item.isDirectory()) scan(name);
    else if (name.endsWith('.lua')) {
      lua.parse(fs.readFileSync(name, 'utf8'), {luaVersion: '5.1'});
      count++;
    }
  }
}
scan('ZDecursive');
scan('docs/tests');
console.log(`${count} Lua files parsed successfully (Lua 5.1)`);
