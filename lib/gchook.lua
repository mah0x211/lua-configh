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
local unpack = unpack or table.unpack

--- gc_hook returns an object that calls fn(...) when garbage collected.
--- Uses newproxy on Lua 5.1 (tables lack __gc support), setmetatable on 5.2+.
--- @param fn function called with captured args on GC
--- @return userdata|table hook
local function gc_hook(fn, ...)
    local narg = select('#', ...)
    local args = {
        ...,
    }
    local callback = function()
        fn(unpack(args, 1, narg))
    end

    -- Lua 5.1's newproxy supports __gc on userdata, but not tables.
    if newproxy then
        local p = newproxy(true)
        getmetatable(p).__gc = callback
        return p
    end

    -- Lua 5.2+ supports __gc on tables.
    return setmetatable({}, {
        __gc = callback,
    })
end

return gc_hook
