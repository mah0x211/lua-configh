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
    -- confirm that the entry is recorded in inspected
    assert.equal(cfgh.inspected.headers['stdio.h'].is_exists, true)
    assert.equal(cfgh.inspected.headers['stdio.h'].target, 'headers')
    -- integer key and target hash key refer to the same entry
    assert.equal(cfgh.inspected[1], cfgh.inspected.headers['stdio.h'])

    -- test that not-found header is recorded in inspected
    ok, err = cfgh:check_header('this_is_unknown_header_for_test.h')
    assert.is_false(ok)
    assert.is_string(err)
    assert.equal(cfgh.inspected.headers['this_is_unknown_header_for_test.h']
                     .is_exists, false)
end

function testcase.check_func()
    local cfgh = configh('gcc')
    assert(cfgh:check_header('stdio.h'))

    -- test that check whether the function is available
    local ok, err = cfgh:check_func('stdio.h', 'printf')
    assert(ok, err)
    -- confirm that the entry is recorded in inspected.funcs keyed by fqname
    assert.equal(cfgh.inspected.funcs['printf'].is_exists, true)

    -- test that probe without header includes returns false
    ok, err = cfgh:check_func(nil, 'printf')
    assert.is_false(ok)
    assert.is_string(err)
end

function testcase.check_type()
    local cfgh = configh('gcc')
    assert(cfgh:check_header('sys/socket.h'))

    -- test that check whether the type is available
    local ok, err = cfgh:check_type('sys/socket.h', 'struct sockaddr_storage')
    assert(ok, err)
    -- confirm that the entry is recorded in inspected.types keyed by fqname
    assert.equal(cfgh.inspected.types['struct sockaddr_storage'].is_exists, true)

    -- test that probe without header includes returns false
    ok, err = cfgh:check_type(nil, 'struct sockaddr_storage')
    assert.is_false(ok)
    assert.is_string(err)
end

function testcase.check_member()
    local cfgh = configh('gcc')
    assert(cfgh:check_header('sys/socket.h'))

    -- test that check whether the member is available
    local ok, err = cfgh:check_member('sys/socket.h', 'struct sockaddr',
                                      'sa_family')
    assert(ok, err)
    -- confirm that the entry is recorded in inspected.members keyed by fqname
    assert.equal(cfgh.inspected.members['struct sockaddr.sa_family'].is_exists,
                 true)

    -- test that member probe for unknown member returns false
    ok, err = cfgh:check_member('sys/socket.h', 'struct sockaddr',
                                'unknown_member')
    assert.is_false(ok)
    assert.is_string(err)
    assert.equal(cfgh.inspected.members['struct sockaddr.unknown_member']
                     .is_exists, false)
end

function testcase.check_decl()
    local cfgh = configh('gcc')
    assert(cfgh:check_header('limits.h'))

    -- test that check whether the macro constant is defined
    local ok, err = cfgh:check_decl('limits.h', 'PATH_MAX')
    assert(ok, err)
    -- confirm that the entry is recorded in inspected.decls keyed by fqname
    assert.equal(cfgh.inspected.decls['PATH_MAX'].is_exists, true)

    -- test that add commented macro if the declaration is not available
    ok, err = cfgh:check_decl('limits.h', 'UNKNOWN_CONSTANT')
    assert.is_false(ok)
    assert.is_string(err)
    assert.equal(cfgh.inspected.decls['UNKNOWN_CONSTANT'].is_exists, false)
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

function testcase.set_cppflags()
    local cfgh = configh('gcc')

    -- test that set cppflags with a string
    cfgh:set_cppflags('-I/usr/local/include')
    assert.equal(#cfgh.exec.cppflags, 1)
    assert.equal(cfgh.exec.cppflags[1], '-I/usr/local/include')

    -- test that set cppflags with a string array
    cfgh:set_cppflags({
        '-I/usr/local/include',
        '-I/opt/include',
        '-DDEBUG',
    })
    assert.equal(#cfgh.exec.cppflags, 3)

    -- test that set_cppflags replaces the list
    cfgh:set_cppflags({
        '-I/new/path',
    })
    assert.equal(#cfgh.exec.cppflags, 1)
    assert.equal(cfgh.exec.cppflags[1], '-I/new/path')
end

function testcase.add_cppflags()
    local cfgh = configh('gcc')

    -- test that add_cppflags appends to the existing list
    cfgh:add_cppflags('-I/usr/local/include')
    assert.equal(#cfgh.exec.cppflags, 1)
    cfgh:add_cppflags({
        '-I/opt/include',
        '-DDEBUG',
    })
    assert.equal(#cfgh.exec.cppflags, 3)
    assert.equal(cfgh.exec.cppflags[1], '-I/usr/local/include')
    assert.equal(cfgh.exec.cppflags[2], '-I/opt/include')
    assert.equal(cfgh.exec.cppflags[3], '-DDEBUG')
end

function testcase.set_incdirs()
    local cfgh = configh('gcc')

    -- test that set incdirs with a string
    cfgh:set_incdirs('/usr/local/include')
    assert.equal(#cfgh.exec.incdirs, 1)
    assert.equal(cfgh.exec.incdirs[1], '/usr/local/include')

    -- test that set incdirs with a string array
    cfgh:set_incdirs({
        '/usr/local/include',
        '/opt/include',
    })
    assert.equal(#cfgh.exec.incdirs, 2)

    -- test that set_incdirs replaces the list
    cfgh:set_incdirs({
        '/new/path',
    })
    assert.equal(#cfgh.exec.incdirs, 1)
    assert.equal(cfgh.exec.incdirs[1], '/new/path')
end

function testcase.add_incdirs()
    local cfgh = configh('gcc')

    -- test that add_incdirs appends to the existing list
    cfgh:add_incdirs('/usr/local/include')
    assert.equal(#cfgh.exec.incdirs, 1)
    cfgh:add_incdirs({
        '/opt/include',
    })
    assert.equal(#cfgh.exec.incdirs, 2)
    assert.equal(cfgh.exec.incdirs[1], '/usr/local/include')
    assert.equal(cfgh.exec.incdirs[2], '/opt/include')
end

function testcase.set_cflags()
    local cfgh = configh('gcc')

    -- test that set cflags with a string
    cfgh:set_cflags('-O2')
    assert.equal(#cfgh.exec.cflags, 1)
    assert.equal(cfgh.exec.cflags[1], '-O2')

    -- test that set cflags with a string array
    cfgh:set_cflags({
        '-O2',
        '-Wall',
    })
    assert.equal(#cfgh.exec.cflags, 2)

    -- test that set_cflags replaces the list
    cfgh:set_cflags({
        '-O0',
    })
    assert.equal(#cfgh.exec.cflags, 1)
    assert.equal(cfgh.exec.cflags[1], '-O0')
end

function testcase.add_cflags()
    local cfgh = configh('gcc')

    -- test that add_cflags appends to the existing list
    cfgh:add_cflags('-O2')
    assert.equal(#cfgh.exec.cflags, 1)
    cfgh:add_cflags({
        '-Wall',
    })
    assert.equal(#cfgh.exec.cflags, 2)
    assert.equal(cfgh.exec.cflags[1], '-O2')
    assert.equal(cfgh.exec.cflags[2], '-Wall')
end

function testcase.set_libdirs()
    local cfgh = configh('gcc')

    cfgh:set_libdirs('/usr/local/lib')
    assert.equal(#cfgh.exec.libdirs, 1)
    assert.equal(cfgh.exec.libdirs[1], '/usr/local/lib')

    cfgh:set_libdirs({
        '/usr/local/lib',
        '/opt/lib',
    })
    assert.equal(#cfgh.exec.libdirs, 2)

    cfgh:set_libdirs({
        '/new/lib',
    })
    assert.equal(#cfgh.exec.libdirs, 1)
    assert.equal(cfgh.exec.libdirs[1], '/new/lib')
end

function testcase.add_libdirs()
    local cfgh = configh('gcc')

    cfgh:add_libdirs('/usr/local/lib')
    assert.equal(#cfgh.exec.libdirs, 1)
    cfgh:add_libdirs({
        '/opt/lib',
    })
    assert.equal(#cfgh.exec.libdirs, 2)
    assert.equal(cfgh.exec.libdirs[1], '/usr/local/lib')
    assert.equal(cfgh.exec.libdirs[2], '/opt/lib')
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

function testcase.inspected_mixed_table()
    local cfgh = configh('gcc')
    assert(cfgh:check_header('stdio.h'))
    assert(cfgh:check_func('stdio.h', 'printf'))

    -- integer key and target hash key share the same entry reference
    local h = cfgh.inspected.headers['stdio.h']
    assert.equal(h, cfgh.inspected[1])
    assert.equal(h.target, 'headers')
    assert.equal(h.declname, 'stdio.h')
    assert.equal(h.order, 1)

    local f = cfgh.inspected.funcs['printf']
    assert.equal(f, cfgh.inspected[2])
    assert.equal(f.target, 'funcs')
    assert.equal(f.declname, 'printf')
    assert.equal(f.order, 2)
end

function testcase.check_header_dedup()
    local cfgh = configh('gcc')
    cfgh:check_header('stdio.h')
    cfgh:check_header('stdio.h') -- re-probes and updates existing entry; no new integer entry
    assert.equal(#cfgh.inspected, 1)

    -- check_func dedup: same fqname re-probes but adds no new integer entry
    cfgh:check_func('stdio.h', 'printf')
    cfgh:check_func('stdio.h', 'printf') -- re-probe, no new entry
    assert.equal(#cfgh.inspected, 2)
end

