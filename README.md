# lua-configh

[![test](https://github.com/mah0x211/lua-configh/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-configh/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-configh/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-configh)


lua-configh is a lightweight autoconf alternative that generates config.h files. It checks for the availability of C headers, functions, types, and declarations by compiling test code with the C compiler.


## Installation

```
luarocks install configh
```

***

## Command Line Interface

The `configh` command-line tool is installed with the lua-configh module and can be used to generate a `config.h` file from a configuration Lua file.


### Usage


```bash
configh <config.lua> [--out=<filename>]
```

#### Arguments

- `<config.lua>`: Path to the configuration Lua file.
- `--out=<filename>`: Specify the output header file name (default: `config.h`).


#### Configuration File Format

The configuration file must return a table with the following optional fields:

```lua
-- example config file for configh command
return {
    -- C compiler name (optional, default: $CC or 'cc')
    cc = 'gcc',

    -- enable status output (optional, default: false)
    -- it enables output messages to stdout as follows:
    --
    --   checking for header file <stdio.h>... found
    --
    -- when checking headers, functions, types, declarations, and members.
    output_status = true,

    -- feature macros (optional)
    -- these macros will be defined in config.h.
    features = {
        -- feature macro with value (value can be string or number)
        _GNU_SOURCE = 1,
        -- feature macro without value
        'ENABLE_FEATURE_X',
    },

    -- add CPPFLAGS for compiling test code (optional)
    -- specify cppflags as strings in an array.
    cppflags = {
        '-I/usr/local/include',
        '-DDEBUG',
    },

    -- headers to check (optional)
    -- array of header file names
    -- if a header file exists, HAVE_<HEADER_NAME> macro is defined in config.h
    -- <HEADER_NAME> is the header file name with dots replaced by underscores
    headers = {
        'stdio.h',
        'stdlib.h',
    },

    -- functions to check (optional)
    -- format: { [header_file] = { function1, function2, ... } }
    -- if a function exists, HAVE_<FUNC_NAME> macro is defined in config.h
    -- <FUNC_NAME> is the function name in uppercase
    funcs = {
        ['stdio.h'] = {
            'printf',
            'fprintf',
        },
    },

    -- types to check (optional)
    -- format: { [header_file] = { type1, type2, ... } }
    -- if a type exists, HAVE_<TYPE_NAME> macro is defined in config.h
    -- <TYPE_NAME> is the type name in uppercase
    types = {
        ['sys/types.h'] = {
            'pid_t',
            'size_t',
        },
    },

    -- declarations to check (optional)
    -- format: { [header_file] = { decl1, decl2, ... } }
    -- declarations include macro constants, enum values, and global variables
    -- if a declaration exists, HAVE_<DECL_NAME> macro is defined in config.h
    -- <DECL_NAME> is the declaration name in uppercase
    decls = {
        ['unistd.h'] = {
            'STDIN_FILENO',
            'STDOUT_FILENO',
            'POSIX_VERSION',
        },
    },

    -- members to check (optional)
    -- format: { [header_file] = { [type] = { member1, member2, ... } } }
    -- if a member exists, HAVE_<TYPE_NAME>_<MEMBER_NAME> macro is defined in config.h
    -- <TYPE_NAME> and <MEMBER_NAME> are in uppercase, with dots replaced by underscores
    members = {
        ['stdio.h'] = {
            FILE = {
                '_flags',
                '_IO_read_ptr',
            },
        },
    },
}
```

When you run the `configh` command with the above configuration file (`example_config.lua`), it generates a `config.h` file and outputs status messages as follows:

```bash
$ configh ./example_config.lua 
check header: stdio.h ... found
check header: stdlib.h ... found
check header: stdio.h ... found
check function: printf ... found
check function: fprintf ... found
check header: sys/types.h ... found
check type: pid_t ... found
check type: size_t ... found
check header: unistd.h ... found
check decl: STDIN_FILENO ... found
check decl: STDOUT_FILENO ... found
check decl: POSIX_VERSION ... not found
  >  /tmp/lua_UvTFLz.c:8:11: error: use of undeclared identifier 'POSIX_VERSION'
  >      8 |     (void)POSIX_VERSION;
  >        |           ^
  >  1 error generated.
  >   
check header: stdio.h ... found
check member: FILE._flags ... found
check member: FILE._IO_read_ptr ... not found
  >  /tmp/lua_C5ciAJ.c:7:21: error: no member named '_IO_read_ptr' in 'struct __sFILE'
  >      7 |     FILE x; (void)x._IO_read_ptr;
  >        |                   ~ ^
  >  1 error generated.
  >   
======================================================================
All checks are done.
Writing definitions to config.h ... done
======================================================================
```

The generated `config.h` file looks like this:

```c
/**
 * this file is generated by the lua-configh module on Fri Jan 16 07:51:23 2026
 */
#define ENABLE_FEATURE_X

#define _GNU_SOURCE 1

/* Define to 1 if you have the <stdio.h> header. */
#define HAVE_STDIO_H 1

/* Define to 1 if you have the <stdlib.h> header. */
#define HAVE_STDLIB_H 1

/* Define to 1 if you have the <stdio.h> header. */
#define HAVE_STDIO_H 1

/* Define to 1 if you have the `printf' function. */
#define HAVE_PRINTF 1

/* Define to 1 if you have the `fprintf' function. */
#define HAVE_FPRINTF 1

/* Define to 1 if you have the <sys/types.h> header. */
#define HAVE_SYS_TYPES_H 1

/* Define to 1 if you have the `pid_t' type. */
#define HAVE_PID_T 1

/* Define to 1 if you have the `size_t' type. */
#define HAVE_SIZE_T 1

/* Define to 1 if you have the <unistd.h> header. */
#define HAVE_UNISTD_H 1

/* Define to 1 if you have the `STDIN_FILENO' decl. */
#define HAVE_STDIN_FILENO 1

/* Define to 1 if you have the `STDOUT_FILENO' decl. */
#define HAVE_STDOUT_FILENO 1

/* Define to 1 if you have the `POSIX_VERSION' decl. */
/* #undef HAVE_POSIX_VERSION */

/* Define to 1 if you have the <stdio.h> header. */
#define HAVE_STDIO_H 1

/* Define to 1 if you have the `FILE._flags' member. */
#define HAVE_FILE__FLAGS 1

/* Define to 1 if you have the `FILE._IO_read_ptr' member. */
/* #undef HAVE_FILE__IO_READ_PTR */
```

---


## Library API

The `configh` module provides an API to generate a config.h file programmatically.

### Usage

```lua
local configh = require('configh')
-- create configh object
local cfgh = configh('gcc')

-- set feature macro
cfgh:set_feature('_GNU_SOURCE')

-- add cppflags
-- CPPFLAGS environment variable is also loaded automatically
cfgh:add_cppflag('-I/usr/local/include')

-- check whether the specified header file exists
local ok, err = cfgh:check_header('stdio.h')
if not ok then
    print('stdio.h not found')
    print(err)
    return
end

-- check whether the specified header file exists
cfgh:check_header('unknown_header_file.h')

-- check whether the specified function exists
ok, err = cfgh:check_func('stdio.h', 'printf')
if not ok then
    print('printf not found')
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

-- above code outputs the following:
--[[
/**
 * this file is generated by the lua-configh module on Sat Jun 17 12:57:53 2023
 */

/* Define to 1 if you have the <stdio.h> header file. */
#define HAVE_STDIO_H 1

/* Define to 1 if you have the <unknown_header_file.h> header file. */
/* #undef HAVE_UNKNOWN_HEADER_FILE_H */

/* Define to 1 if you have the `printf' function. */
#define HAVE_PRINTF 1

]]
```


## cfgh = configh( cc )

Creates a `configh` object.

**Parameters**

- `cc:string`: a C compiler name. (`gcc`, `clang`, etc..)

**Returns**

- `cfgh:configh`: `configh` object.


## configh:set_feature( name [, value] )

Defines a feature macro in the config.h file.

**Parameters**

- `name:string`: a feature macro name.
- `value:string|number?`: a feature macro value.


## configh:unset_feature( name )

Removes a feature macro that was set by the `configh:set_feature` method.

**Parameters**

- `name:string`: a feature macro name.


## configh:add_cppflag( flag )

Adds a cppflag to be used when compiling test code.

**Parameters**

- `flag:string`: a cppflag string (e.g. `-I/usr/local/include`, `-DDEBUG`).

**NOTE**

- The `CPPFLAGS` environment variable is automatically loaded when creating a `configh` object.
- Tilde (`~`) is **not** expanded. Use `$HOME` or absolute path instead (e.g. `-I$HOME/include` or `-I/home/user/include`).


## configh:remove_cppflag( flag )

Removes a cppflag that was added by the `configh:add_cppflag` method.

**Parameters**

- `flag:string`: a cppflag string.


## configh:output_status( enabled )

Enables or disables the output of status messages to stdout when the `configh:check_header`, `configh:check_func`, `configh:check_type`, `configh:check_decl`, and `configh:check_member` methods are called.

**Parameters**

- `enabled:boolean`: `true` to enable, or `false` to disable.


## configh:set_stdout( [outfile] )

Sets the output file for status messages when the `configh:check_header`, `configh:check_func`, `configh:check_type`, `configh:check_decl`, and `configh:check_member` methods are called.

**Parameters**

- `outfile:file*?`: an output file handle. If `nil` or omitted, `io.stdout` is used.


## ok, err = configh:check_header( header )

Checks whether the specified header file exists.

**Parameters**

- `header:string`: a header file name.

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string`: error message if the generated source code fails to compile.


## ok, err = configh:check_func( headers, func )

Checks whether the specified function exists.

**Parameters**

- `headers:string|string[]`: a header file name or array of header file names.
- `func:string`: a function name.

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string`: error message if the generated source code fails to compile.


## ok, err = configh:check_type( headers, type )

Checks whether the specified type exists.

**Parameters**

- `headers:string|string[]`: a header file name or array of header file names.
- `type:string`: a type name.

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string`: error message if the generated source code fails to compile.


## ok, err = configh:check_decl( headers, name )

Checks whether the specified declaration (macro constant, enum value, or global variable) exists.

**Parameters**

- `headers:string|string[]`: a header file name or array of header file names.
- `name:string`: a declaration name.

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string`: error message if the generated source code fails to compile.


## ok, err = configh:check_member( headers, type, member )

Checks whether the specified member field exists in the type.

**Parameters**

- `headers:string|string[]`: a header file name or array of header file names.
- `type:string`: a type name.
- `member:string`: a member name.

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string`: error message if the generated source code fails to compile.


## ok, err = configh:flush( pathname )

Flushes the definition macros to the specified pathname.

**Parameters**

- `pathname:string`: a pathname of config.h file.

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string`: error message if the file failed to be written.

