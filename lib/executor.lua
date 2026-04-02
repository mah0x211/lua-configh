--
-- Copyright (C) 2023 Masatoshi Fukunaga
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
local assert = assert
local error = error
local type = type
local format = string.format
-- local gsub = string.gsub
local concat = table.concat
local getenv = os.getenv
local execute = os.execute
local tmpname = os.tmpname
local remove = os.remove
local open = io.open
local truncate = require('io.truncate')
local gcfn = require('gcfn')

--- @class configh.executor
--- @field cc string
--- @field features table<string, integer>|table<integer, string>
--- @field cppflags string[]
--- @field incdirs string[]
--- @field buffile string
--- @field buf file*
local Executor = {}

local LUA_VERSION = tonumber(_VERSION:match('Lua (%d+%.%d+)'))

--- new create a new configh.executor object
--- @param cc string?
--- @return configh.executor
function Executor:init(cc)
    if cc == nil then
        cc = getenv('CC')
        if not cc then
            error(
                'cc argument or CC environment variable must contain compiler name')
        end
    elseif type(cc) ~= 'string' then
        error('cc must be string or nil')
    end

    self.cc = cc
    self.features = {}
    self.cppflags = {}
    self.incdirs = {}
    self.buffile = assert(tmpname())
    self.buf = assert(open(self.buffile, 'r'))
    -- create new gcfn object
    self.gco = gcfn(function(pathname)
        remove(pathname)
    end, self.buffile)

    -- load CPPFLAGS environment variable
    local cppflags_str = getenv('CPPFLAGS')
    if cppflags_str then
        for flag in cppflags_str:gmatch('%S+') do
            self.cppflags[#self.cppflags + 1] = flag
        end
    end

    return self
end

--- read_error reads and clears the error buffer
--- @param exec configh.executor
--- @return string err
local function read_error(exec)
    local err = exec.buf:read('*a')
    assert(truncate(exec.buffile, 0))
    exec.buf:seek('set')
    return err
end

--- run_cmd executes a shell command and returns ok status
--- @param cmd string
--- @return boolean ok
local function run_cmd(cmd)
    local res = execute(cmd)
    if LUA_VERSION < 5.2 then
        return (res == 0)
    end
    return res == true
end

--- flags_flatten joins an array of bare strings into a space-separated
--- string, prepending prefix to each entry. Returns '' for empty arrays.
--- @param arr string[]
--- @param prefix? string
--- @return string
local function flags_flatten(arr, prefix)
    assert(prefix == nil or type(prefix) == 'string',
           'prefix must be string or nil')
    if #arr == 0 then
        return ''
    end
    prefix = prefix or ''
    return prefix .. concat(arr, ' ' .. prefix)
end

--- preprocess runs the C preprocessor to check if headers can be included
--- @param opts table  { headers: string|string[]|nil, code: string|nil }
--- @return boolean ok
--- @return string? err
function Executor:preprocess(opts)
    opts = opts or {}
    local srcfile = self:makecsrc(opts.headers, opts.code)
    local cmd = concat({
        self.cc,
        concat(self.cppflags, ' '),
        flags_flatten(self.incdirs, '-I'),
        '-E',
        srcfile,
        '-o /dev/null',
        '2>',
        self.buffile,
    }, ' ')
    local ok = run_cmd(cmd)
    remove(srcfile)
    if ok then
        return true
    end
    return false, read_error(self)
end

--- compile runs the compiler in syntax-only mode to check declarations
--- @param opts table  { headers: string|string[]|nil, code: string|nil }
--- @return boolean ok
--- @return string? err
function Executor:compile(opts)
    opts = opts or {}
    local srcfile = self:makecsrc(opts.headers, opts.code)
    local cmd = concat({
        self.cc,
        concat(self.cppflags, ' '),
        flags_flatten(self.incdirs, '-I'),
        '-fsyntax-only',
        srcfile,
        '2>',
        self.buffile,
    }, ' ')
    local ok = run_cmd(cmd)
    remove(srcfile)
    if ok then
        return true
    end
    return false, read_error(self)
end

--- link compiles and links to verify a symbol exists in the current libraries
--- @param opts table  { headers: string|string[]|nil, code: string|nil }
--- @return boolean ok
--- @return string? err
function Executor:link(opts)
    opts = opts or {}
    local srcfile = self:makecsrc(opts.headers, opts.code)
    local outfile = tmpname()
    local cmd = concat({
        self.cc,
        concat(self.cppflags, ' '),
        flags_flatten(self.incdirs, '-I'),
        '-o',
        outfile,
        srcfile,
        '2>',
        self.buffile,
    }, ' ')
    local ok = run_cmd(cmd)
    remove(srcfile)
    if ok then
        remove(outfile)
        return true
    end
    return false, read_error(self)
end

--- makecsrc create a new c source file
--- @param headers? string|string[]
--- @param code string?
--- @return string pathname
function Executor:makecsrc(headers, code)
    -- check headers
    if headers == nil then
        headers = {}
    elseif type(headers) == 'string' then
        headers = {
            headers,
        }
    elseif type(headers) ~= 'table' then
        error('headers must be a string or string[]')
    end
    local includes = {}
    for idx, header in ipairs(headers) do
        if type(header) ~= 'string' then
            error(format('headers#%d must be a string', idx))
        end
        includes[#includes + 1] = format('#include <%s>', header)
    end
    headers = concat(includes, '\n')

    -- check code
    if code ~= nil then
        assert(type(code) == 'string', 'code must be a string or nil')
        code = code .. ';'
    end

    -- feature macros
    local features = concat(self.features, '\n')

    -- create c source file
    local pathname = tmpname() .. '.c'
    local f = assert(open(pathname, 'w+'))

    local ok, err = f:write(format(concat({
        '%s',
        '',
        '%s',
        '',
        'int main() {',
        '    %s',
        '    return 0;',
        '}',
    }, '\n'), features, headers, code or ''))
    f:close()
    if not ok then
        remove(pathname)
        error(format('failed to make c source file: %s', err))
    end

    return pathname
end

--- set_feature define the feature macro in testing
--- @param name string
--- @param value? string|number
function Executor:set_feature(name, value)
    local tv = type(value)
    assert(type(name) == 'string', 'name must be string')
    assert(value == nil or tv == 'string' or tv == 'number',
           'value must be a string, number or nil')

    -- convert number to string
    if tv == 'number' then
        value = tostring(value)
    end

    local macro = concat({
        '#define',
        name,
        value,
    }, ' ')
    local idx = self.features[name]
    if idx then
        self.features[idx] = macro
    else
        self.features[#self.features + 1] = macro
        self.features[name] = #self.features
    end
end

--- unset_feature undefine the feature macro in testing
--- @param name string
function Executor:unset_feature(name)
    assert(type(name) == 'string', 'name must be string')

    local idx = self.features[name]
    if idx then
        self.features[idx] = ''
    end
end

--- add_flags validates and normalizes flags to a string array
--- @param arr string[]
--- @param flags string|string[]
--- @return string[]
local function add_flags(arr, flags)
    assert(type(arr) == 'table', 'arr must be a table')
    if type(flags) == 'string' then
        local trimmed = flags:match('^%s*(.-)%s*$')
        if trimmed ~= '' then
            arr[#arr + 1] = trimmed
        end
        return arr
    elseif type(flags) ~= 'table' then
        error('flags must be a string or string[]')
    end

    -- validate and append flags to array, skipping empty strings
    for i, v in ipairs(flags) do
        if type(v) ~= 'string' then
            error(format('flags#%d must be a string', i))
        end
        local trimmed = v:match('^%s*(.-)%s*$')
        if trimmed ~= '' then
            arr[#arr + 1] = trimmed
        end
    end
    return arr
end

--- add_cppflags append cppflags to the existing list
--- @param flags string|string[]
function Executor:add_cppflags(flags)
    add_flags(self.cppflags, flags)
end

--- set_cppflags set cppflags, replacing any previously set flags
--- @param flags string|string[]
function Executor:set_cppflags(flags)
    self.cppflags = add_flags({}, flags)
end

--- add_incdirs append include directories to the existing list
--- @param dirs string|string[]
function Executor:add_incdirs(dirs)
    add_flags(self.incdirs, dirs)
end

--- set_incdirs set include directories, replacing any previously set dirs
--- @param dirs string|string[]
function Executor:set_incdirs(dirs)
    self.incdirs = add_flags({}, dirs)
end

--- check_header check the header is available
--- @param headers string|string[]
--- @return boolean ok
--- @return string? err
function Executor:check_header(headers)
    return self:preprocess({
        headers = headers,
    })
end

--- check_func check the function is available
--- @param headers string|string[]|nil
--- @param func string
--- @return boolean ok
--- @return string? err
function Executor:check_func(headers, func)
    assert(type(func) == 'string', 'func must be a string')
    return self:link({
        headers = headers,
        code = format('void (*function_pointer)(void) = (void (*)(void))%s',
                      func),
    })
end

--- check_type check the type is available
--- @param headers string|string[]|nil
--- @param ctype string
--- @return boolean ok
--- @return string? err
function Executor:check_type(headers, ctype)
    assert(type(ctype) == 'string', 'type must be a string')
    return self:compile({
        headers = headers,
        code = format('%s x', ctype),
    })
end

--- check_decl check whether named symbol is defined as a macro or can be used as an r-value
--- @param headers string|string[]|nil
--- @param name string
--- @return boolean ok
--- @return string? err
function Executor:check_decl(headers, name)
    assert(type(name) == 'string', 'name must be a string')
    return self:compile({
        headers = headers,
        code = format('#ifndef %s\n    (void)%s;\n#endif\n\n', name, name),
    })
end

--- check_member check the member field is available
--- @param headers string|string[]|nil
--- @param ctype string
--- @param member string
--- @return boolean ok
--- @return string? err
function Executor:check_member(headers, ctype, member)
    assert(type(ctype) == 'string', 'type must be a string')
    assert(type(member) == 'string', 'member must be a string')
    return self:compile({
        headers = headers,
        code = format('%s x; (void)x.%s', ctype, member),
    })
end

Executor = require('metamodule').new(Executor)
return Executor

