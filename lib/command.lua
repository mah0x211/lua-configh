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
local isfile = require('io.isfile')
local generate = require('configh.generate')

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

--- load_config load and execute the configuration file
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
--- @param stderr file*?
local function command(args, stdout, stderr)
    set_stdio_files(stdout, stderr)
    local config_file, out_file = parse_args(args)
    local config = load_config(config_file)
    config.output = out_file
    local ok, report, err = pcall(generate, config, 'config', stdout)
    if not ok then
        fatal('Error: %s\n', report)
    elseif report == nil then
        fatal('Error: failed to write %s: %s\n', out_file, err)
    end
end

return command

