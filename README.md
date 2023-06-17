# lua-configh

[![test](https://github.com/mah0x211/lua-configh/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-configh/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-configh/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-configh)


lua-configh is a helper module that generates config.h file.


## Installation

```
luarocks install configh
```


## Usage


```lua
local configh = require('configh')
-- create configh object
local cfgh = configh('gcc')

-- check whether the specified header file exists or not.
local ok, err = cfgh:check_header('sys/epoll.h')
if not ok then
    print('sys/epoll.h not found')
    print(err)
    return
end

-- check whether the specified function exists or not.
ok, err = cfgh:check_func('sys/epoll.h', 'epoll_create')
if not ok then
    print('epoll_create not found')
    print(err)
    return
end

-- flush the definition macros to the specified pathname.
ok, err = cfgh:flush('./config.h')
if not ok then
    print('failed to write config.h')
    print(err)
    return
end

-- config.h
local f = assert(io.open('./config.h', 'r'))
print(f:read('*a'))
f:close()
```

---

## cfgh = configh( cc )

creates a `configh` object.

**Parameters**

- `cc:string`: a C compiler name. (`gcc`, `clang`, etc..)

**Returns**

- `cfgh:configh`: `configh` object.


## ok, err = configh:check_header( header )

checks whether the specified header file exists or not.

**Parameters**

- `header:string`: a header file name.

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string`: error message if the generated source code fails to compile.


## ok, err = configh:check_func( headers, funcname )

checks whether the specified function exists or not.

**Parameters**

- `headers:string|string[]`: a header file name or array of header file names.
- `funcname:string`: a function name.

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string`: error message if the generated source code fails to compile.


## ok, err = configh:flush( pathname )

flushes the definition macros to the specified pathname.

**Parameters**

- `pathname:string`: a pathname of config.h file.

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string`: error message if the definition macro failed to be written.

