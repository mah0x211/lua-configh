require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local setenv = require('setenv')
local configh = require('configh')

function testcase.new_configh()
    -- test that create a new Configh object with compiler name
    local cfgh = configh('gcc')
    assert.match(cfgh, '^configh: ', false)

    -- test that create a new Configh object with CC environment variable
    setenv('CC', 'gcc')
    cfgh = configh('gcc')
    assert.match(cfgh, '^configh: ', false)
    setenv('CC', nil)

    -- test that throws an error if cc is not string
    local err = assert.throws(configh, 123)
    assert.match(err, 'cc must be string or nil')

    -- test that throws an error if cc and CC environment variable are not set
    err = assert.throws(configh)
    assert.match(err,
                 'cc argument or CC environment variable must contain compiler name')
end

function testcase.set_and_unset_featrue()
    local cfgh = configh('gcc')

    -- test that set feature macro to use in c source file
    cfgh:set_feature('_GNU_SOURCE')
    local pathname = cfgh.exec:makecsrc()
    local f = assert(io.open(pathname, 'r'))
    os.remove(pathname)
    local src = f:read('*a')
    f:close()
    assert.re_match(src, '^#define _GNU_SOURCE', 'm')

    -- test that replace new feature macro
    cfgh:set_feature('_GNU_SOURCE', '123')
    pathname = cfgh.exec:makecsrc()
    f = assert(io.open(pathname, 'r'))
    os.remove(pathname)
    src = f:read('*a')
    f:close()
    assert.re_match(src, '^#define _GNU_SOURCE 123', 'm')

    -- test that remove feature macro
    cfgh:unset_feature('_GNU_SOURCE')
    pathname = cfgh.exec:makecsrc()
    f = assert(io.open(pathname, 'r'))
    os.remove(pathname)
    src = f:read('*a')
    f:close()
    assert.not_re_match(src, '^#define _GNU_SOURCE', 'm')
end

function testcase.check_header()
    local cfgh = configh('gcc')

    -- test that check whether the header is available
    local ok, err = cfgh:check_header('stdio.h')
    assert(ok, err)
    -- confirm that the macro is defined in macro list
    assert.re_match(table.concat(cfgh.macros), '^#define HAVE_STDIO_H 1', 'm')

    -- test that add commented macro if the header is not available
    ok, err = cfgh:check_header('this_is_unknown_header_for_test.h')
    assert.is_false(ok)
    assert.is_string(err)
    assert.re_match(table.concat(cfgh.macros, '\n'),
                    '^/\\* #undef HAVE_THIS_IS_UNKNOWN_HEADER_FOR_TEST_H \\*/',
                    'm')
end

function testcase.check_func()
    local cfgh = configh('gcc')

    -- test that check whether the function is available
    local ok, err = cfgh:check_func('stdio.h', 'printf')
    assert(ok, err)
    -- confirm that the macro is defined in macro list
    assert.re_match(table.concat(cfgh.macros, '\n'), '^#define HAVE_PRINTF 1',
                    'm')

    -- test that add commented macro if the function is not available
    ok, err = cfgh:check_func(nil, 'printf')
    assert.is_false(ok)
    assert.is_string(err)
    assert.re_match(table.concat(cfgh.macros, '\n'),
                    '^/\\* #undef HAVE_PRINTF \\*/', 'm')
end

function testcase.check_type()
    local cfgh = configh('gcc')

    -- test that check whether the type is available
    local ok, err = cfgh:check_type('sys/socket.h', 'struct sockaddr_storage')
    assert(ok, err)
    -- confirm that the macro is defined in macro list
    assert.re_match(table.concat(cfgh.macros, '\n'),
                    '^#define HAVE_STRUCT_SOCKADDR_STORAGE 1', 'm')

    -- test that add commented macro if the type is not available
    ok, err = cfgh:check_type(nil, 'struct sockaddr_storage')
    assert.is_false(ok)
    assert.is_string(err)
    assert.re_match(table.concat(cfgh.macros, '\n'),
                    '^/\\* #undef HAVE_STRUCT_SOCKADDR_STORAGE \\*/', 'm')
end

function testcase.check_member()
    local cfgh = configh('gcc')

    -- test that check whether the member is available
    local ok, err = cfgh:check_member('sys/socket.h', 'struct sockaddr',
                                      'sa_family')
    assert(ok, err)
    -- confirm that the macro is defined in macro list
    assert.re_match(table.concat(cfgh.macros, '\n'),
                    '^#define HAVE_STRUCT_SOCKADDR_SA_FAMILY 1', 'm')

    -- test that add commented macro if the member is not available
    ok, err = cfgh:check_member('sys/socket.h', 'struct sockaddr',
                                'unknown_member')
    assert.is_false(ok)
    assert.is_string(err)
    assert.re_match(table.concat(cfgh.macros, '\n'),
                    '^/\\* #undef HAVE_STRUCT_SOCKADDR_UNKNOWN_MEMBER \\*/', 'm')
end

function testcase.check_decl()
    local cfgh = configh('gcc')

    -- test that check whether the macro constant is defined
    local ok, err = cfgh:check_decl('limits.h', 'PATH_MAX')
    assert(ok, err)
    -- confirm that the macro is defined in macro list
    assert.re_match(table.concat(cfgh.macros, '\n'), '^#define HAVE_PATH_MAX 1',
                    'm')

    -- test that add commented macro if the declaration is not available
    ok, err = cfgh:check_decl('limits.h', 'UNKNOWN_CONSTANT')
    assert.is_false(ok)
    assert.is_string(err)

    assert.re_match(table.concat(cfgh.macros, '\n'),
                    '^/\\* #undef HAVE_UNKNOWN_CONSTANT \\*/', 'm')
end

function testcase.output_status()
    local cfgh = configh('gcc')
    local stdout = assert(io.tmpfile())
    stdout:setvbuf('no')
    cfgh:set_stdout(stdout)

    -- test that enable output status
    cfgh:output_status(true)
    cfgh:check_header('stdio.h')
    stdout:seek('set')
    assert.match(stdout:read('*a'), 'check header: stdio.h ... found')
end

function testcase.add_and_remove_cppflag()
    local cfgh = configh('gcc')

    -- test that add cppflag
    cfgh:add_cppflag('-I/usr/local/include')
    assert.is_uint(cfgh.exec.cppflags['-I/usr/local/include'])
    assert.equal(cfgh.exec.cppflags[cfgh.exec.cppflags['-I/usr/local/include']],
                 '-I/usr/local/include')

    -- test that add multiple cppflags
    cfgh:add_cppflag('-I/opt/include')
    cfgh:add_cppflag('-DDEBUG')
    assert.equal(#cfgh.exec.cppflags, 3)

    -- test that remove cppflag
    cfgh:remove_cppflag('-I/usr/local/include')
    assert.is_nil(cfgh.exec.cppflags['-I/usr/local/include'])
    assert.equal(#cfgh.exec.cppflags, 2)
end

function testcase.flush()
    local cfgh = configh('gcc')
    cfgh:set_feature('_GNU_SOURCE')
    assert(cfgh:check_header('stdio.h'))
    assert(cfgh:check_func('stdio.h', 'printf'))

    -- test that check whether the function is available
    local ok, err = cfgh:flush('./test_config.h')
    assert.is_true(ok)
    assert.is_nil(err)
    -- confirm
    local f = assert(io.open('./test_config.h', 'r'))
    os.remove('./test_config.h')
    local content = f:read('*a')
    f:close()
    for _, pattern in ipairs({
        '\n#define _GNU_SOURCE\n',
        '\n#define HAVE_STDIO_H 1\n',
        '\n#define HAVE_PRINTF 1\n',
    }) do
        assert.match(content, pattern)
        assert.match(content, pattern)
    end

    -- test that return an error if failed to open the file pointed by pathname
    ok, err = cfgh:flush('./foo/bar/baz/test_config.h')
    assert.is_false(ok)
    assert.match(err, 'No such file or directory')

    -- test that throws an error if a pathname is nil
    err = assert.throws(cfgh.flush, cfgh)
    assert.match(err, 'pathname must be string')
end

