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

    -- test that unset blanks the slot; name key is retained
    exec:unset_feature('_GNU_SOURCE')
    local idx = exec.features._GNU_SOURCE
    assert.is_uint(idx)
    assert.equal(exec.features[idx], '')

    -- test that set_feature reuses the existing slot after unset
    exec:set_feature('_GNU_SOURCE')
    assert.equal(exec.features._GNU_SOURCE, idx)
    assert.equal(exec.features[idx], '#define _GNU_SOURCE')

    -- test that throws an error if name argument is nether nil, string nor number
    local err = assert.throws(exec.set_feature, exec, {})
    assert.match(err, 'name must be string')
    err = assert.throws(exec.unset_feature, exec, {})
    assert.match(err, 'name must be string')
end

function testcase.unset_feature_reenable()
    local exec = executor('gcc')
    exec:set_feature('A')
    exec:set_feature('B')
    exec:set_feature('C')

    -- unset middle slot and confirm indices are stable
    local idx_a = exec.features.A
    local idx_b = exec.features.B
    local idx_c = exec.features.C
    exec:unset_feature('B')
    assert.equal(exec.features.A, idx_a)
    assert.equal(exec.features.B, idx_b)
    assert.equal(exec.features.C, idx_c)
    assert.equal(exec.features[idx_b], '')

    -- unset first slot
    exec:unset_feature('A')
    assert.equal(exec.features[idx_a], '')
    assert.equal(exec.features[idx_c], '#define C')

    -- re-enable B reuses its existing slot
    exec:set_feature('B', '1')
    assert.equal(exec.features.B, idx_b)
    assert.equal(exec.features[idx_b], '#define B 1')
end

function testcase.preprocess()
    local exec = executor('gcc')

    -- test that preprocess succeeds for an existing header
    local ok, err = exec:preprocess({
        headers = 'stdio.h',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that preprocess fails for a nonexistent header
    ok, err = exec:preprocess({
        headers = 'this_is_unknown_header_for_test.h',
    })
    assert.is_false(ok)
    assert.is_string(err)
end

function testcase.compile()
    local exec = executor('gcc')

    -- test that compile succeeds for an existing type (with header)
    local ok, err = exec:compile({
        headers = 'sys/socket.h',
        code = 'struct sockaddr_storage x',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that compile fails for an unknown type
    ok, err = exec:compile({
        code = 'unknown_type_xyz_for_test x',
    })
    assert.is_false(ok)
    assert.is_string(err)
end

function testcase.link()
    local exec = executor('gcc')

    -- test that link succeeds for an existing function (with header)
    local ok, err = exec:link({
        headers = 'stdio.h',
        code = 'void (*fp)(void) = (void (*)(void))printf',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that link fails for a nonexistent function
    ok, err = exec:link({
        code = 'void (*fp)(void) = (void (*)(void))nonexistent_func_xyz_for_test',
    })
    assert.is_false(ok)
    assert.is_string(err)
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

function testcase.set_cppflags()
    local exec = executor('gcc')

    -- test that set cppflags with a string
    exec:set_cppflags('-I/usr/local/include')
    assert.equal(#exec.cppflags, 1)
    assert.equal(exec.cppflags[1], '-I/usr/local/include')

    -- test that set cppflags with a string array
    exec:set_cppflags({
        '-I/usr/local/include',
        '-I/opt/include',
        '-DDEBUG',
    })
    assert.equal(#exec.cppflags, 3)
    assert.equal(exec.cppflags[1], '-I/usr/local/include')
    assert.equal(exec.cppflags[2], '-I/opt/include')
    assert.equal(exec.cppflags[3], '-DDEBUG')

    -- test that set_cppflags replaces the existing list
    exec:set_cppflags({
        '-I/new/path',
    })
    assert.equal(#exec.cppflags, 1)
    assert.equal(exec.cppflags[1], '-I/new/path')

    -- test that set_cppflags with empty array clears the list
    exec:set_cppflags({})
    assert.equal(#exec.cppflags, 0)

    -- test that empty string and whitespace-only strings are ignored
    exec:set_cppflags('')
    assert.equal(#exec.cppflags, 0)
    exec:set_cppflags({
        '-DFOO',
        '',
        '   ',
        '-DBAR',
    })
    assert.equal(#exec.cppflags, 2)
    assert.equal(exec.cppflags[1], '-DFOO')
    assert.equal(exec.cppflags[2], '-DBAR')

    -- test that leading/trailing whitespace is trimmed
    exec:set_cppflags('  -DTRIMMED  ')
    assert.equal(#exec.cppflags, 1)
    assert.equal(exec.cppflags[1], '-DTRIMMED')

    -- test that throws an error if flags is not string or table
    local err = assert.throws(exec.set_cppflags, exec, 123)
    assert.match(err, 'flags must be a string or string[]')

    -- test that throws an error if an element of flags is not string
    err = assert.throws(exec.set_cppflags, exec, {
        '-I/usr/local/include',
        123,
    })
    assert.match(err, 'flags#2 must be a string')
end

function testcase.add_cppflags()
    local exec = executor('gcc')

    -- test that add cppflags with a string
    exec:add_cppflags('-I/usr/local/include')
    assert.equal(#exec.cppflags, 1)
    assert.equal(exec.cppflags[1], '-I/usr/local/include')

    -- test that add cppflags with a string array appends to existing list
    exec:add_cppflags({
        '-I/opt/include',
        '-DDEBUG',
    })
    assert.equal(#exec.cppflags, 3)
    assert.equal(exec.cppflags[1], '-I/usr/local/include')
    assert.equal(exec.cppflags[2], '-I/opt/include')
    assert.equal(exec.cppflags[3], '-DDEBUG')

    -- test that set_cppflags replaces all flags including those added via add_cppflags
    exec:set_cppflags({
        '-I/new/path',
    })
    assert.equal(#exec.cppflags, 1)
    assert.equal(exec.cppflags[1], '-I/new/path')

    -- test that throws an error if flags is not string or table
    local err = assert.throws(exec.add_cppflags, exec, 123)
    assert.match(err, 'flags must be a string or string[]')

    -- test that throws an error if an element of flags is not string
    err = assert.throws(exec.add_cppflags, exec, {
        '-I/usr/local/include',
        123,
    })
    assert.match(err, 'flags#2 must be a string')
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
    assert.equal(#exec.cppflags, 2)
    assert.equal(exec.cppflags[1], '-I/usr/local/include')
    assert.equal(exec.cppflags[2], '-DDEBUG')

    -- test that add_cppflags appends to env-loaded flags
    exec:add_cppflags('-I/opt/include')
    assert.equal(#exec.cppflags, 3)
    assert.equal(exec.cppflags[3], '-I/opt/include')

    -- test that set_cppflags replaces env-loaded flags
    exec:set_cppflags({
        '-I/new/path',
    })
    assert.equal(#exec.cppflags, 1)
    assert.equal(exec.cppflags[1], '-I/new/path')
    setenv('CPPFLAGS', nil)

    -- test that CPPFLAGS environment variable is empty
    setenv('CPPFLAGS', '')
    exec = executor('gcc')
    assert.equal(#exec.cppflags, 0)
    setenv('CPPFLAGS', nil)
end

function testcase.set_incdirs()
    local exec = executor('gcc')

    -- test that set incdirs with a string
    exec:set_incdirs('/usr/local/include')
    assert.equal(#exec.incdirs, 1)
    assert.equal(exec.incdirs[1], '/usr/local/include')

    -- test that set incdirs with a string array
    exec:set_incdirs({
        '/usr/local/include',
        '/opt/include',
    })
    assert.equal(#exec.incdirs, 2)
    assert.equal(exec.incdirs[1], '/usr/local/include')
    assert.equal(exec.incdirs[2], '/opt/include')

    -- test that set_incdirs replaces the existing list
    exec:set_incdirs({
        '/new/path',
    })
    assert.equal(#exec.incdirs, 1)
    assert.equal(exec.incdirs[1], '/new/path')

    -- test that set_incdirs with empty array clears the list
    exec:set_incdirs({})
    assert.equal(#exec.incdirs, 0)

    -- test that empty string and whitespace-only strings are ignored
    exec:set_incdirs('')
    assert.equal(#exec.incdirs, 0)
    exec:set_incdirs({
        '/a',
        '',
        '   ',
        '/b',
    })
    assert.equal(#exec.incdirs, 2)
    assert.equal(exec.incdirs[1], '/a')
    assert.equal(exec.incdirs[2], '/b')

    -- test that leading/trailing whitespace is trimmed
    exec:set_incdirs('  /trimmed  ')
    assert.equal(#exec.incdirs, 1)
    assert.equal(exec.incdirs[1], '/trimmed')

    -- test that throws an error if dirs is not string or table
    local err = assert.throws(exec.set_incdirs, exec, 123)
    assert.match(err, 'flags must be a string or string[]')

    -- test that throws an error if an element of dirs is not string
    err = assert.throws(exec.set_incdirs, exec, {
        '/usr/local/include',
        123,
    })
    assert.match(err, 'flags#2 must be a string')
end

function testcase.add_incdirs()
    local exec = executor('gcc')

    -- test that add incdirs with a string
    exec:add_incdirs('/usr/local/include')
    assert.equal(#exec.incdirs, 1)
    assert.equal(exec.incdirs[1], '/usr/local/include')

    -- test that add incdirs with a string array appends to existing list
    exec:add_incdirs({
        '/opt/include',
    })
    assert.equal(#exec.incdirs, 2)
    assert.equal(exec.incdirs[1], '/usr/local/include')
    assert.equal(exec.incdirs[2], '/opt/include')

    -- test that set_incdirs replaces all dirs including those added via add_incdirs
    exec:set_incdirs({
        '/new/path',
    })
    assert.equal(#exec.incdirs, 1)
    assert.equal(exec.incdirs[1], '/new/path')

    -- test that throws an error if dirs is not string or table
    local err = assert.throws(exec.add_incdirs, exec, 123)
    assert.match(err, 'flags must be a string or string[]')

    -- test that throws an error if an element of dirs is not string
    err = assert.throws(exec.add_incdirs, exec, {
        '/usr/local/include',
        123,
    })
    assert.match(err, 'flags#2 must be a string')
end

function testcase.incdirs_functional()
    local exec = executor('gcc')

    -- create a unique temp directory with a custom header
    local tmpbase = os.tmpname()
    os.remove(tmpbase)
    local tmpdir = tmpbase .. '_incdirs'
    os.execute('mkdir -p ' .. tmpdir)
    local hfile = assert(io.open(tmpdir .. '/configh_custom_test.h', 'w'))
    hfile:write('/* configh test header */\n')
    hfile:close()

    -- test that check_header fails without incdirs set
    local ok = exec:check_header('configh_custom_test.h')
    assert.is_false(ok)

    -- test that check_header succeeds after adding the dir
    exec:add_incdirs(tmpdir)
    ok = exec:check_header('configh_custom_test.h')
    assert.is_true(ok)

    -- test that check_header fails after clearing incdirs
    exec:set_incdirs({})
    ok = exec:check_header('configh_custom_test.h')
    assert.is_false(ok)

    -- cleanup
    os.remove(tmpdir .. '/configh_custom_test.h')
    os.execute('rmdir ' .. tmpdir)
end

function testcase.set_cflags()
    local exec = executor('gcc')

    -- test that set cflags with a string
    exec:set_cflags('-O2')
    assert.equal(#exec.cflags, 1)
    assert.equal(exec.cflags[1], '-O2')

    -- test that set cflags with a string array
    exec:set_cflags({
        '-O2',
        '-Wall',
        '-Wextra',
    })
    assert.equal(#exec.cflags, 3)
    assert.equal(exec.cflags[1], '-O2')
    assert.equal(exec.cflags[2], '-Wall')
    assert.equal(exec.cflags[3], '-Wextra')

    -- test that set_cflags replaces the existing list
    exec:set_cflags({
        '-O0',
    })
    assert.equal(#exec.cflags, 1)
    assert.equal(exec.cflags[1], '-O0')

    -- test that set_cflags with empty array clears the list
    exec:set_cflags({})
    assert.equal(#exec.cflags, 0)

    -- test that empty string and whitespace-only strings are ignored
    exec:set_cflags('')
    assert.equal(#exec.cflags, 0)
    exec:set_cflags({
        '-O2',
        '',
        '   ',
        '-g',
    })
    assert.equal(#exec.cflags, 2)
    assert.equal(exec.cflags[1], '-O2')
    assert.equal(exec.cflags[2], '-g')

    -- test that leading/trailing whitespace is trimmed
    exec:set_cflags('  -O1  ')
    assert.equal(#exec.cflags, 1)
    assert.equal(exec.cflags[1], '-O1')

    -- test that throws an error if flags is not string or table
    local err = assert.throws(exec.set_cflags, exec, 123)
    assert.match(err, 'flags must be a string or string[]')

    -- test that throws an error if an element of flags is not string
    err = assert.throws(exec.set_cflags, exec, {
        '-O2',
        123,
    })
    assert.match(err, 'flags#2 must be a string')
end

function testcase.add_cflags()
    local exec = executor('gcc')

    -- test that add cflags with a string
    exec:add_cflags('-O2')
    assert.equal(#exec.cflags, 1)
    assert.equal(exec.cflags[1], '-O2')

    -- test that add cflags with a string array appends to existing list
    exec:add_cflags({
        '-Wall',
        '-Wextra',
    })
    assert.equal(#exec.cflags, 3)
    assert.equal(exec.cflags[1], '-O2')
    assert.equal(exec.cflags[2], '-Wall')
    assert.equal(exec.cflags[3], '-Wextra')

    -- test that set_cflags replaces all flags including those added via add_cflags
    exec:set_cflags({
        '-O0',
    })
    assert.equal(#exec.cflags, 1)
    assert.equal(exec.cflags[1], '-O0')

    -- test that throws an error if flags is not string or table
    local err = assert.throws(exec.add_cflags, exec, 123)
    assert.match(err, 'flags must be a string or string[]')

    -- test that throws an error if an element of flags is not string
    err = assert.throws(exec.add_cflags, exec, {
        '-O2',
        123,
    })
    assert.match(err, 'flags#2 must be a string')
end

function testcase.cflags_env()
    -- test that load CFLAGS environment variable
    setenv('CFLAGS', '-O2 -Wall')
    local exec = executor('gcc')
    assert.equal(#exec.cflags, 2)
    assert.equal(exec.cflags[1], '-O2')
    assert.equal(exec.cflags[2], '-Wall')

    -- test that add_cflags appends to env-loaded flags
    exec:add_cflags('-g')
    assert.equal(#exec.cflags, 3)
    assert.equal(exec.cflags[3], '-g')

    -- test that set_cflags replaces env-loaded flags
    exec:set_cflags({
        '-O0',
    })
    assert.equal(#exec.cflags, 1)
    assert.equal(exec.cflags[1], '-O0')
    setenv('CFLAGS', nil)

    -- test that CFLAGS environment variable is empty
    setenv('CFLAGS', '')
    exec = executor('gcc')
    assert.equal(#exec.cflags, 0)
    setenv('CFLAGS', nil)
end

