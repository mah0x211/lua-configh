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

function testcase.makecsrc()
    local exec = executor('gcc')

    -- test that create a new c source file
    local pathname = exec:makecsrc('stdio.h', 'test_t x')
    local f = assert(io.open(pathname, 'r'))
    os.remove(pathname)
    local src = f:read('*a')
    f:close()
    assert.re_match(src, '^#include <stdio.h>', 'm')
    assert.re_match(src, '^\\s*test_t x;', 'm')
end

function testcase.set_and_unset_featrue()
    local exec = executor('gcc')

    -- test that set feature macro to use in c source file
    exec:set_feature('_GNU_SOURCE')
    assert.is_uint(exec.features._GNU_SOURCE)
    assert.equal(exec.features[exec.features._GNU_SOURCE], '#define _GNU_SOURCE')

    -- test that replace new feature macro
    exec:set_feature('_GNU_SOURCE', '123')
    assert.is_uint(exec.features._GNU_SOURCE)
    assert.equal(exec.features[exec.features._GNU_SOURCE],
                 '#define _GNU_SOURCE 123')

    -- test that remove feature macro
    exec:unset_feature('_GNU_SOURCE')
    assert.is_nil(exec.features._GNU_SOURCE)

    -- test that throws an error if name argument is not string
    local err = assert.throws(exec.set_feature, exec, 123)
    assert.match(err, 'name must be string')
    err = assert.throws(exec.unset_feature, exec, 123)
    assert.match(err, 'name must be string')

    -- test that throws an error if value argument is not string
    err = assert.throws(exec.set_feature, exec, '_GNU_SOURCE', 123)
    assert.match(err, 'value must be string or nil')
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

function testcase.check_type()
    local exec = executor('gcc')

    -- test that check whether the type is available
    local ok, err = exec:check_type('sys/socket.h', 'struct sockaddr_storage')
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return false if the types is not available
    ok, err = exec:check_type(nil, 'struct sockaddr_storage')
    assert.is_false(ok)
    assert.is_string(err)

    -- test that throws an error if type argument is not string
    err = assert.throws(exec.check_type, exec, 'stdio.h', 123)
    assert.match(err, 'type must be a string')
end

