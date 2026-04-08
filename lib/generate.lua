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
local assert = assert
local pairs = pairs
local type = type
local configh = require('configh')
local sort = require('configh.sortiter')

local sortedkpairs = sort.kpairs
local sortedipairs = sort.ipairs
local sortedpairs = sort.pairs

local VALID_CFG_KEYS = {
    cc = true,
    output = true,
    output_status = true,
    incdirs = true,
    libdirs = true,
    libs = true,
    cppflags = true,
    cflags = true,
    ldflags = true,
    features = true,
    headers = true,
    funcs = true,
    types = true,
    decls = true,
    members = true,
    sizeof = true,
}

--- ensure_header checks a header exactly once and records the result in
--- report[header]. Subsequent calls return the cached is_exists value
--- without re-running the probe (cfgh:check_header also deduplicates
--- internally, but this avoids the extra call entirely).
--- @param cfgh configh
--- @param report table
--- @param header string
--- @return boolean ok
local function ensure_header(cfgh, report, header)
    if report[header] then
        return report[header].is_exists
    end
    local ok = cfgh:check_header(header)
    report[header] = {
        is_exists = ok,
    }
    return ok
end

--- probe_headers ensures every header listed in cfg.headers is probed and
--- recorded in report.
--- @param cfgh configh
--- @param report table
--- @param label string
--- @param cfg table
local function probe_headers(cfgh, report, label, cfg)
    for _, header in sortedipairs(label, cfg, 'headers') do
        ensure_header(cfgh, report, header)
    end
end

--- probe_funcs probes each function under its header.  A header that does not
--- exist is skipped; its child entries are left as nil.
--- report[header][name] = true if the function is found, false otherwise.
--- @param cfgh configh
--- @param report table
--- @param label string
--- @param cfg table
local function probe_funcs(cfgh, report, label, cfg)
    for header in sortedkpairs(label, cfg, 'funcs') do
        if ensure_header(cfgh, report, header) then
            for _, name in sortedipairs(label, cfg, 'funcs', header) do
                report[header][name] = cfgh:check_func(header, name) == true
            end
        end
    end
end

--- probe_types probes each C type under its header.
--- report[header][name] = true if the type is found, false otherwise.
--- @param cfgh configh
--- @param report table
--- @param label string
--- @param cfg table
local function probe_types(cfgh, report, label, cfg)
    for header in sortedkpairs(label, cfg, 'types') do
        if ensure_header(cfgh, report, header) then
            for _, name in sortedipairs(label, cfg, 'types', header) do
                report[header][name] = cfgh:check_type(header, name) == true
            end
        end
    end
end

--- probe_decls probes each preprocessor constant/declaration under its header.
--- report[header][name] = true if the declaration is found, false otherwise.
--- @param cfgh configh
--- @param report table
--- @param label string
--- @param cfg table
local function probe_decls(cfgh, report, label, cfg)
    for header in sortedkpairs(label, cfg, 'decls') do
        if ensure_header(cfgh, report, header) then
            for _, name in sortedipairs(label, cfg, 'decls', header) do
                report[header][name] = cfgh:check_decl(header, name) == true
            end
        end
    end
end

--- probe_sizeof probes the byte size of each C type under its header.
--- report[header][name] = size:integer if the type is found, false otherwise.
--- The size value is read back from inspected.sizeof[name].size which
--- check_sizeof records internally after a successful compile.
--- @param cfgh configh
--- @param report table
--- @param label string
--- @param cfg table
local function probe_sizeof(cfgh, report, label, cfg)
    for header in sortedkpairs(label, cfg, 'sizeof') do
        if ensure_header(cfgh, report, header) then
            for _, name in sortedipairs(label, cfg, 'sizeof', header) do
                local ok, _, size = cfgh:check_sizeof(header, name)
                report[header][name] = ok and size or false
            end
        end
    end
end

--- probe_members probes each struct/union member under its header.
--- report[header]["ctype.member"] = true if the member is found, false
--- otherwise.
--- @param cfgh configh
--- @param report table
--- @param label string
--- @param cfg table
local function probe_members(cfgh, report, label, cfg)
    for header in sortedkpairs(label, cfg, 'members') do
        if ensure_header(cfgh, report, header) then
            for ctype in sortedkpairs(label, cfg, 'members', header) do
                for _, member in sortedipairs(label, cfg, 'members', header,
                                              ctype) do
                    report[header][ctype .. '.' .. member] = cfgh:check_member(
                                                                 header, ctype,
                                                                 member) == true
                end
            end
        end
    end
end

--- generate creates a new Configh instance, runs all probes described in cfg,
--- and flushes the result to cfg.output.
--- @param cfg table
--- @param label string?  root label for error messages (default: 'cfg')
--- @return table? report
--- @return string? err
local function generate(cfg, label)
    label = label or 'cfg'
    assert(type(label) == 'string', 'label must be a string')
    assert(type(cfg) == 'table', label .. ' must be a table')
    assert(type(cfg.output) == 'string', label .. '.output must be a string')
    for k in pairs(cfg) do
        assert(VALID_CFG_KEYS[k], label .. ': unknown key: ' .. tostring(k))
    end
    -- validate probe field structure before creating cfgh instance so that
    -- structure errors are reported before cc/CC validation errors
    for _, key in ipairs({
        'features',
        'headers',
        'funcs',
        'types',
        'decls',
        'sizeof',
        'members',
    }) do
        if cfg[key] ~= nil and type(cfg[key]) ~= 'table' then
            error(label .. '["' .. key .. '"] must be a table')
        end
    end

    local cfgh = configh(cfg.cc)

    if cfg.output_status ~= nil then
        cfgh:output_status(cfg.output_status)
    end
    if cfg.incdirs ~= nil then
        cfgh:set_incdirs(cfg.incdirs)
    end
    if cfg.libdirs ~= nil then
        cfgh:set_libdirs(cfg.libdirs)
    end
    if cfg.libs ~= nil then
        cfgh:set_libs(cfg.libs)
    end
    if cfg.cppflags ~= nil then
        cfgh:set_cppflags(cfg.cppflags)
    end
    if cfg.cflags ~= nil then
        cfgh:set_cflags(cfg.cflags)
    end
    if cfg.ldflags ~= nil then
        cfgh:set_ldflags(cfg.ldflags)
    end

    -- features: mixed table (string key = name+value, integer key = name only)
    -- sortedpairs ensures only string/integer keys are present, so the type(k)
    -- branch here is a semantic distinction, not an error guard.
    for k, v in sortedpairs(label, cfg, 'features') do
        if type(k) == 'string' then
            cfgh:set_feature(k, v)
        else
            cfgh:set_feature(v)
        end
    end

    local report = {}
    probe_headers(cfgh, report, label, cfg)
    probe_funcs(cfgh, report, label, cfg)
    probe_types(cfgh, report, label, cfg)
    probe_decls(cfgh, report, label, cfg)
    probe_sizeof(cfgh, report, label, cfg)
    probe_members(cfgh, report, label, cfg)

    local ok, err = cfgh:flush(cfg.output)
    if not ok then
        return nil, err
    end
    return report
end

return generate
