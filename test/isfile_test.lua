require('luacov')
-- save real file handles before testcase wraps io.stderr and io.stdout
local REAL_STDERR = io.stderr
local REAL_STDOUT = io.stdout
local testcase = require('testcase')
local assert = require('assert')

local function reload()
    package.loaded['configh.isfile'] = nil
    return require('configh.isfile')
end

-- is_file returns true for standard file handles ---------------------------

function testcase.returns_true_for_stderr()
    local is_file = reload()
    assert.is_true(is_file(REAL_STDERR))
end

function testcase.returns_true_for_stdout()
    local is_file = reload()
    assert.is_true(is_file(REAL_STDOUT))
end

function testcase.returns_true_for_opened_file()
    local is_file = reload()
    local f = assert(io.tmpfile())
    local ok = is_file(f)
    f:close()
    assert.is_true(ok)
end

-- is_file returns false for non-file values --------------------------------

function testcase.returns_false_for_nil()
    local is_file = reload()
    assert.is_false(is_file(nil))
end

function testcase.returns_false_for_boolean()
    local is_file = reload()
    assert.is_false(is_file(true))
end

function testcase.returns_false_for_number()
    local is_file = reload()
    assert.is_false(is_file(42))
end

function testcase.returns_false_for_string()
    local is_file = reload()
    assert.is_false(is_file('hello'))
end

function testcase.returns_false_for_plain_table()
    local is_file = reload()
    assert.is_false(is_file({}))
end

function testcase.returns_false_for_table_with_metatable()
    local is_file = reload()
    local t = setmetatable({}, {})
    assert.is_false(is_file(t))
end

-- FILE_MT is cached: second call skips initialization ----------------------

function testcase.result_is_consistent_across_calls()
    local is_file = reload()
    -- first call triggers lazy init
    assert.is_true(is_file(REAL_STDERR))
    -- second call uses cached FILE_MT
    assert.is_true(is_file(REAL_STDERR))
    assert.is_false(is_file({}))
end

-- fallback paths when standard handles lack a metatable -------------------

function testcase.falls_back_to_stdout_when_stderr_lacks_metatable()
    local is_file = reload()
    local orig_stderr = io.stderr
    local orig_stdout = io.stdout
    -- luacheck: push ignore 122
    io.stderr = {} -- plain table: getmetatable returns nil, assert fails
    io.stdout = REAL_STDOUT -- ensure stdout is a real file handle for fallback
    local ok, result = pcall(is_file, REAL_STDOUT)
    io.stderr = orig_stderr
    io.stdout = orig_stdout
    -- luacheck: pop
    assert.is_true(ok)
    assert.is_true(result)
end

function testcase.falls_back_to_tmpfile_when_stderr_and_stdout_lack_metatable()
    local is_file = reload()
    local orig_err = io.stderr
    local orig_out = io.stdout
    local f = io.tmpfile() -- open before mocking so it has the real metatable
    -- luacheck: push ignore 122
    io.stderr = {}
    io.stdout = {}
    local ok, result = pcall(is_file, f)
    io.stderr = orig_err
    io.stdout = orig_out
    -- luacheck: pop
    f:close()
    assert.is_true(ok)
    assert.is_true(result)
end

function testcase.returns_false_when_file_mt_cannot_be_resolved()
    local is_file = reload()
    local orig_err = io.stderr
    local orig_out = io.stdout
    local orig_tmp = io.tmpfile
    -- luacheck: push ignore 122
    io.stderr = {}
    io.stdout = {}
    io.tmpfile = function()
        return nil
    end -- assert(nil) will throw inside pcall
    local ok, result = pcall(is_file, {})
    io.stderr = orig_err
    io.stdout = orig_out
    io.tmpfile = orig_tmp
    -- luacheck: pop
    assert.is_true(ok)
    assert.is_false(result)
end
