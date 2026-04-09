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

    -- include directories for compiling test code (optional)
    -- accepts a string or a string[] (passed as -I flags)
    incdirs = { '/usr/local/include' },

    -- library search directories for linking test code (optional)
    -- accepts a string or a string[] (passed as -L flags)
    libdirs = { '/usr/local/lib' },

    -- library names to link against for test code (optional)
    -- accepts a string or a string[] (passed as -l flags)
    libs = { 'pcre2-8' },

    -- extra preprocessor flags (optional)
    -- accepts a string or a string[] (passed as-is to the compiler)
    cppflags = { '-DDEBUG' },

    -- extra compiler flags (optional)
    -- accepts a string or a string[]
    cflags = { '-std=c11' },

    -- extra linker flags (optional)
    -- accepts a string or a string[]
    ldflags = { '-pthread' },

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

    -- type sizes to measure (optional)
    -- format: { [header_file] = { type1, type2, ... } }
    -- SIZEOF_<TYPE_NAME> is defined in config.h with the byte size as value
    -- <TYPE_NAME> is the type name in uppercase with special chars replaced by _
    sizeof = {
        ['stddef.h'] = {
            'size_t',
            'ptrdiff_t',
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
 * this file is generated by the lua-configh module.
 */
#define ENABLE_FEATURE_X

#define _GNU_SOURCE 1

/* Define to 1 if you have the <stdio.h> header. */
#define HAVE_STDIO_H 1

/* Define to 1 if you have the <stdlib.h> header. */
#define HAVE_STDLIB_H 1

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

/* Define to 1 if you have the `FILE._flags' member. */
#define HAVE_FILE__FLAGS 1

/* Define to 1 if you have the `FILE._IO_read_ptr' member. */
/* #undef HAVE_FILE__IO_READ_PTR */
```

---


## Library API

The `configh` module provides two usage patterns: a declarative high-level
function `configh.generate()` and a manual instance API.

### Using configh.generate()

The `configh.generate` module provides a `generate()` function that accepts
a single cfg table and runs all probes in one call, then writes the result
to `cfg.output`.

```lua
local generate = require('configh.generate')
local report, err = generate({
    -- C compiler name (optional, default: $CC)
    cc = 'gcc',

    -- output file path (required)
    output = 'src/config.h',

    -- enable status output (optional, default: false)
    output_status = true,

    -- compiler/linker settings (optional)
    incdirs  = {'/usr/local/include'},
    libdirs  = {'/usr/local/lib'},
    libs     = {'z'},
    cppflags = {'-D_GNU_SOURCE'},
    cflags   = {'-std=c11'},
    ldflags  = {'-Wl,-rpath,/usr/local/lib'},

    -- feature macros (optional, mixed table)
    features = {
        _GNU_SOURCE = 1,
        'ENABLE_FEATURE_X',
    },

    -- headers to check (optional)
    headers = {'stdio.h', 'stdlib.h'},

    -- functions to check per header (optional)
    funcs = {
        ['sys/epoll.h'] = {'epoll_create', 'epoll_create1'},
    },

    -- types to check per header (optional)
    types = {
        ['sys/types.h'] = {'pid_t', 'size_t'},
    },

    -- declarations to check per header (optional)
    decls = {
        ['unistd.h'] = {'STDIN_FILENO', 'STDOUT_FILENO'},
    },

    -- type sizes to measure per header (optional)
    sizeof = {
        ['sys/types.h'] = {'size_t', 'off_t'},
    },

    -- struct members to check per header (optional)
    members = {
        ['stdio.h'] = {
            FILE = {'_flags'},
        },
    },
})
if report == nil then
    error(err)
end
-- report['stdio.h'].is_exists            => true/false (header probed)
-- report['sys/epoll.h'].epoll_create     => true/false (func found/not found)
-- report['sys/types.h']['size_t']        => integer (byte size) or false
```

### Using the instance API

```lua
local configh = require('configh')
-- create configh object
-- CPPFLAGS, CFLAGS, and LDFLAGS environment variables are loaded automatically
local cfgh = configh('gcc')

-- set feature macro
cfgh:set_feature('_GNU_SOURCE')

-- add preprocessor flags
-- CPPFLAGS environment variable is also loaded automatically
cfgh:add_cppflags({'-I/usr/local/include', '-DDEBUG'})

-- add include directories (passed as -I flags)
cfgh:add_incdirs('/opt/include')

-- add compiler flags
cfgh:add_cflags('-std=c11')

-- add library search directories (passed as -L flags, link stage only)
cfgh:add_libdirs('/usr/local/lib')

-- add library names (passed as -l flags, link stage only)
cfgh:add_libs({'z', 'm'})

-- add linker flags
cfgh:add_ldflags('-Wl,-rpath,/usr/local/lib')

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

-- check a function that requires linking against a library.
-- the first probe for a given library name also emits HAVE_LIB_<LIBRARY>
-- in config.h alongside HAVE_<FUNC>.
ok, err = cfgh:check_func('math.h', 'sin', 'm')
if not ok then
    print('sin (libm) not found')
    print(err)
end

-- check the size of a C type at compile time.
-- SIZEOF_<TYPE> macro is emitted in config.h on success.
local sz
ok, err, sz = cfgh:check_sizeof('sys/types.h', 'size_t')
if not ok then
    print('size_t not found')
    print(err)
else
    print('size_t = ' .. sz .. ' bytes')
end

-- flush the definition macros to the specified pathname.
ok, err = cfgh:flush('./config.h')
if not ok then
    print('failed to write config.h')
    print(err)
    return
end
```


## report, err = generate( cfg [, label [, stdout]] )

`require('configh.generate')` returns this function.

Creates a `configh` instance, applies all settings from `cfg`, runs all
probes, and flushes the result to `cfg.output`. This is the recommended
entry point when all probe information is known up front.

**Parameters**

- `cfg:table`: configuration table with the following fields:
  - `cc:string?`: C compiler name. Defaults to the `CC` environment variable.
  - `output:string`: output path for the generated `config.h` file. **Required.**
  - `output_status:boolean?`: enable status output to stdout (default: `false`).
  - `incdirs:string|string[]?`: include directories (passed as `-I` flags).
  - `libdirs:string|string[]?`: library search directories (passed as `-L` flags).
  - `libs:string|string[]?`: library names to link against (passed as `-l` flags).
  - `cppflags:string|string[]?`: extra preprocessor flags.
  - `cflags:string|string[]?`: extra compiler flags.
  - `ldflags:string|string[]?`: extra linker flags.
  - `features:table?`: feature macros. Mixed table: string keys define named
    macros with a value; integer-keyed strings define macros without a value.
  - `headers:string[]?`: header files to probe with `check_header`.
  - `funcs:table<string,string[]>?`: functions to probe per header file.
    Format: `{ [header] = { func, ... } }`.
  - `types:table<string,string[]>?`: C types to probe per header file.
    Format: `{ [header] = { type, ... } }`.
  - `decls:table<string,string[]>?`: declarations to probe per header file.
    Format: `{ [header] = { decl, ... } }`.
  - `sizeof:table<string,string[]>?`: type sizes to measure per header file.
    Format: `{ [header] = { type, ... } }`.
  - `members:table<string,table<string,string[]>>?`: struct members to probe.
    Format: `{ [header] = { [type] = { member, ... } } }`.
- `label:string?`: root label used in error messages (default: `'cfg'`).
  Typically set to the module name (e.g. `build.modules` key) when called
  from `luarocks-build-hooks`.
- `stdout:file*?`: file handle for probe status output (default: `io.stdout`).
  Overrides the handle used by `configh:set_stdout()` inside the call.
  Has effect only when `output_status` is `true`.

**Returns**

- `report:table`: probe result table on success.
  - `report[header].is_exists:boolean`: whether the header was found.
  - `report[header][name]:boolean`: `true`/`false` for each `funcs`, `types`,
    or `decls` probe.
  - `report[header]["type.member"]:boolean`: `true`/`false` for each `members`
    probe. The key is `"ctype.member"` (e.g. `"FILE._flags"`).
  - `report[header][name]:integer`: byte size for each `sizeof` probe, or
    `false` if the type was not found.
- `err:string?`: error message if `cfg.output` could not be written
  (`report` is `nil` in this case).

**NOTE**

- `check_header` deduplication is applied automatically: a header that appears
  in both `headers` and as a key in `funcs`/`types`/`decls`/`sizeof`/`members`
  is compiled only once.
- `funcs` always calls `check_func(header, name)` without a per-function
  library argument. Use `cfg.libs` to set global link libraries for all probes,
  or use the instance API (`configh:check_func`) for per-function library
  control.


## cfgh = configh( cc )

Creates a `configh` object.

**Parameters**

- `cc:string?`: a C compiler name (`gcc`, `clang`, etc.). If omitted or `nil`, the `CC` environment variable is used. An error is raised if neither is available.

**Returns**

- `cfgh:configh`: `configh` object.

**NOTE**

- The `CPPFLAGS`, `CFLAGS`, and `LDFLAGS` environment variables are automatically loaded into the corresponding flag fields when creating a `configh` object.


## configh:set_feature( name [, value] )

Defines a feature macro in the config.h file.

**Parameters**

- `name:string`: a feature macro name.
- `value:string|number?`: a feature macro value.


## configh:unset_feature( name )

Removes a feature macro that was set by the `configh:set_feature` method.

**Parameters**

- `name:string`: a feature macro name.


## configh:set_incdirs( dirs )

Sets the include directories to be passed as `-I` flags. Replaces any previously set directories.

**Parameters**

- `dirs:string|string[]`: a directory path or an array of directory paths (e.g. `'/usr/local/include'` or `{'/usr/local/include', '/opt/include'}`).


## configh:add_incdirs( dirs )

Appends include directories to the existing list.

**Parameters**

- `dirs:string|string[]`: a directory path or an array of directory paths.


## configh:set_libdirs( dirs )

Sets the library search directories to be passed as `-L` flags. Replaces any previously set directories.

**Parameters**

- `dirs:string|string[]`: a directory path or an array of directory paths (e.g. `'/usr/local/lib'` or `{'/usr/local/lib', '/opt/lib'}`).


## configh:add_libdirs( dirs )

Appends library search directories to the existing list.

**Parameters**

- `dirs:string|string[]`: a directory path or an array of directory paths.


## configh:set_libs( libs )

Sets the library names to be passed as `-l` flags in the link stage. Replaces any previously set names.

**Parameters**

- `libs:string|string[]`: a library name or an array of library names without the `-l` prefix (e.g. `'z'` or `{'z', 'm'}`).


## configh:add_libs( libs )

Appends library names to the existing list.

**Parameters**

- `libs:string|string[]`: a library name or an array of library names without the `-l` prefix.


## configh:set_cppflags( flags )

Sets the cppflags to be used when compiling test code. Replaces any previously set cppflags, including those loaded from the `CPPFLAGS` environment variable.

**Parameters**

- `flags:string|string[]`: a cppflag string or an array of cppflag strings (e.g. `'-I/usr/local/include'` or `{'-I/usr/local/include', '-DDEBUG'}`).

**NOTE**

- Tilde (`~`) is **not** expanded. Use `$HOME` or absolute path instead (e.g. `-I$HOME/include` or `-I/home/user/include`).


## configh:add_cppflags( flags )

Appends cppflags to the existing list. Flags loaded from the `CPPFLAGS` environment variable are preserved.

**Parameters**

- `flags:string|string[]`: a cppflag string or an array of cppflag strings (e.g. `'-I/usr/local/include'` or `{'-I/usr/local/include', '-DDEBUG'}`).

**NOTE**

- The `CPPFLAGS` environment variable is automatically loaded when creating a `configh` object.
- Tilde (`~`) is **not** expanded. Use `$HOME` or absolute path instead (e.g. `-I$HOME/include` or `-I/home/user/include`).


## configh:set_cflags( flags )

Sets the compiler flags to be used when compiling test code. Replaces any previously set cflags, including those loaded from the `CFLAGS` environment variable.

**Parameters**

- `flags:string|string[]`: a cflag string or an array of cflag strings (e.g. `'-std=c11'` or `{'-std=c11', '-m32'}`).

**NOTE**

- The `CFLAGS` environment variable is automatically loaded when creating a `configh` object.


## configh:add_cflags( flags )

Appends cflags to the existing list. Flags loaded from the `CFLAGS` environment variable are preserved.

**Parameters**

- `flags:string|string[]`: a cflag string or an array of cflag strings.


## configh:set_ldflags( flags )

Sets the linker flags to be used in the link stage. Replaces any previously set ldflags, including those loaded from the `LDFLAGS` environment variable.

**Parameters**

- `flags:string|string[]`: a linker flag string or an array of linker flag strings (e.g. `'-Wl,-rpath,/usr/local/lib'` or `{'-Wl,--as-needed', '-static'}`).

**NOTE**

- The `LDFLAGS` environment variable is automatically loaded when creating a `configh` object.
- `ldflags` is placed before `libdirs` (`-L`) in the link command, matching the conventional `$(LDFLAGS)` position in Make rules.


## configh:add_ldflags( flags )

Appends ldflags to the existing list. Flags loaded from the `LDFLAGS` environment variable are preserved.

**Parameters**

- `flags:string|string[]`: a linker flag string or an array of linker flag strings.


## configh:output_status( enabled )

Enables or disables the output of status messages to stdout when the `configh:check_header`, `configh:check_func`, `configh:check_type`, `configh:check_decl`, `configh:check_member`, and `configh:check_sizeof` methods are called.

**Parameters**

- `enabled:boolean`: `true` to enable, or `false` to disable.


## configh:set_stdout( [outfile] )

Sets the output file for status messages when the `configh:check_header`, `configh:check_func`, `configh:check_type`, `configh:check_decl`, `configh:check_member`, and `configh:check_sizeof` methods are called.

**Parameters**

- `outfile:file*?`: an output file handle. If `nil` or omitted, `io.stdout` is used.


## ok, err = configh:check_header( header )

Checks whether the specified header file exists.

**Parameters**

- `header:string`: a header file name.

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string?`: error message if the generated source code fails to compile.


## ok, err = configh:check_func( headers, name [, library] )

Checks whether the specified function exists.

**Parameters**

- `headers:string|string[]|nil`: a header file name or array of header file names, or `nil`.
- `name:string`: a function name (e.g. `"printf"`).
- `library:string?`: an optional library name to link against (e.g. `"m"` for `-lm`). When given, the link probe passes `-l<library>`. The first probe for a given library name also emits a `HAVE_LIB_<LIBRARY>` macro in config.h alongside the `HAVE_<FUNC>` macro.

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string?`: error message if the generated source code fails to compile or link.


## ok, err = configh:check_type( headers, name )

Checks whether the specified type exists.

**Parameters**

- `headers:string|string[]|nil`: a header file name or array of header file names, or `nil`.
- `name:string`: a C type name (e.g. `"pid_t"`, `"struct sockaddr_storage"`).

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string?`: error message if the generated source code fails to compile.


## ok, err = configh:check_decl( headers, name )

Checks whether the specified declaration (macro constant, enum value, or global variable) exists.

**Parameters**

- `headers:string|string[]|nil`: a header file name or array of header file names, or `nil`.
- `name:string`: a declaration name (e.g. `"PATH_MAX"`, `"O_RDONLY"`).

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string?`: error message if the generated source code fails to compile.


## ok, err = configh:check_member( headers, name, member )

Checks whether the specified member field exists in the type.

**Parameters**

- `headers:string|string[]|nil`: a header file name or array of header file names, or `nil`.
- `name:string`: a C struct type name (e.g. `"struct sockaddr"`).
- `member:string`: a member field name (e.g. `"sa_family"`).

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string?`: error message if the generated source code fails to compile.


## ok, err, size = configh:check_sizeof( headers, name )

Determines the size of a C type at compile time.

**Parameters**

- `headers:string|string[]|nil`: a header file name or array of header file names, or `nil`.
- `name:string`: a C type name (e.g. `"size_t"`, `"struct sockaddr"`).

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string?`: error message if the generated source code fails to compile.
- `size:integer?`: byte size of the type on success, `nil` on failure.

**NOTE**

- On success, a `SIZEOF_<TYPE>` macro is emitted in config.h with the type's size in bytes (e.g. `#define SIZEOF_SIZE_T 8`).
- On failure, `/* #undef SIZEOF_<TYPE> */` is emitted.
- `<TYPE>` is the type name in uppercase with all non-alphanumeric characters replaced by underscores.


## ok, err = configh:flush( pathname )

Flushes the definition macros to the specified pathname.

**Parameters**

- `pathname:string`: a pathname of config.h file.

**Returns**

- `ok:boolean`: `true` on success, or `false` on failure.
- `err:string?`: error message if the file failed to be written.


## License

This project is licensed under the MIT License. See the LICENSE file for details.
