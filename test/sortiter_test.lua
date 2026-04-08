require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local sort = require('configh.sortiter')

-- helper: collect all (k, v) pairs from a stateful closure iterator
local function collect(iter)
    local result = {}
    local k, v = iter()
    while k ~= nil do
        result[#result + 1] = {
            k,
            v,
        }
        k, v = iter()
    end
    return result
end

-- kpairs -----------------------------------------------------------------

function testcase.kpairs_returns_string_keys_sorted()
    local tbl = {
        foo = {
            c = 1,
            a = 2,
            b = 3,
        },
    }
    local result = collect(sort.kpairs('root', tbl, 'foo'))
    assert.equal(#result, 3)
    assert.equal(result[1][1], 'a')
    assert.equal(result[2][1], 'b')
    assert.equal(result[3][1], 'c')
end

function testcase.kpairs_returns_empty_iter_when_field_is_nil()
    local tbl = {}
    local result = collect(sort.kpairs('root', tbl, 'missing'))
    assert.equal(#result, 0)
end

function testcase.kpairs_errors_when_field_is_not_table()
    local err = assert.throws(sort.kpairs, 'root', {
        foo = 'bad',
    }, 'foo')
    assert.match(err, 'root["foo"] must be a table')
end

function testcase.kpairs_errors_on_non_string_key()
    local err = assert.throws(sort.kpairs, 'root', {
        foo = {
            [1] = 'x',
        },
    }, 'foo')
    assert.match(err, 'keys must be string')
end

function testcase.kpairs_traverses_nested_path()
    local tbl = {
        a = {
            b = {
                z = 1,
                y = 2,
            },
        },
    }
    local result = collect(sort.kpairs('root', tbl, 'a', 'b'))
    assert.equal(#result, 2)
    assert.equal(result[1][1], 'y')
    assert.equal(result[2][1], 'z')
end

function testcase.kpairs_errors_on_intermediate_non_table()
    local err = assert.throws(sort.kpairs, 'root', {
        a = {
            b = 'bad',
        },
    }, 'a', 'b', 'c')
    assert.match(err, 'root["a"]["b"] must be a table')
end

function testcase.kpairs_returns_empty_iter_when_intermediate_is_nil()
    local tbl = {
        a = {},
    }
    local result = collect(sort.kpairs('root', tbl, 'a', 'missing', 'c'))
    assert.equal(#result, 0)
end

-- ipairs -----------------------------------------------------------------

function testcase.ipairs_returns_integer_keys_in_order()
    local tbl = {
        arr = {
            'c',
            'a',
            'b',
        },
    }
    local result = collect(sort.ipairs('root', tbl, 'arr'))
    assert.equal(#result, 3)
    assert.equal(result[1][2], 'c')
    assert.equal(result[2][2], 'a')
    assert.equal(result[3][2], 'b')
end

function testcase.ipairs_returns_empty_iter_when_field_is_nil()
    local tbl = {}
    local result = collect(sort.ipairs('root', tbl, 'missing'))
    assert.equal(#result, 0)
end

function testcase.ipairs_errors_when_field_is_not_table()
    local err = assert.throws(sort.ipairs, 'root', {
        arr = 'bad',
    }, 'arr')
    assert.match(err, 'root["arr"] must be a table')
end

function testcase.ipairs_errors_on_non_integer_key()
    local err = assert.throws(sort.ipairs, 'root', {
        arr = {
            foo = 'x',
        },
    }, 'arr')
    assert.match(err, 'keys must be integer')
end

function testcase.ipairs_errors_on_float_key()
    local err = assert.throws(sort.ipairs, 'root', {
        arr = {
            [1.5] = 'x',
        },
    }, 'arr')
    assert.match(err, 'keys must be integer')
end

-- pairs ------------------------------------------------------------------

function testcase.pairs_returns_string_keys_then_integer_keys()
    local tbl = {
        mixed = {
            [2] = 'two',
            z = 'z',
            [1] = 'one',
            a = 'a',
        },
    }
    local result = collect(sort.pairs('root', tbl, 'mixed'))
    -- string keys first (sorted), then integer keys (sorted)
    assert.equal(result[1][1], 'a')
    assert.equal(result[2][1], 'z')
    assert.equal(result[3][1], 1)
    assert.equal(result[4][1], 2)
end

function testcase.pairs_returns_empty_iter_when_field_is_nil()
    local tbl = {}
    local result = collect(sort.pairs('root', tbl, 'missing'))
    assert.equal(#result, 0)
end

function testcase.pairs_errors_when_field_is_not_table()
    local err = assert.throws(sort.pairs, 'root', {
        mixed = 'bad',
    }, 'mixed')
    assert.match(err, 'root["mixed"] must be a table')
end

function testcase.pairs_errors_on_invalid_key_type()
    local err = assert.throws(sort.pairs, 'root', {
        mixed = {
            [true] = 'x',
        },
    }, 'mixed')
    assert.match(err, 'keys must be string or integer')
end

function testcase.pairs_errors_on_float_key()
    local err = assert.throws(sort.pairs, 'root', {
        mixed = {
            [1.5] = 'x',
        },
    }, 'mixed')
    assert.match(err, 'keys must be string or integer')
end
