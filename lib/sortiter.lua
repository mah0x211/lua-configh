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
local pairs = pairs
local sort = table.sort

local function EMPTY_ITER()
end

--- get_value follows a field path through tbl, returning the target table and
--- the accumulated label path for use in error messages.
--- Returns nil if any step along the path is nil (target does not exist).
--- Errors if any non-nil step is not a table.
--- @param label string  root label for error messages
--- @param tbl table     root table
--- @param fields table  ordered list of field names to follow
--- @return table|nil t
--- @return string path
local function get_value(label, tbl, fields)
    local t = tbl
    local path = label
    for i = 1, #fields do
        local f = fields[i]
        local v = t[f]
        if v == nil then
            return nil, path
        end
        path = path .. '["' .. tostring(f) .. '"]'
        if type(v) ~= 'table' then
            error(path .. ' must be a table')
        end
        t = v
    end
    return t, path
end

--- sortedkpairs iterates the table reached by following fields from tbl,
--- yielding string keys in sorted order. Errors if any key is not a string.
--- @param label string  root label for error messages
--- @param tbl table     root table
--- @param ... string    field path to follow
--- @return function iter
local function sortedkpairs(label, tbl, ...)
    local t, path = get_value(label, tbl, {
        ...,
    })
    if not t then
        return EMPTY_ITER
    end
    local arr = {}
    for k, v in pairs(t) do
        if type(k) ~= 'string' then
            error(path .. ' keys must be string')
        end
        arr[#arr + 1] = {
            k = k,
            v = v,
        }
    end
    sort(arr, function(a, b)
        return a.k < b.k
    end)
    local i = 0
    return function()
        i = i + 1
        local e = arr[i]
        if e then
            return e.k, e.v
        end
    end
end

--- sortedipairs iterates the table reached by following fields from tbl in
--- integer-index order (1, 2, ...). Errors if any key is not an integer.
--- @param label string  root label for error messages
--- @param tbl table     root table
--- @param ... string    field path to follow
--- @return function iter
local function sortedipairs(label, tbl, ...)
    local t, path = get_value(label, tbl, {
        ...,
    })
    if not t then
        return EMPTY_ITER
    end
    for k in pairs(t) do
        if type(k) ~= 'number' or k % 1 ~= 0 then
            error(path .. ' keys must be integer')
        end
    end
    local i = 0
    return function()
        i = i + 1
        local v = t[i]
        if v ~= nil then
            return i, v
        end
    end
end

--- sortedpairs iterates the table reached by following fields from tbl,
--- yielding string keys first (sorted), then integer keys (sorted). Errors if
--- any key is neither a string nor an integer.
--- @param label string  root label for error messages
--- @param tbl table     root table
--- @param ... string    field path to follow
--- @return function iter
local function sortedpairs(label, tbl, ...)
    local t, path = get_value(label, tbl, {
        ...,
    })
    if not t then
        return EMPTY_ITER
    end
    local arr = {}
    for k, v in pairs(t) do
        local kt = type(k)
        if kt ~= 'string' and not (kt == 'number' and k % 1 == 0) then
            error(path .. ' keys must be string or integer')
        end
        arr[#arr + 1] = {
            t = kt,
            k = k,
            v = v,
        }
    end
    sort(arr, function(a, b)
        if a.t == b.t then
            return a.k < b.k
        end
        return a.t == 'string' -- string keys before integer keys
    end)
    local i = 0
    return function()
        i = i + 1
        local e = arr[i]
        if e then
            return e.k, e.v
        end
    end
end

return {
    kpairs = sortedkpairs,
    ipairs = sortedipairs,
    pairs = sortedpairs,
}
