require('luacov')
local testcase = require('testcase')
local setenv = require('setenv')
local executor = require('configh.executor')

function testcase.new_executor()
    -- test that create a new Executor object with compiler name
    local exec = executor('gcc')
    assert.match(exec, '^configh.executor: ', false)

    -- test that it create a temporary file
    local f, err = io.open(exec.buffile, 'r')
    assert.is_file(f)
    assert.is_nil(err)
    f:close()

    -- test that temporary file is removed after Executor object is garbage collected
    local buffile = exec.buffile
    -- luacheck: ignore 311
    exec = nil
    collectgarbage('collect')
    f, err = io.open(buffile, 'r')
    assert.is_nil(f)
    assert.is_string(err)

    -- test that create a new Exec object with CC environment variable
    setenv('CC', 'gcc')
    exec = executor('gcc')
    assert.match(exec, '^configh.executor: ', false)
    setenv('CC', nil)

    -- test that throws an error if cc is not string
    err = assert.throws(executor, 123)
    assert.match(err, 'cc must be string or nil')

    -- test that throws an error if cc and CC environment variable are not set
    err = assert.throws(executor)
    assert.match(err,
                 'cc argument or CC environment variable must contain compiler name')
end

function testcase.check_header()
    local exec = executor('gcc')

    -- test that check whether the header is available
    local ok, err = exec:check_header('stdio.h')
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return false if the header is not available
    ok, err = exec:check_header('this_is_unknown_header_for_test.h')
    assert.is_false(ok)
    assert.is_string(err)

    -- test that throws an error if header argument is not string
    err = assert.throws(exec.check_header, exec, 123)
    assert.match(err, 'headers must be a string or string[]')

    -- test that throws an error if headers contains non-string value
    err = assert.throws(exec.check_header, exec, {
        'stdio.h',
        123,
    })
    assert.match(err, 'headers#2 must be a string')
end

function testcase.check_func()
    local exec = executor('gcc')

    -- test that check whether the function is available
    local ok, err = exec:check_func('stdio.h', 'printf')
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return false if the function is not available
    ok, err = exec:check_func(nil, 'printf')
    assert.is_false(ok)
    assert.is_string(err)

    -- test that throws an error if func argument is not string
    err = assert.throws(exec.check_func, exec, 'stdio.h', 123)
    assert.match(err, 'func must be a string')
end

