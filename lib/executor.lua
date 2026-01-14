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
--- @field cppflags table<string, integer>|table<integer, string>
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

    self.cc = cc or os.getenv('CC') or 'gcc'
    self.features = {}
    self.cppflags = {}
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
            if not self.cppflags[flag] then
                self.cppflags[#self.cppflags + 1] = flag
                self.cppflags[flag] = #self.cppflags
            end
        end
    end

    return self
end

--- compile compile a c source file
--- @param exec configh.executor
--- @param srcfile string
--- @return boolean ok
--- @return string? err
local function compile(exec, srcfile)
    local objfile = 'a.out'
    local cmd = concat({
        exec.cc,
        concat(exec.cppflags, ' '),
        '-o',
        objfile,
        srcfile,
        '2>',
        exec.buffile,
    }, ' ')
    local res = execute(cmd)
    local ok = res == true
    if LUA_VERSION < 5.2 then
        ok = (res == 0)
    end

    -- cleanup
    remove(srcfile)
    if ok then
        -- successfully compiled
        remove(objfile)
        return true
    end

    local err = exec.buf:read('*a')
    assert(truncate(exec.buffile, 0))
    exec.buf:seek('set')

    return false, err
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
--- @param value? string
function Executor:set_feature(name, value)
    assert(type(name) == 'string', 'name must be string')
    assert(type(value) == 'string' or value == nil,
           'value must be string or nil')

    local feature = concat({
        '#define',
        name,
        value,
    }, ' ')
    local idx = self.features[name]
    if not idx then
        idx = #self.features + 1
    end
    self.features[idx] = feature
    self.features[name] = idx
end

--- unset_feature undefine the feature macro in testing
--- @param name string
function Executor:unset_feature(name)
    assert(type(name) == 'string', 'name must be string')

    local idx = self.features[name]
    if idx then
        self.features[name] = nil
        table.remove(self.features, idx)
    end
end

--- add_cppflag add a cppflag
--- @param flag string
function Executor:add_cppflag(flag)
    assert(type(flag) == 'string', 'flag must be string')

    if not self.cppflags[flag] then
        self.cppflags[#self.cppflags + 1] = flag
        self.cppflags[flag] = #self.cppflags
    end
end

--- remove_cppflag remove a cppflag
--- @param flag string
function Executor:remove_cppflag(flag)
    assert(type(flag) == 'string', 'flag must be string')

    local idx = self.cppflags[flag]
    if idx then
        self.cppflags[flag] = nil
        table.remove(self.cppflags, idx)
    end
end

--- check_header check the header is available
--- @param headers string|string[]
--- @return boolean ok
--- @return string? err
function Executor:check_header(headers)
    return compile(self, self:makecsrc(headers))
end

--- check_func check the function is available
--- @param headers string|string[]
--- @param func string
--- @return boolean ok
--- @return string? err
function Executor:check_func(headers, func)
    assert(type(func) == 'string', 'func must be a string')
    local code = 'void (*function_pointer)(void) = (void (*)(void))%s'
    return compile(self, self:makecsrc(headers, format(code, func)))
end

--- check_type check the type is available
--- @param headers string|string[]
--- @param ctype string
--- @return boolean ok
--- @return string? err
function Executor:check_type(headers, ctype)
    assert(type(ctype) == 'string', 'type must be a string')
    return compile(self, self:makecsrc(headers, format('%s x', ctype)))
end

--- check_member check the member field is available
--- @param headers string|string[]
--- @param ctype string
--- @param member string
--- @return boolean ok
--- @return string? err
function Executor:check_member(headers, ctype, member)
    assert(type(ctype) == 'string', 'type must be a string')
    assert(type(member) == 'string', 'member must be a string')
    return compile(self, self:makecsrc(headers, format('%s x; (void)x.%s',
                                                       ctype, member)))
end

Executor = require('metamodule').new(Executor)
return Executor

