require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local generate = require('configh.generate')

function testcase.generate_validates_cfg()
    -- test that throws error if cfg is not a table
    local err = assert.throws(generate, 'not a table')
    assert.match(err, 'cfg must be a table')

    -- test that throws error if cfg.output is not a string
    err = assert.throws(generate, {})
    assert.match(err, '.output must be a string')

    err = assert.throws(generate, {
        output = 123,
    })
    assert.match(err, '.output must be a string')

    -- test that throws error for unknown keys
    err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        unknown = 1,
    })
    assert.match(err, 'unknown key')

    -- test that label is used in error messages
    err = assert.throws(generate, {
        output = 123,
    }, 'mymodule')
    assert.match(err, 'mymodule.output must be a string')
end

function testcase.generate_validates_structure()
    -- test that throws error if a probe field is not a table
    local err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        features = 'bad',
    })
    assert.match(err, '["features"] must be a table')

    err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        headers = 'bad',
    })
    assert.match(err, '["headers"] must be a table')

    err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        funcs = 'bad',
    })
    assert.match(err, '["funcs"] must be a table')

    err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        types = 'bad',
    })
    assert.match(err, '["types"] must be a table')

    err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        decls = 'bad',
    })
    assert.match(err, '["decls"] must be a table')

    err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        sizeof = 'bad',
    })
    assert.match(err, '["sizeof"] must be a table')

    err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        members = 'bad',
    })
    assert.match(err, '["members"] must be a table')

    -- test that throws error if funcs has non-string key
    err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        funcs = {
            [1] = {
                'printf',
            },
        },
    })
    assert.match(err, '["funcs"] keys must be string')

    -- test that throws error if headers has non-integer key
    err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        headers = {
            foo = 'bar',
        },
    })
    assert.match(err, '["headers"] keys must be integer')

    -- test that throws error if funcs[header] value is not a table
    -- (stdio.h is expected to exist on the test platform)
    err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        funcs = {
            ['stdio.h'] = 'bad',
        },
    })
    assert.match(err, 'must be a table')

    -- test that throws error if members[header] value is not a table
    err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        members = {
            ['stdio.h'] = 'bad',
        },
    })
    assert.match(err, 'must be a table')

    -- test that throws error if members[header][type] value is not a table
    err = assert.throws(generate, {
        cc = 'gcc',
        output = 'x',
        members = {
            ['stdio.h'] = {
                ['FILE'] = 'bad',
            },
        },
    })
    assert.match(err, 'must be a table')
end

function testcase.generate()
    -- test that generate produces config.h with expected macros
    local report, err = generate({
        cc = 'gcc',
        output = './test_config.h',
        features = {
            '_GNU_SOURCE',
            _FILE_OFFSET_BITS = '64',
        },
        headers = {
            'stdio.h',
        },
        funcs = {
            ['stdio.h'] = {
                'printf',
            },
        },
        sizeof = {
            ['stddef.h'] = {
                'size_t',
            },
        },
    })
    assert.not_nil(report)
    assert.is_nil(err)
    local f = assert(io.open('./test_config.h', 'r'))
    os.remove('./test_config.h')
    local content = f:read('*a')
    f:close()
    assert.match(content, '\n#define _GNU_SOURCE\n')
    assert.match(content, '\n#define _FILE_OFFSET_BITS 64\n')
    assert.match(content, '\n#define HAVE_STDIO_H 1\n')
    assert.match(content, '\n#define HAVE_PRINTF 1\n')
    assert.match(content, '#define SIZEOF_SIZE_T ')

    -- test that a missing header causes its child probes to be skipped
    report, err = generate({
        cc = 'gcc',
        output = './test_config.h',
        funcs = {
            ['no_such_header_xyz.h'] = {
                'some_func_xyz',
            },
        },
    })
    assert.not_nil(report)
    assert.is_nil(err)
    f = assert(io.open('./test_config.h', 'r'))
    os.remove('./test_config.h')
    content = f:read('*a')
    f:close()
    assert.match(content, 'HAVE_NO_SUCH_HEADER_XYZ_H')
    assert.is_nil(content:match('HAVE_SOME_FUNC_XYZ'))

    -- test that flush failure returns (nil, err)
    report, err = generate({
        cc = 'gcc',
        output = './nonexistent_dir_xyz/test_config.h',
        headers = {
            'stdio.h',
        },
    })
    assert.is_nil(report)
    assert.match(err, 'No such file or directory')

    -- test that label appears in error messages
    err = assert.throws(generate, {
        output = 'x',
        features = 'bad',
    }, 'build.modules.mymod')
    assert.match(err, 'build.modules.mymod["features"] must be a table')
end

function testcase.generate_with_stdout()
    -- test that stdout argument is forwarded to cfgh:set_stdout()
    local tmpfile = os.tmpname()
    local f = assert(io.open(tmpfile, 'w'))
    local report, err = generate({
        cc = 'gcc',
        output = './test_config.h',
        output_status = true,
        headers = {
            'stdio.h',
        },
    }, nil, f)
    f:close()
    os.remove('./test_config.h')
    assert.not_nil(report)
    assert.is_nil(err)
    local rf = assert(io.open(tmpfile, 'r'))
    local content = rf:read('*a')
    rf:close()
    os.remove(tmpfile)
    assert.match(content, 'stdio.h')

    -- test that an invalid stdout type raises error
    err = assert.throws(generate, {
        cc = 'gcc',
        output = './test_config.h',
    }, nil, 'not a file')
    assert.match(err, 'outfile must be file or nil')
end

function testcase.generate_report()
    -- test that report has header entries with is_exists
    local report, err = generate({
        cc = 'gcc',
        output = './test_config.h',
        headers = {
            'stdio.h',
        },
        funcs = {
            ['stdio.h'] = {
                'printf',
            },
        },
        types = {
            ['sys/types.h'] = {
                'pid_t',
            },
        },
        decls = {
            ['unistd.h'] = {
                'STDIN_FILENO',
            },
        },
        sizeof = {
            ['stddef.h'] = {
                'size_t',
            },
        },
        members = {
            ['stdio.h'] = {
                FILE = {
                    '_flags',
                },
            },
        },
    })
    os.remove('./test_config.h')
    assert.not_nil(report)
    assert.is_nil(err)

    -- header in headers[] has is_exists entry
    assert.is_true(report['stdio.h'].is_exists)

    -- funcs child entry under its header
    assert.is_true(report['stdio.h']['printf'])

    -- types child entry
    assert.not_nil(report['sys/types.h'])
    assert.is_true(report['sys/types.h'].is_exists)
    assert.is_true(report['sys/types.h']['pid_t'])

    -- decls child entry
    assert.not_nil(report['unistd.h'])
    assert.is_true(report['unistd.h'].is_exists)
    assert.is_true(report['unistd.h']['STDIN_FILENO'])

    -- sizeof child entry
    assert.not_nil(report['stddef.h'])
    assert.is_true(report['stddef.h'].is_exists)
    -- sizeof child entry is the byte size (integer), not a boolean
    assert.is_true(type(report['stddef.h']['size_t']) == 'number')
    assert.is_true(report['stddef.h']['size_t'] > 0)

    -- members child entry uses "type.member" key
    assert.is_true(report['stdio.h']['FILE._flags'])

    -- test that missing header has is_exists=false and no child entries
    report, err = generate({
        cc = 'gcc',
        output = './test_config.h',
        funcs = {
            ['no_such_header_xyz.h'] = {
                'some_func_xyz',
            },
        },
    })
    os.remove('./test_config.h')
    assert.not_nil(report)
    assert.is_nil(err)
    assert.is_false(report['no_such_header_xyz.h'].is_exists)
    assert.is_nil(report['no_such_header_xyz.h']['some_func_xyz'])

    -- test that a header appearing in both headers[] and funcs{} gets one entry
    report = generate({
        cc = 'gcc',
        output = './test_config.h',
        headers = {
            'stdio.h',
        },
        funcs = {
            ['stdio.h'] = {
                'printf',
            },
        },
    })
    os.remove('./test_config.h')
    assert.not_nil(report)
    -- count keys in report['stdio.h']: is_exists + printf only (no duplicate)
    local count = 0
    for _ in pairs(report['stdio.h']) do
        count = count + 1
    end
    -- is_exists + printf = 2
    assert.equal(count, 2)
end
