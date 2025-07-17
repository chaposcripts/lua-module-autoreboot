# lua-module-autoreboot
Automatically reloads [MoonLoader](https://www.blast.hk/threads/13305/) script when making changes to any of the modules from `require()`.

## Usage example
```lua
local TestFn = require('test-module');
local Module2 = require('module2');
local Module3 = require('module3');
require('module-autoreboot');

function main()
    TestFn();
    Module2();
    Module3();
    wait(-1);
end
```
