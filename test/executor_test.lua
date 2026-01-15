require('luacov')
local testcase = require('testcase')
local assert = require('assert')
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

    -- test that replace new feature macro with number value
    exec:set_feature('_GNU_SOURCE', 123)
    assert.is_uint(exec.features._GNU_SOURCE)
    assert.equal(exec.features[exec.features._GNU_SOURCE],
                 '#define _GNU_SOURCE 123')

    -- test that replace new feature macro with string value
    exec:set_feature('_GNU_SOURCE', '"foo"')
    assert.is_uint(exec.features._GNU_SOURCE)
    assert.equal(exec.features[exec.features._GNU_SOURCE],
                 '#define _GNU_SOURCE "foo"')

    -- test that remove feature macro
    exec:unset_feature('_GNU_SOURCE')
    assert.is_nil(exec.features._GNU_SOURCE)

    -- test that throws an error if name argument is nether nil, string nor number
    local err = assert.throws(exec.set_feature, exec, {})
    assert.match(err, 'name must be string')
    err = assert.throws(exec.unset_feature, exec, {})
    assert.match(err, 'name must be string')
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

function testcase.check_member()
    local exec = executor('gcc')

    -- test that check whether the member field is available
    local ok, err = exec:check_member('sys/socket.h', 'struct sockaddr',
                                      'sa_family')
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return false if the member field is not available
    ok, err = exec:check_member('sys/socket.h', 'struct sockaddr',
                                'unknown_member')
    assert.is_false(ok)
    assert.is_string(err)

    -- test that throws an error if type argument is not string
    err = assert.throws(exec.check_member, exec, 'sys/socket.h', 123)
    assert.match(err, 'type must be a string')

    -- test that throws an error if member argument is not string
    err = assert.throws(exec.check_member, exec, 'sys/socket.h',
                        'struct sockaddr', 123)
    assert.match(err, 'member must be a string')
end

function testcase.add_and_remove_cppflag()
    local exec = executor('gcc')

    -- test that add cppflag
    exec:add_cppflag('-I/usr/local/include')
    assert.is_uint(exec.cppflags['-I/usr/local/include'])
    assert.equal(exec.cppflags[exec.cppflags['-I/usr/local/include']],
                 '-I/usr/local/include')

    -- test that add multiple cppflags
    exec:add_cppflag('-I/opt/include')
    exec:add_cppflag('-DDEBUG')
    assert.equal(#exec.cppflags, 3)

    -- test that do not add duplicate cppflag
    exec:add_cppflag('-I/usr/local/include')
    assert.equal(#exec.cppflags, 3)

    -- test that remove cppflag
    exec:remove_cppflag('-I/usr/local/include')
    assert.is_nil(exec.cppflags['-I/usr/local/include'])
    assert.equal(#exec.cppflags, 2)

    -- test that remove non-existent cppflag does not throw error
    exec:remove_cppflag('-I/nonexistent')
    assert.equal(#exec.cppflags, 2)

    -- test that throws an error if flag argument is not string
    local err = assert.throws(exec.add_cppflag, exec, 123)
    assert.match(err, 'flag must be string')
    err = assert.throws(exec.remove_cppflag, exec, 123)
    assert.match(err, 'flag must be string')
end

function testcase.check_decl()
    local exec = executor('gcc')

    -- test that check whether the macro constant is defined
    local ok, err = exec:check_decl('limits.h', 'PATH_MAX')
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that check whether the enum value is defined
    ok, err = exec:check_decl('fcntl.h', 'O_RDONLY')
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that check whether the global variable is defined
    ok, err = exec:check_decl('errno.h', 'errno')
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return false if the declaration is not available
    ok, err = exec:check_decl('limits.h', 'UNKNOWN_CONSTANT')
    assert.is_false(ok)
    assert.is_string(err)

    -- test that throws an error if name argument is not string
    err = assert.throws(exec.check_decl, exec, 'stdio.h', 123)
    assert.match(err, 'name must be a string')
end

function testcase.cppflags_env()
    -- test that load CPPFLAGS environment variable
    setenv('CPPFLAGS', '-I/usr/local/include -DDEBUG')
    local exec = executor('gcc')
    assert.is_uint(exec.cppflags['-I/usr/local/include'])
    assert.is_uint(exec.cppflags['-DDEBUG'])
    assert.equal(#exec.cppflags, 2)
    setenv('CPPFLAGS', nil)

    -- test that CPPFLAGS environment variable is empty
    setenv('CPPFLAGS', '')
    exec = executor('gcc')
    assert.equal(#exec.cppflags, 0)
    setenv('CPPFLAGS', nil)
end

