--
-- Copyright (C) 2026 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
local format = string.format
local type = type
local ipairs = ipairs
local pairs = pairs
local isfile = require('io.isfile')
local configh = require('configh')

--- file-scope variables
local STDERR = io.stderr
local STDOUT = io.stdout

--- set_stdio_files set stdout and stderr file handles
--- @param stdout file*?
--- @param stderr file*?
local function set_stdio_files(stdout, stderr)
    if stdout ~= nil then
        assert(isfile(stdout), 'stdout must be a file* or nil')
        STDOUT = stdout
    end
    if stderr ~= nil then
        assert(isfile(stderr), 'stderr must be a file* or nil')
        STDERR = stderr
    end
end

--- print error message to stderr
--- @param ... any
local function perror(...)
    STDERR:write(format(...))
end

--- fatal print error message and exit with error code
--- @param ... any
local function fatal(...)
    perror(...)
    os.exit(1)
end

--- check a v is a string[]|table<string, string|number> or not
--- @param v any
--- @param name string
--- @return boolean ok
local function checkopt_table(v, name)
    if v == nil then
        return false
    end

    if type(v) ~= 'table' then
        fatal('%s must be a string[]|table<string, string|number> or nil', name)
    end

    for key, val in pairs(v) do
        local t = type(key)
        if t == 'string' then
            -- key-value part
            t = type(val)
            if t ~= 'string' and t ~= 'number' then
                fatal('%s.%s value must be a string or number, got %q', name,
                      key, t)
            end
        elseif t ~= 'number' then
            -- array part - key must be number
            fatal('%s index must be an integer, got %q', name, t)
        elseif key % 1 ~= 0 then
            -- array part - key must be integer
            fatal('%s index must be an integer, got non-integer %f', name, key)
        elseif type(val) ~= 'string' then
            -- array part - value must be string
            fatal('%s[%d] value must be a string, got %q', name, key, type(val))
        end
    end
    return true
end

--- check a v is a string array or not
--- @param v any
--- @param name string
--- @return boolean ok
local function checkopt_array(v, name)
    if v == nil then
        return false
    end

    if type(v) ~= 'table' or (#v == 0 and next(v)) then
        -- v is not a table, or it is not an consecutive array
        fatal('%s must be a string[] or nil\n', name)
    end

    for i, val in ipairs(v) do
        local t = type(val)
        if t ~= 'string' then
            fatal('%s#%d must be a string, got %q', name, i, t)
        end
    end
    return true
end

--- check a v is a table<string, string[]> or not
--- @param v any
--- @param name string
--- @return boolean ok
local function checkopt_map_array(v, name)
    if v == nil then
        return false
    end

    if type(v) ~= 'table' or #v > 0 then
        fatal('%s must be a table<string, string[]> or nil', name)
    end

    for key, val in pairs(v) do
        local t = type(key)
        if t ~= 'string' then
            fatal('%s[%s] must be a string, got %q', name, tostring(key), t)
        end
        checkopt_array(val, format('%s.%s', name, key))
    end
    return true
end

--- checkopt_nested_map check a v is a table of tables of string arrays or not
--- @param v any
--- @param name string
local function checkopt_nested_map(v, name)
    if v == nil then
        return
    elseif type(v) ~= 'table' or #v > 0 then
        fatal('%s must be a table<string, table<string, string[]>> or nil', name)
    end

    for key1, val1 in pairs(v) do
        local t = type(key1)
        if t ~= 'string' then
            fatal('%s[%s] must be a string, got %q', name, tostring(key1), t)
        end
        checkopt_map_array(val1, format('%s.%s', name, key1))
    end

    return true
end

--- opt_boolean check optional boolean type
--- @param v any
--- @param defv boolean? default value
--- @param ... any
--- @return boolean? v
local function checkopt_boolean(v, defv, ...)
    if v == nil then
        return defv
    elseif type(v) ~= 'boolean' then
        fatal(...)
    end
    return v
end

--- opt_string check optional string type
--- @param v any
--- @param defv string? default value
--- @param ... any
--- @return string? v
local function checkopt_string(v, defv, ...)
    if v == nil then
        return defv
    elseif type(v) ~= 'string' then
        fatal(...)
    end
    return v
end

--- validate_config validate configuration table
--- @param config table
local function validate_config(config)
    -- validate cc (optional)
    checkopt_string(config.cc, nil, 'cc must be a string or nil\n')
    -- validate output_status (optional)
    checkopt_boolean(config.output_status, nil,
                     'output_status must be a boolean or nil\n')
    -- validate features (optional)
    checkopt_table(config.features, 'features')
    -- validate cppflags (optional)
    checkopt_array(config.cppflags, 'cppflags')
    -- validate headers (optional)
    checkopt_array(config.headers, 'headers')
    -- validate funcs (optional)
    checkopt_map_array(config.funcs, 'funcs')
    -- validate types (optional)
    checkopt_map_array(config.types, 'types')
    -- validate decls (optional)
    checkopt_map_array(config.decls, 'decls')
    -- validate members (optional)
    checkopt_nested_map(config.members, 'members')
end

--- load configuration file
--- @param config_file string
--- @return table config
local function load_config(config_file)
    local fn, err = loadfile(config_file)
    if not fn then
        fatal('Error: failed to load config file: %s\n', err)
    end

    local ok, config = pcall(fn)
    if not ok then
        fatal('Error: failed to execute config file: %s\n', config)
    end

    if type(config) ~= 'table' then
        fatal('Error: config file must return a table\n')
    end

    validate_config(config)
    return config
end

--- print usage message
---
--- if err is given, print error message before usage message, then exit with
---  error code. otherwise, print usage message and exit with success code.
---
--- @param err string?
local function print_usage(...)
    local usage = [[

Usage: configh <config.lua> [--out=<filename>]

Arguments:
  <config.lua>        Path to the configuration Lua file.
  --out=<filename>    Specify the output header file name (default: config.h).

]]
    if ... then
        -- print error message and usage, then exit with error code
        perror(...)
        perror(usage)
        os.exit(1)
    end

    STDOUT:write(usage)
    os.exit(0)
end

--- parse_args parse command line arguments
--- @param args string[]
--- @return string config_file
--- @return string out_file
local function parse_args(args)
    if #args == 0 then
        print_usage()
    end

    local dupcheck = {}
    local out_file = 'config.h'
    local config_file
    for i = 1, #args do
        local arg = args[i]
        local key, val = arg:match('^([^=]+)=(.+)$')
        if key then
            if dupcheck[key] then
                print_usage('Error: multiple %q options specified\n', key)
            end
            dupcheck[key] = true
            if key == '--out' then
                out_file = val
            else
                print_usage('Error: unknown option %q\n', arg)
            end
        elseif not config_file then
            -- use as config file
            config_file = arg
        else
            print_usage('Error: multiple config files specified: %q and %q\n',
                        config_file, arg)
        end
    end

    if not config_file then
        print_usage('Error: no config file specified')
    end

    return config_file, out_file
end

--- command main command function
--- @param args string[]
--- @param stdout file*?
local function command(args, stdout, stderr)
    -- set std io files
    set_stdio_files(stdout, stderr)
    -- parse arguments and load config file
    local config_file, out_file = parse_args(args)
    local config = load_config(config_file)

    -- create configh object
    local cfgh = configh(config.cc or os.getenv('CC'))

    -- set output status
    if config.output_status then
        cfgh:output_status(true)
        cfgh:set_stdout(stdout)
    end

    -- set feature macros
    if config.features then
        for name, value in pairs(config.features) do
            if type(name) == 'string' then
                -- process key-value part (name with value)
                cfgh:set_feature(name, value)
            else
                -- process array part (name only)
                cfgh:set_feature(value)
            end
        end
    end

    -- add cppflags
    if config.cppflags then
        for _, flag in ipairs(config.cppflags) do
            cfgh:add_cppflag(flag)
        end
    end

    -- check headers
    if config.headers then
        for _, header in ipairs(config.headers) do
            cfgh:check_header(header)
        end
    end

    -- check funcs (only if header exists)
    if config.funcs then
        for header, funcs in pairs(config.funcs) do
            if cfgh:check_header(header) then
                for _, func in ipairs(funcs) do
                    cfgh:check_func(header, func)
                end
            end
        end
    end

    -- check types (only if header exists)
    if config.types then
        for header, types in pairs(config.types) do
            if cfgh:check_header(header) then
                for _, ctype in ipairs(types) do
                    cfgh:check_type(header, ctype)
                end
            end
        end
    end

    -- check decls (only if header exists)
    if config.decls then
        for header, decls in pairs(config.decls) do
            if cfgh:check_header(header) then
                for _, decl in ipairs(decls) do
                    cfgh:check_decl(header, decl)
                end
            end
        end
    end

    -- check members (only if header exists)
    if config.members then
        for header, members in pairs(config.members) do
            if cfgh:check_header(header) then
                for ctype, mems in pairs(members) do
                    for _, member in ipairs(mems) do
                        cfgh:check_member(header, ctype, member)
                    end
                end
            end
        end
    end

    -- flush config.h
    local ok, err = cfgh:flush(out_file)
    if not ok then
        fatal('Error: failed to write config.h: %s\n', err)
    end
end

return command

