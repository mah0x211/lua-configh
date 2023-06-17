require('luacov')
local testcase = require('testcase')
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

function testcase.flush()
    local cfgh = configh('gcc')
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

