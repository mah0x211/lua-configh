require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local gc_hook = require('configh.gchook')

-- gc_hook calls fn when the returned object is garbage collected --------

function testcase.calls_fn_on_gc()
    local called = false
    do
        local _ = gc_hook(function()
            called = true
        end)
    end
    collectgarbage()
    collectgarbage()
    assert.is_true(called)
end

function testcase.fn_is_called_once()
    local count = 0
    do
        local _ = gc_hook(function()
            count = count + 1
        end)
    end
    collectgarbage()
    collectgarbage()
    assert.equal(count, 1)
end

function testcase.fn_receives_passed_arguments()
    local got
    do
        local _ = gc_hook(function(...)
            got = {
                ...,
            }
        end, 'a', 'b', 'c')
    end
    collectgarbage()
    collectgarbage()
    assert.equal(got, {
        'a',
        'b',
        'c',
    })
end

function testcase.fn_receives_no_arguments_when_none_passed()
    local nargs
    do
        local _ = gc_hook(function(...)
            nargs = select('#', ...)
        end)
    end
    collectgarbage()
    collectgarbage()
    assert.equal(nargs, 0)
end

function testcase.fn_can_close_over_values()
    local result
    local value = 'hello'
    do
        local _ = gc_hook(function()
            result = value
        end)
    end
    collectgarbage()
    collectgarbage()
    assert.equal(result, 'hello')
end
