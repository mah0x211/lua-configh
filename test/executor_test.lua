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

    -- test that throws an error if cc is empty or whitespace-only
    err = assert.throws(executor, '')
    assert.match(err, 'cc must start with an ASCII letter')
    err = assert.throws(executor, '   ')
    assert.match(err, 'cc must start with an ASCII letter')

    -- test that throws an error if cc does not start with a letter
    err = assert.throws(executor, '123gcc')
    assert.match(err, 'cc must start with an ASCII letter')
    err = assert.throws(executor, '/usr/bin/cc')
    assert.match(err, 'cc must start with an ASCII letter')
end

function testcase.makecsrc()
    local exec = executor('gcc')

    -- test that create a new c source file
    local pathname = exec:makecsrc('stdio.h', 'test_t x;')
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
        code = 'struct sockaddr_storage x;',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that compile fails for an unknown type
    ok, err = exec:compile({
        code = 'unknown_type_xyz_for_test x;',
    })
    assert.is_false(ok)
    assert.is_string(err)
end

function testcase.link()
    local exec = executor('gcc')

    -- test that link succeeds for an existing function (with header)
    local ok, err = exec:link({
        headers = 'stdio.h',
        code = 'void (*fp)(void) = (void (*)(void))printf;',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that link fails for a nonexistent function
    ok, err = exec:link({
        code = 'void (*fp)(void) = (void (*)(void))nonexistent_func_xyz_for_test;',
    })
    assert.is_false(ok)
    assert.is_string(err)
end

function testcase.check_header()
    local exec = executor('gcc')

    -- test that check whether the header is available
    local ok, err = exec:check_header({
        headers = 'stdio.h',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return false if the header is not available
    ok, err = exec:check_header({
        headers = 'this_is_unknown_header_for_test.h',
    })
    assert.is_false(ok)
    assert.is_string(err)

    -- test that throws an error if params is not a table
    err = assert.throws(exec.check_header, exec, 'stdio.h')
    assert.match(err, 'params must be a table')

    -- test that throws an error if params.headers is not string
    err = assert.throws(exec.check_header, exec, {
        headers = 123,
    })
    assert.match(err, 'params.headers must be a string')
end

function testcase.check_func()
    local exec = executor('gcc')

    -- test that check whether the function is available
    local ok, err = exec:check_func({
        headers = 'stdio.h',
        name = 'printf',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return false if the function is not available (no headers)
    ok, err = exec:check_func({
        name = 'printf',
    })
    assert.is_false(ok)
    assert.is_string(err)

    -- test that throws an error if params is not a table
    err = assert.throws(exec.check_func, exec, 'stdio.h')
    assert.match(err, 'params must be a table')

    -- test that throws an error if params.name is not string
    err = assert.throws(exec.check_func, exec, {
        headers = 'stdio.h',
        name = 123,
    })
    assert.match(err, 'params.name must be a string')

    -- test that check with a library links against it
    ok, err = exec:check_func({
        headers = 'math.h',
        name = 'sin',
        library = 'm',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that returns false when the library does not exist
    ok, err = exec:check_func({
        name = 'no_such_func_xyz',
        library = 'no_such_lib_xyz_for_test',
    })
    assert.is_false(ok)
    assert.is_string(err)

    -- test that throws an error if params.library is not string or nil
    err = assert.throws(exec.check_func, exec, {
        headers = 'stdio.h',
        name = 'printf',
        library = 123,
    })
    assert.match(err, 'params.library must be a string or nil')
end

function testcase.check_type()
    local exec = executor('gcc')

    -- test that check whether the type is available
    local ok, err = exec:check_type({
        headers = 'sys/socket.h',
        name = 'struct sockaddr_storage',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return false if the type is not available (no headers)
    ok, err = exec:check_type({
        name = 'struct sockaddr_storage',
    })
    assert.is_false(ok)
    assert.is_string(err)

    -- test that throws an error if params is not a table
    err = assert.throws(exec.check_type, exec, 'sys/socket.h')
    assert.match(err, 'params must be a table')

    -- test that throws an error if params.name is not string
    err = assert.throws(exec.check_type, exec, {
        headers = 'stdio.h',
        name = 123,
    })
    assert.match(err, 'params.name must be a string')
end

function testcase.check_member()
    local exec = executor('gcc')

    -- test that check whether the member field is available
    local ok, err = exec:check_member({
        headers = 'sys/socket.h',
        name = 'struct sockaddr',
        member = 'sa_family',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return false if the member field is not available
    ok, err = exec:check_member({
        headers = 'sys/socket.h',
        name = 'struct sockaddr',
        member = 'unknown_member',
    })
    assert.is_false(ok)
    assert.is_string(err)

    -- test that throws an error if params is not a table
    err = assert.throws(exec.check_member, exec, 'sys/socket.h')
    assert.match(err, 'params must be a table')

    -- test that throws an error if params.name is not string
    err = assert.throws(exec.check_member, exec, {
        headers = 'sys/socket.h',
        name = 123,
    })
    assert.match(err, 'params.name must be a string')

    -- test that throws an error if params.member is not string
    err = assert.throws(exec.check_member, exec, {
        headers = 'sys/socket.h',
        name = 'struct sockaddr',
        member = 123,
    })
    assert.match(err, 'params.member must be a string')
end

function testcase.check_sizeof()
    local exec = executor('gcc')

    -- test that returns the size of a primitive type
    local ok, err, size = exec:check_sizeof({
        name = 'char',
    })
    assert.is_true(ok)
    assert.is_nil(err)
    assert.equal(size, 1)

    -- test that returns the correct size for int (typically 4)
    ok, err, size = exec:check_sizeof({
        name = 'int',
    })
    assert.is_true(ok)
    assert.is_nil(err)
    assert.is_number(size)
    assert.is_true(size > 0)

    -- test that returns size using a header type
    ok, err, size = exec:check_sizeof({
        headers = 'stddef.h',
        name = 'size_t',
    })
    assert.is_true(ok)
    assert.is_nil(err)
    assert.is_number(size)
    assert.is_true(size > 0)

    -- test that returns false for an unknown type
    ok, err, size = exec:check_sizeof({
        name = 'no_such_type_t',
    })
    assert.is_false(ok)
    assert.is_string(err)
    assert.is_nil(size)

    -- test that throws an error if params is not a table
    err = assert.throws(exec.check_sizeof, exec, 'char')
    assert.match(err, 'params must be a table')

    -- test that throws an error if params.name is not string
    err = assert.throws(exec.check_sizeof, exec, {
        name = 123,
    })
    assert.match(err, 'params.name must be a string')
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
    local ok, err = exec:check_decl({
        headers = 'limits.h',
        name = 'PATH_MAX',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that check whether the enum value is defined
    ok, err = exec:check_decl({
        headers = 'fcntl.h',
        name = 'O_RDONLY',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that check whether the global variable is defined
    ok, err = exec:check_decl({
        headers = 'errno.h',
        name = 'errno',
    })
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return false if the declaration is not available
    ok, err = exec:check_decl({
        headers = 'limits.h',
        name = 'UNKNOWN_CONSTANT',
    })
    assert.is_false(ok)
    assert.is_string(err)

    -- test that throws an error if params is not a table
    err = assert.throws(exec.check_decl, exec, 'stdio.h')
    assert.match(err, 'params must be a table')

    -- test that throws an error if params.name is not string
    err = assert.throws(exec.check_decl, exec, {
        headers = 'stdio.h',
        name = 123,
    })
    assert.match(err, 'params.name must be a string')
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
    local ok = exec:check_header({
        headers = 'configh_custom_test.h',
    })
    assert.is_false(ok)

    -- test that check_header succeeds after adding the dir
    exec:add_incdirs(tmpdir)
    ok = exec:check_header({
        headers = 'configh_custom_test.h',
    })
    assert.is_true(ok)

    -- test that check_header fails after clearing incdirs
    exec:set_incdirs({})
    ok = exec:check_header({
        headers = 'configh_custom_test.h',
    })
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

function testcase.set_libdirs()
    local exec = executor('gcc')

    -- test that set libdirs with a string
    exec:set_libdirs('/usr/local/lib')
    assert.equal(#exec.libdirs, 1)
    assert.equal(exec.libdirs[1], '/usr/local/lib')

    -- test that set libdirs with a string array
    exec:set_libdirs({
        '/usr/local/lib',
        '/opt/lib',
    })
    assert.equal(#exec.libdirs, 2)
    assert.equal(exec.libdirs[1], '/usr/local/lib')
    assert.equal(exec.libdirs[2], '/opt/lib')

    -- test that set_libdirs replaces the existing list
    exec:set_libdirs({
        '/new/lib',
    })
    assert.equal(#exec.libdirs, 1)
    assert.equal(exec.libdirs[1], '/new/lib')

    -- test that set_libdirs with empty array clears the list
    exec:set_libdirs({})
    assert.equal(#exec.libdirs, 0)

    -- test that empty string and whitespace-only strings are ignored
    exec:set_libdirs('')
    assert.equal(#exec.libdirs, 0)
    exec:set_libdirs({
        '/a',
        '',
        '   ',
        '/b',
    })
    assert.equal(#exec.libdirs, 2)
    assert.equal(exec.libdirs[1], '/a')
    assert.equal(exec.libdirs[2], '/b')

    -- test that leading/trailing whitespace is trimmed
    exec:set_libdirs('  /trimmed  ')
    assert.equal(#exec.libdirs, 1)
    assert.equal(exec.libdirs[1], '/trimmed')

    -- test that throws an error if dirs is not string or table
    local err = assert.throws(exec.set_libdirs, exec, 123)
    assert.match(err, 'flags must be a string or string[]')

    -- test that throws an error if an element of dirs is not string
    err = assert.throws(exec.set_libdirs, exec, {
        '/usr/local/lib',
        123,
    })
    assert.match(err, 'flags#2 must be a string')
end

function testcase.add_libdirs()
    local exec = executor('gcc')

    -- test that add libdirs with a string
    exec:add_libdirs('/usr/local/lib')
    assert.equal(#exec.libdirs, 1)
    assert.equal(exec.libdirs[1], '/usr/local/lib')

    -- test that add libdirs with a string array appends to existing list
    exec:add_libdirs({
        '/opt/lib',
    })
    assert.equal(#exec.libdirs, 2)
    assert.equal(exec.libdirs[1], '/usr/local/lib')
    assert.equal(exec.libdirs[2], '/opt/lib')

    -- test that set_libdirs replaces all dirs including those added via add_libdirs
    exec:set_libdirs({
        '/new/lib',
    })
    assert.equal(#exec.libdirs, 1)
    assert.equal(exec.libdirs[1], '/new/lib')

    -- test that throws an error if dirs is not string or table
    local err = assert.throws(exec.add_libdirs, exec, 123)
    assert.match(err, 'flags must be a string or string[]')

    -- test that throws an error if an element of dirs is not string
    err = assert.throws(exec.add_libdirs, exec, {
        '/usr/local/lib',
        123,
    })
    assert.match(err, 'flags#2 must be a string')
end

function testcase.set_libs()
    local exec = executor('gcc')

    -- test that set libs with a string
    exec:set_libs('z')
    assert.equal(#exec.libs, 1)
    assert.equal(exec.libs[1], 'z')

    -- test that set libs with a string array
    exec:set_libs({
        'z',
        'm',
    })
    assert.equal(#exec.libs, 2)
    assert.equal(exec.libs[1], 'z')
    assert.equal(exec.libs[2], 'm')

    -- test that set_libs replaces the existing list
    exec:set_libs({
        'ssl',
    })
    assert.equal(#exec.libs, 1)
    assert.equal(exec.libs[1], 'ssl')

    -- test that set_libs with empty array clears the list
    exec:set_libs({})
    assert.equal(#exec.libs, 0)

    -- test that empty string and whitespace-only strings are ignored
    exec:set_libs('')
    assert.equal(#exec.libs, 0)
    exec:set_libs({
        'a',
        '',
        '   ',
        'b',
    })
    assert.equal(#exec.libs, 2)
    assert.equal(exec.libs[1], 'a')
    assert.equal(exec.libs[2], 'b')

    -- test that leading/trailing whitespace is trimmed
    exec:set_libs('  crypto  ')
    assert.equal(#exec.libs, 1)
    assert.equal(exec.libs[1], 'crypto')

    -- test that throws an error if libs is not string or table
    local err = assert.throws(exec.set_libs, exec, 123)
    assert.match(err, 'flags must be a string or string[]')

    -- test that throws an error if an element of libs is not string
    err = assert.throws(exec.set_libs, exec, {
        'z',
        123,
    })
    assert.match(err, 'flags#2 must be a string')
end

function testcase.add_libs()
    local exec = executor('gcc')

    -- test that add libs with a string
    exec:add_libs('z')
    assert.equal(#exec.libs, 1)
    assert.equal(exec.libs[1], 'z')

    -- test that add libs with a string array appends to existing list
    exec:add_libs({
        'm',
    })
    assert.equal(#exec.libs, 2)
    assert.equal(exec.libs[1], 'z')
    assert.equal(exec.libs[2], 'm')

    -- test that set_libs replaces all libs including those added via add_libs
    exec:set_libs({
        'ssl',
    })
    assert.equal(#exec.libs, 1)
    assert.equal(exec.libs[1], 'ssl')

    -- test that throws an error if libs is not string or table
    local err = assert.throws(exec.add_libs, exec, 123)
    assert.match(err, 'flags must be a string or string[]')

    -- test that throws an error if an element of libs is not string
    err = assert.throws(exec.add_libs, exec, {
        'z',
        123,
    })
    assert.match(err, 'flags#2 must be a string')
end

function testcase.set_ldflags()
    local exec = executor('gcc')

    -- test that set ldflags with a string
    exec:set_ldflags('-Wl,-rpath,/usr/local/lib')
    assert.equal(#exec.ldflags, 1)
    assert.equal(exec.ldflags[1], '-Wl,-rpath,/usr/local/lib')

    -- test that set ldflags with a string array
    exec:set_ldflags({
        '-Wl,--as-needed',
        '-static',
    })
    assert.equal(#exec.ldflags, 2)
    assert.equal(exec.ldflags[1], '-Wl,--as-needed')
    assert.equal(exec.ldflags[2], '-static')

    -- test that set_ldflags replaces the existing list
    exec:set_ldflags({
        '-Wl,-z,relro',
    })
    assert.equal(#exec.ldflags, 1)
    assert.equal(exec.ldflags[1], '-Wl,-z,relro')

    -- test that set_ldflags with empty array clears the list
    exec:set_ldflags({})
    assert.equal(#exec.ldflags, 0)

    -- test that empty string and whitespace-only strings are ignored
    exec:set_ldflags('')
    assert.equal(#exec.ldflags, 0)
    exec:set_ldflags({
        '-Wl,-a',
        '',
        '   ',
        '-Wl,-b',
    })
    assert.equal(#exec.ldflags, 2)
    assert.equal(exec.ldflags[1], '-Wl,-a')
    assert.equal(exec.ldflags[2], '-Wl,-b')

    -- test that leading/trailing whitespace is trimmed
    exec:set_ldflags('  -static  ')
    assert.equal(#exec.ldflags, 1)
    assert.equal(exec.ldflags[1], '-static')

    -- test that throws an error if flags is not string or table
    local err = assert.throws(exec.set_ldflags, exec, 123)
    assert.match(err, 'flags must be a string or string[]')

    -- test that throws an error if an element of flags is not string
    err = assert.throws(exec.set_ldflags, exec, {
        '-Wl,-rpath,/a',
        123,
    })
    assert.match(err, 'flags#2 must be a string')
end

function testcase.add_ldflags()
    local exec = executor('gcc')

    -- test that add ldflags with a string
    exec:add_ldflags('-Wl,-rpath,/usr/local/lib')
    assert.equal(#exec.ldflags, 1)
    assert.equal(exec.ldflags[1], '-Wl,-rpath,/usr/local/lib')

    -- test that add ldflags with a string array appends to existing list
    exec:add_ldflags({
        '-static',
    })
    assert.equal(#exec.ldflags, 2)
    assert.equal(exec.ldflags[1], '-Wl,-rpath,/usr/local/lib')
    assert.equal(exec.ldflags[2], '-static')

    -- test that set_ldflags replaces all flags including those added via add_ldflags
    exec:set_ldflags({
        '-Wl,-z,relro',
    })
    assert.equal(#exec.ldflags, 1)
    assert.equal(exec.ldflags[1], '-Wl,-z,relro')

    -- test that throws an error if flags is not string or table
    local err = assert.throws(exec.add_ldflags, exec, 123)
    assert.match(err, 'flags must be a string or string[]')

    -- test that throws an error if an element of flags is not string
    err = assert.throws(exec.add_ldflags, exec, {
        '-Wl,-rpath,/a',
        123,
    })
    assert.match(err, 'flags#2 must be a string')
end

function testcase.ldflags_env()
    -- test that LDFLAGS environment variable is read into ldflags on init
    setenv('LDFLAGS', '-Wl,-rpath,/usr/local/lib -static')
    local exec = executor('gcc')
    assert.equal(#exec.ldflags, 2)
    assert.equal(exec.ldflags[1], '-Wl,-rpath,/usr/local/lib')
    assert.equal(exec.ldflags[2], '-static')

    -- test that add_ldflags appends to env-loaded flags
    exec:add_ldflags('-Wl,--as-needed')
    assert.equal(#exec.ldflags, 3)
    assert.equal(exec.ldflags[3], '-Wl,--as-needed')

    -- test that set_ldflags replaces env-loaded flags
    exec:set_ldflags({
        '-Wl,-z,relro',
    })
    assert.equal(#exec.ldflags, 1)
    assert.equal(exec.ldflags[1], '-Wl,-z,relro')
    setenv('LDFLAGS', nil)

    -- test that LDFLAGS environment variable is empty
    setenv('LDFLAGS', '')
    exec = executor('gcc')
    assert.equal(#exec.ldflags, 0)
    setenv('LDFLAGS', nil)
end
