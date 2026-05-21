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
local gchook = require('configh.gchook')

--- @class configh.executor
--- @field private __classname string
--- @field cc string
--- @field features table<string, integer>|table<integer, string>
--- @field cppflags string[]
--- @field incdirs string[]
--- @field cflags string[]
--- @field libdirs string[]
--- @field libs string[]
--- @field ldflags string[]
--- @field buffile string
--- @field buf file*
local Executor = {}
Executor.__index = Executor

--- __tostring returns the class name for debugging purposes
--- @return string
function Executor:__tostring()
    return self.__classname
end

local LUA_VERSION = tonumber(_VERSION:match('Lua (%d+%.%d+)'))

--- load_env_flags reads space-separated flags from an environment variable
--- into the given array.
--- @param arr string[]
--- @param name string
local function load_env_flags(arr, name)
    local s = getenv(name)
    if s then
        for flag in s:gmatch('%S+') do
            arr[#arr + 1] = flag
        end
    end
end

--- read_error reads and clears the error buffer
--- @param exec configh.executor
--- @return string err
local function read_error(exec)
    local err = exec.buf:read('*a')
    assert(open(exec.buffile, 'w')):close()
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

--- compile runs the compiler to check declarations.
--- Without opts.outfile it uses -fsyntax-only (no output file).
--- With opts.outfile it compiles to an object file with -c.
--- opts fields:
---   headers  string|string[]|nil  include headers
---   code     string?              code placed inside main()
---   outfile  string?              path for the produced .o; enables -c mode
--- @param opts table
--- @return boolean ok
--- @return string? err
function Executor:compile(opts)
    opts = opts or {}
    local srcfile = self:makecsrc(opts.headers, opts.code)
    local cmd = concat({
        self.cc,
        concat(self.cppflags, ' '),
        flags_flatten(self.incdirs, '-I'),
        concat(self.cflags, ' '),
        not opts.outfile and '-fsyntax-only' or '-c -o ' .. opts.outfile,
        srcfile,
        '2>',
        self.buffile,
    }, ' ')
    local ok = run_cmd(cmd)
    remove(srcfile)
    if ok then
        return true
    end
    if opts.outfile then
        remove(opts.outfile)
    end
    return false, read_error(self)
end

--- link compiles and links to verify a symbol exists in the current libraries
--- opts fields:
---   headers  string|string[]|nil  include headers
---   code     string?              code placed inside main()
--- @param opts table
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
        concat(self.cflags, ' '),
        '-o',
        outfile,
        srcfile,
        concat(self.ldflags, ' '),
        flags_flatten(self.libdirs, '-L'),
        flags_flatten(self.libs, '-l'),
        flags_flatten(opts.extra_libs or {}, '-l'),
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
    assert(code == nil or type(code) == 'string', 'code must be a string or nil')

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

--- add_cflags append cflags to the existing list
--- @param flags string|string[]
function Executor:add_cflags(flags)
    add_flags(self.cflags, flags)
end

--- set_cflags set cflags, replacing any previously set flags
--- @param flags string|string[]
function Executor:set_cflags(flags)
    self.cflags = add_flags({}, flags)
end

--- add_libdirs append library directories to the existing list
--- @param dirs string|string[]
function Executor:add_libdirs(dirs)
    add_flags(self.libdirs, dirs)
end

--- set_libdirs set library directories, replacing any previously set dirs
--- @param dirs string|string[]
function Executor:set_libdirs(dirs)
    self.libdirs = add_flags({}, dirs)
end

--- add_libs append library names to the existing list
--- @param libs string|string[]
function Executor:add_libs(libs)
    add_flags(self.libs, libs)
end

--- set_libs set library names, replacing any previously set names
--- @param libs string|string[]
function Executor:set_libs(libs)
    self.libs = add_flags({}, libs)
end

--- add_ldflags append ldflags to the existing list
--- @param flags string|string[]
function Executor:add_ldflags(flags)
    add_flags(self.ldflags, flags)
end

--- set_ldflags set ldflags, replacing any previously set flags
--- @param flags string|string[]
function Executor:set_ldflags(flags)
    self.ldflags = add_flags({}, flags)
end

--- check_header check the header is available
--- @param params table  { headers: string }
--- @return boolean ok
--- @return string? err
function Executor:check_header(params)
    assert(type(params) == 'table', 'params must be a table')
    assert(type(params.headers) == 'string', 'params.headers must be a string')
    return self:preprocess({
        headers = params.headers,
    })
end

--- check_func check the function is available
--- @param params table  { headers: string|string[]|nil, name: string, library: string? }
---                      library is the name passed to -l (e.g. "m" for -lm)
--- @return boolean ok
--- @return string? err
function Executor:check_func(params)
    assert(type(params) == 'table', 'params must be a table')
    assert(type(params.name) == 'string', 'params.name must be a string')
    assert(params.library == nil or type(params.library) == 'string',
           'params.library must be a string or nil')
    return self:link({
        headers = params.headers,
        code = format('void (*function_pointer)(void) = (void (*)(void))%s;',
                      params.name),
        extra_libs = params.library and {
            params.library,
        } or {},
    })
end

--- check_type check the type is available
--- @param params table  { headers: string|string[]|nil, name: string }
---                      name is the C type name (e.g. "struct sockaddr_storage")
--- @return boolean ok
--- @return string? err
function Executor:check_type(params)
    assert(type(params) == 'table', 'params must be a table')
    assert(type(params.name) == 'string', 'params.name must be a string')
    return self:compile({
        headers = params.headers,
        code = format('%s x;', params.name),
    })
end

--- check_decl check whether named symbol is defined as a macro or can be used as an r-value
--- @param params table  { headers: string|string[]|nil, name: string }
--- @return boolean ok
--- @return string? err
function Executor:check_decl(params)
    assert(type(params) == 'table', 'params must be a table')
    assert(type(params.name) == 'string', 'params.name must be a string')
    return self:compile({
        headers = params.headers,
        code = format('#ifndef %s\n    (void)%s;\n#endif\n\n', params.name,
                      params.name),
    })
end

--- check_member check the member field is available
--- @param params table  { headers: string|string[]|nil, name: string, member: string }
---                      name is the C struct type name (e.g. "struct sockaddr")
--- @return boolean ok
--- @return string? err
function Executor:check_member(params)
    assert(type(params) == 'table', 'params must be a table')
    assert(type(params.name) == 'string', 'params.name must be a string')
    assert(type(params.member) == 'string', 'params.member must be a string')
    return self:compile({
        headers = params.headers,
        code = format('%s x; (void)x.%s;', params.name, params.member),
    })
end

--- check_sizeof determines the size of a C type by embedding sizeof() as
--- explicit big-endian bytes in a global array within the compiled object
--- file, then scanning the binary to extract the value.  The per-call
--- unique objfile path is used as the signature, so false matches against
--- any content from user-specified headers cannot occur.
--- @param params table  { headers: string|string[]|nil, name: string }  name is the C type name (e.g. "size_t")
--- @return boolean ok
--- @return string? err
--- @return integer? size  the sizeof(params.name), or nil if undetermined
function Executor:check_sizeof(params)
    assert(type(params) == 'table', 'params must be a table')
    assert(type(params.name) == 'string', 'params.name must be a string')
    local ctype = params.name

    local objfile = tmpname() .. '.o'
    -- Encode the unique objfile path as decimal byte values so it can be
    -- used as the signature inside the C initializer without quoting issues.
    -- The reversed path is used as the end marker so that size=0 can be
    -- distinguished from "signature not found".
    local sig = objfile
    local sig_end = sig:reverse()
    local sig_c, sig_end_c = {}, {}
    for i = 1, #sig do
        sig_c[i] = sig:byte(i)
        sig_end_c[i] = sig_end:byte(i)
    end

    -- Cast to unsigned long long before shifting to avoid UB on 32-bit
    -- targets where sizeof(T) may be a 32-bit size_t.
    local varname = 'configh_sizeof_' .. ctype:gsub('[^%w]', '_')
    local code = ([[
static unsigned char $VARNAME[] = {
    $SIG,
    (unsigned char)(((unsigned long long)sizeof($CTYPE) >> 56) & 0xFF),
    (unsigned char)(((unsigned long long)sizeof($CTYPE) >> 48) & 0xFF),
    (unsigned char)(((unsigned long long)sizeof($CTYPE) >> 40) & 0xFF),
    (unsigned char)(((unsigned long long)sizeof($CTYPE) >> 32) & 0xFF),
    (unsigned char)(((unsigned long long)sizeof($CTYPE) >> 24) & 0xFF),
    (unsigned char)(((unsigned long long)sizeof($CTYPE) >> 16) & 0xFF),
    (unsigned char)(((unsigned long long)sizeof($CTYPE) >>  8) & 0xFF),
    (unsigned char)(((unsigned long long)sizeof($CTYPE) >>  0) & 0xFF),
    $SIG_END
};
return (int)((char*)&$VARNAME - (char*)0);]]):gsub('%$([A-Z_]+)', {
        VARNAME = varname,
        SIG = concat(sig_c, ','),
        SIG_END = concat(sig_end_c, ','),
        CTYPE = ctype,
    })

    local ok, err = self:compile({
        headers = params.headers,
        code = code,
        outfile = objfile,
    })
    if not ok then
        return false, err
    end

    -- read object binary and locate the size bytes between the two signatures
    local bf = assert(open(objfile, 'rb'))
    local data = assert(bf:read('*a'))
    bf:close()
    remove(objfile)

    -- search for the signature and verify the end marker follows the size bytes
    local pos = data:find(sig, 1, true)
    if not pos then
        return false, format('unable to determine sizeof(%s)', ctype)
    end
    local size_start = pos + #sig
    if data:sub(size_start + 8, size_start + 7 + #sig_end) ~= sig_end then
        return false, format('unable to determine sizeof(%s)', ctype)
    end

    -- the 8 bytes between the two signatures are the size in big-endian order
    local size = 0
    for i = 0, 7 do
        size = size * 256 + data:byte(size_start + i)
    end
    return true, nil, size
end

--- new create a new configh.executor object
--- @param cc string?
--- @return configh.executor
local function new(cc)
    if cc == nil then
        cc = getenv('CC')
        if not cc then
            error(
                'cc argument or CC environment variable must contain compiler name')
        end
    elseif type(cc) ~= 'string' then
        error('cc must be string or nil')
    end

    -- trim whitespace
    cc = cc:match('^%s*(.-)%s*$')
    if not cc:find('^[a-zA-Z]') then
        error('cc must start with an ASCII letter')
    end

    local self = {
        cc = cc,
        features = {},
        cppflags = {},
        incdirs = {},
        cflags = {},
        libdirs = {},
        libs = {},
        ldflags = {},
        buffile = assert(tmpname()),
    }
    self.__classname = format('configh.executor: %s', tostring(self))
    self.buf = assert(open(self.buffile, 'r'))
    -- register a GC hook to delete the temp file when executor is collected
    self.gco = gchook(function(pathname)
        remove(pathname)
    end, self.buffile)

    -- load environment variables for flag fields
    load_env_flags(self.cppflags, 'CPPFLAGS')
    load_env_flags(self.cflags, 'CFLAGS')
    load_env_flags(self.ldflags, 'LDFLAGS')

    return setmetatable(self, Executor)
end

return new
