require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local dump = require('dump')
local command = require('configh.command')

local osexit = os.exit
local FILES_TO_CLEANUP = {}

function testcase.after_each()
    -- cleanup created files
    for filename in pairs(FILES_TO_CLEANUP) do
        os.remove(filename)
    end
    FILES_TO_CLEANUP = {}
    -- restore os.exit
    os.exit = osexit -- luacheck: ignore
end

local function create_test_config_file(filename, content)
    assert(type(filename) == 'string', 'filename must be string')
    assert(type(content) == 'string' or type(content) == 'table',
           'content must be string or table')

    local f = assert(io.open(filename, 'w'))
    if not FILES_TO_CLEANUP[filename] then
        FILES_TO_CLEANUP[filename] = true
    end

    if type(content) == 'table' then
        content = 'return ' .. dump(content)
    end
    f:write(content)
    f:close()
end

local function read_header_file(filename)
    local f = assert(io.open(filename, 'r'), filename .. ' should exist')
    if not FILES_TO_CLEANUP[filename] then
        FILES_TO_CLEANUP[filename] = true
    end
    return f:read('*a')
end

local function load_configh_output(...)
    local f = assert(io.tmpfile())
    os.exit = function() -- luacheck: ignore
        error('')
    end
    local ok, err = pcall(command, {
        ...,
    }, f, f)
    os.exit = osexit -- luacheck: ignore
    if not ok then
        -- ignore errors from configh command
        f:write(err)
    end
    f:seek('set')
    local output = f:read('*a')
    f:close()
    return output
end

function testcase.no_args()
    -- test that configh prints usage when no arguments
    local output = load_configh_output()

    assert.match(output, 'Usage: configh')
    assert.match(output, '<config.lua>')
    assert.match(output, '--out=<filename>')
end

function testcase.out_only()
    -- test that configh prints error when only --out is provided
    local output = load_configh_output('--out=config.h')
    assert.match(output, 'Error: no config file specified')
end

function testcase.nonexistent_config()
    -- test that configh prints error when config file doesn't exist
    local output = load_configh_output('nonexistent.lua')
    assert.match(output, 'Error: failed to load config file')
    assert.match(output, 'nonexistent.lua')
end

function testcase.invalid_config()
    -- test that configh prints error when config file has syntax error
    local output = load_configh_output('test_invalid_config.lua')
    assert.match(output, 'Error: failed to load config file')
end

function testcase.valid_config()
    -- test that configh creates config.h with empty config
    create_test_config_file('tmp_valid_config.lua', {
        cc = 'cc', -- need a compiler to avoid error
    })
    local output = load_configh_output('tmp_valid_config.lua',
                                       '--out=tmp_output.h')

    -- should have no output on success
    assert(#output == 0, 'should have no output on success')

    -- check output file contains header comment
    local content = read_header_file('tmp_output.h')
    assert.match(content, 'lua-configh module')
    assert.match(content, '/**')
end

function testcase.invalid_members_format()
    -- test that configh reports error for invalid members format
    -- members must be table<string, table<string, string[]>>
    create_test_config_file('tmp_invalid_members.lua', {
        members = {
            sys = {
                sock = {
                    123,
                }, -- number is an error
            },
        },
    })
    local output = load_configh_output('tmp_invalid_members.lua')
    assert.match(output, 'members.sys.sock#1 must be a string, got "number"')
end

function testcase.unknown_option()
    -- test that configh reports error for unknown option
    create_test_config_file('tmp_unknown_opt_config.lua', {
        cc = 'cc',
    })
    local output = load_configh_output('tmp_unknown_opt_config.lua',
                                       '--unknown=value')
    assert.match(output, 'Error: unknown option')
end

function testcase.multiple_config_files()
    -- test that multiple config files results in error
    create_test_config_file('tmp_multi_out_config.lua', {
        cc = 'cc',
    })
    local output = load_configh_output('tmp_multi_out_config.lua', 'extra.lua')
    assert.match(output, 'Error: multiple config files specified')
end

function testcase.multiple_out_args()
    -- test that multiple --out args results in error
    create_test_config_file('tmp_multi_out_config.lua', {
        cc = 'cc',
    })
    local output = load_configh_output('--out=first.h', '--out=second.h',
                                       'tmp_multi_out_config.lua')
    assert.match(output, 'Error: multiple "--out" options specified')
end

function testcase.invalid_cc_type()
    -- test that cc must be a string or nil
    create_test_config_file('tmp_invalid_cc.lua', {
        -- number is an error
        cc = 123,
    })
    local output = load_configh_output('tmp_invalid_cc.lua')
    assert.match(output, 'cc must be a string or nil')
end

function testcase.invalid_output_status_type()
    -- test that output_status must be a boolean or nil
    create_test_config_file('tmp_invalid_output_status.lua', {
        cc = 'cc',
        -- string is an error
        output_status = 'yes',
    })
    local output = load_configh_output('tmp_invalid_output_status.lua')
    assert.match(output, 'output_status must be a boolean or nil')
end

function testcase.invalid_features_type()
    -- test that features must be a string[]|table<string, string|number> or nil
    create_test_config_file('tmp_invalid_features.lua', {
        cc = 'cc',
        -- string is an error, table required
        features = 'HAVE_FEATURE=1',
    })
    local output = load_configh_output('tmp_invalid_features.lua')
    assert.match(output, 'string[]|table<string, string|number>')
end

function testcase.invalid_features_element_type()
    -- test that features array elements must be strings
    create_test_config_file('tmp_invalid_features_elem.lua', {
        cc = 'cc',
        features = {
            -- number is an error
            123,
        },
    })
    local output = load_configh_output('tmp_invalid_features_elem.lua')
    assert.match(output, 'value must be a string, got')
end

function testcase.invalid_features_value_type()
    -- test that features key-value values must be string or number
    create_test_config_file('tmp_invalid_features_val.lua', {
        cc = 'cc',
        features = {
            -- table is an error for value
            name = {},
        },
    })
    local output = load_configh_output('tmp_invalid_features_val.lua')
    assert.match(output, 'value must be a string or number, got')
end

function testcase.invalid_cppflags_type()
    -- test that cppflags must be a string[] or nil
    create_test_config_file('tmp_invalid_cppflags.lua', {
        cc = 'cc',
        -- string is an error, array required
        cppflags = '-Wall',
    })
    local output = load_configh_output('tmp_invalid_cppflags.lua')
    assert.match(output, 'cppflags must be a string[] or nil')
end

function testcase.invalid_headers_type()
    -- test that headers must be a string[] or nil
    create_test_config_file('tmp_invalid_headers.lua', {
        cc = 'cc',
        -- string is an error, array required
        headers = 'stdio.h',
    })
    local output = load_configh_output('tmp_invalid_headers.lua')
    assert.match(output, 'headers must be a string[] or nil')
end

function testcase.invalid_funcs_type()
    -- test that funcs must be table<string, string[]> or nil
    create_test_config_file('tmp_invalid_funcs.lua', {
        cc = 'cc',
        -- array is an error, table required
        funcs = {
            'printf',
        },
    })
    local output = load_configh_output('tmp_invalid_funcs.lua')
    assert.match(output, 'funcs must be a table<string, string[]>')
end

function testcase.invalid_types_type()
    -- test that types must be table<string, string[]> or nil
    create_test_config_file('tmp_invalid_types.lua', {
        cc = 'cc',
        -- array is an error, table required
        types = {
            'pid_t',
        },
    })
    local output = load_configh_output('tmp_invalid_types.lua')
    assert.match(output, 'types must be a table<string, string[]>')
end

function testcase.invalid_decls_type()
    -- test that decls must be table<string, string[]> or nil
    create_test_config_file('tmp_invalid_decls.lua', {
        cc = 'cc',
        -- array is an error, table required
        decls = {
            'errno',
        },
    })
    local output = load_configh_output('tmp_invalid_decls.lua')
    assert.match(output, 'decls must be a table<string, string[]>')
end

function testcase.invalid_members_type()
    -- test that members must be table<string, table<string, string[]>> or nil
    create_test_config_file('tmp_invalid_members.lua', {
        cc = 'cc',
        -- array is an error, nested table required
        members = {
            'sa_family',
        },
    })
    local output = load_configh_output('tmp_invalid_members.lua')
    assert.match(output,
                 'members must be a table<string, table<string, string[]>>')
end

function testcase.with_features()
    -- test that configh sets feature macros
    create_test_config_file('tmp_features.lua', {
        cc = 'cc',
        features = {
            'ENABLE_FEATURE_X', -- array part (no value)
            HAVE_CONFIG_H = 1, -- key-value part (numeric value)
            str_value = '1', -- key-value part (string value)
            quoted_value = '"foo"', -- key-value part (quoted string)
        },
    })
    local output = load_configh_output('tmp_features.lua',
                                       '--out=tmp_features.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file contains feature macros
    local content = read_header_file('tmp_features.h')
    assert.match(content, '#define ENABLE_FEATURE_X')
    assert.match(content, '#define HAVE_CONFIG_H 1')
    assert.match(content, '#define str_value 1')
    assert.match(content, '#define quoted_value "foo"')
end

function testcase.with_output_status()
    -- test that output_status=true shows check progress
    create_test_config_file('tmp_output_status.lua', {
        cc = 'cc',
        output_status = true,
        headers = {
            'stdio.h',
        },
    })
    local output = load_configh_output('tmp_output_status.lua',
                                       '--out=tmp_output_status.h')

    -- should show check progress
    assert.match(output, 'check header: stdio.h')
    assert.match(output, 'found')
end

function testcase.with_cppflags()
    -- test that cppflags are added to compilation
    create_test_config_file('tmp_cppflags.lua', {
        cc = 'cc',
        cppflags = {
            '-DTEST_MACRO',
            '-DANOTHER=value',
        },
        headers = {
            'stdio.h',
        },
    })
    local output = load_configh_output('tmp_cppflags.lua',
                                       '--out=tmp_cppflags.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file is created
    read_header_file('tmp_cppflags.h')
end

function testcase.with_headers()
    -- test that headers are checked and macros are defined
    create_test_config_file('tmp_headers.lua', {
        cc = 'cc',
        headers = {
            'stdio.h',
            'stdlib.h',
        },
    })
    local output = load_configh_output('tmp_headers.lua', '--out=tmp_headers.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file contains header macros
    local content = read_header_file('tmp_headers.h')
    assert.match(content, 'HAVE_STDIO_H')
    assert.match(content, 'HAVE_STDLIB_H')
end

function testcase.with_funcs()
    -- test that funcs are checked and macros are defined
    create_test_config_file('tmp_funcs.lua', {
        cc = 'cc',
        funcs = {
            ['stdio.h'] = {
                'printf',
                'fprintf',
            },
        },
    })
    local output = load_configh_output('tmp_funcs.lua', '--out=tmp_funcs.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file contains func macros
    local content = read_header_file('tmp_funcs.h')
    assert.match(content, 'HAVE_PRINTF')
    assert.match(content, 'HAVE_FPRINTF')
end

function testcase.with_types()
    -- test that types are checked and macros are defined
    create_test_config_file('tmp_types.lua', {
        cc = 'cc',
        types = {
            ['stdio.h'] = {
                'FILE',
            },
        },
    })
    local output = load_configh_output('tmp_types.lua', '--out=tmp_types.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file contains type macros
    local content = read_header_file('tmp_types.h')
    assert.match(content, 'HAVE_FILE')
end

function testcase.with_decls()
    -- test that decls are checked and macros are defined
    create_test_config_file('tmp_decls.lua', {
        cc = 'cc',
        decls = {
            ['errno.h'] = {
                'errno',
            },
        },
    })
    local output = load_configh_output('tmp_decls.lua', '--out=tmp_decls.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file contains decl macros
    local content = read_header_file('tmp_decls.h')
    assert.match(content, 'HAVE_ERRNO')
end

function testcase.with_members()
    -- test that members are checked and macros are defined
    create_test_config_file('tmp_members.lua', {
        cc = 'cc',
        members = {
            ['stdio.h'] = {
                FILE = {
                    '_flags',
                },
            },
        },
    })
    local output = load_configh_output('tmp_members.lua',
                                       '--out=tmp_members_check.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file contains member macros
    local content = read_header_file('tmp_members_check.h')
    assert.match(content, 'HAVE_FILE__FLAGS')
end

function testcase.with_empty_features()
    -- test that empty features table works
    create_test_config_file('tmp_empty_features.lua', {
        cc = 'cc',
        features = {},
    })
    local output = load_configh_output('tmp_empty_features.lua',
                                       '--out=tmp_empty_features.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file is created
    read_header_file('tmp_empty_features.h')
end

function testcase.with_empty_funcs()
    -- test that empty funcs table works
    create_test_config_file('tmp_empty_funcs.lua', {
        cc = 'cc',
        funcs = {},
    })
    local output = load_configh_output('tmp_empty_funcs.lua',
                                       '--out=tmp_empty_funcs.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file is created
    read_header_file('tmp_empty_funcs.h')
end

function testcase.with_empty_types()
    -- test that empty types table works
    create_test_config_file('tmp_empty_types.lua', {
        cc = 'cc',
        types = {},
    })
    local output = load_configh_output('tmp_empty_types.lua',
                                       '--out=tmp_empty_types.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file is created
    read_header_file('tmp_empty_types.h')
end

function testcase.with_empty_decls()
    -- test that empty decls table works
    create_test_config_file('tmp_empty_decls.lua', {
        cc = 'cc',
        decls = {},
    })
    local output = load_configh_output('tmp_empty_decls.lua',
                                       '--out=tmp_empty_decls.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file is created
    read_header_file('tmp_empty_decls.h')
end

function testcase.with_empty_members()
    -- test that empty members table works
    create_test_config_file('tmp_empty_members.lua', {
        cc = 'cc',
        members = {},
    })
    local output = load_configh_output('tmp_empty_members.lua',
                                       '--out=tmp_empty_members.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file is created
    read_header_file('tmp_empty_members.h')
end

function testcase.with_nonexistent_header()
    -- test that nonexistent header results in #undef
    create_test_config_file('tmp_nonexistent_header.lua', {
        cc = 'cc',
        headers = {
            'nonexistent_header_12345.h',
        },
    })
    local output = load_configh_output('tmp_nonexistent_header.lua',
                                       '--out=tmp_nonexistent.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file contains #undef
    local content = read_header_file('tmp_nonexistent.h')
    assert.match(content, '/* #undef HAVE_NONEXISTENT_HEADER_12345_H */')
end

function testcase.with_funcs_for_nonexistent_header()
    -- test that funcs for nonexistent header are skipped
    create_test_config_file('tmp_funcs_nonexist.lua', {
        cc = 'cc',
        funcs = {
            ['nonexistent.h'] = {
                'some_func',
            },
        },
    })
    local output = load_configh_output('tmp_funcs_nonexist.lua',
                                       '--out=tmp_funcs_nonexist.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- header check should result in #undef
    local content = read_header_file('tmp_funcs_nonexist.h')
    assert.match(content, '/* #undef HAVE_NONEXISTENT_H */')
    -- func should not be defined since header doesn't exist
    assert.not_match(content, 'HAVE_SOME_FUNC')
end

function testcase.with_types_for_nonexistent_header()
    -- test that types for nonexistent header are skipped
    create_test_config_file('tmp_types_nonexist.lua', {
        cc = 'cc',
        types = {
            ['nonexistent.h'] = {
                'some_type',
            },
        },
    })
    local output = load_configh_output('tmp_types_nonexist.lua',
                                       '--out=tmp_types_nonexist.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- header check should result in #undef
    local content = read_header_file('tmp_types_nonexist.h')
    assert.match(content, '/* #undef HAVE_NONEXISTENT_H */')
    -- type should not be defined since header doesn't exist
    assert.not_match(content, 'HAVE_SOME_TYPE')
end

function testcase.with_decls_for_nonexistent_header()
    -- test that decls for nonexistent header are skipped
    create_test_config_file('tmp_decls_nonexist.lua', {
        cc = 'cc',
        decls = {
            ['nonexistent.h'] = {
                'some_decl',
            },
        },
    })
    local output = load_configh_output('tmp_decls_nonexist.lua',
                                       '--out=tmp_decls_nonexist.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- header check should result in #undef
    local content = read_header_file('tmp_decls_nonexist.h')
    assert.match(content, '/* #undef HAVE_NONEXISTENT_H */')
    -- decl should not be defined since header doesn't exist
    assert.not_match(content, 'HAVE_SOME_DECL')
end

function testcase.with_members_for_nonexistent_header()
    -- test that members for nonexistent header are skipped
    create_test_config_file('tmp_members_nonexist.lua', {
        cc = 'cc',
        members = {
            ['nonexistent.h'] = {
                some_type = {
                    'some_member',
                },
            },
        },
    })
    local output = load_configh_output('tmp_members_nonexist.lua',
                                       '--out=tmp_members_nonexist.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- header check should result in #undef
    local content = read_header_file('tmp_members_nonexist.h')
    assert.match(content, '/* #undef HAVE_NONEXISTENT_H */')
    -- member should not be defined since header doesn't exist
    assert.not_match(content, 'HAVE_SOME_TYPE_SOME_MEMBER')
end

function testcase.with_slash_in_header_name()
    -- test that headers with slash (sys/types.h) work correctly
    create_test_config_file('tmp_slash_header.lua', {
        cc = 'cc',
        headers = {
            'sys/types.h',
        },
    })
    local output = load_configh_output('tmp_slash_header.lua',
                                       '--out=tmp_slash_header.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- slash should be replaced with underscore in macro name
    local content = read_header_file('tmp_slash_header.h')
    assert.match(content, 'HAVE_SYS_TYPES_H')
end

function testcase.with_funcs_for_slash_header()
    -- test that funcs for headers with slash work correctly
    create_test_config_file('tmp_funcs_slash.lua', {
        cc = 'cc',
        funcs = {
            ['sys/types.h'] = {
                -- Note: types.h doesn't have functions, this tests the mechanism
                'dummy_func',
            },
        },
    })
    local output = load_configh_output('tmp_funcs_slash.lua',
                                       '--out=tmp_funcs_slash.h')

    -- should succeed silently (header exists, but func doesn't)
    assert(#output == 0, 'should have no output on success')

    -- check output file
    local content = read_header_file('tmp_funcs_slash.h')
    -- header should be found
    assert.match(content, 'HAVE_SYS_TYPES_H')
end

function testcase.with_types_for_slash_header()
    -- test that types for headers with slash work correctly
    create_test_config_file('tmp_types_slash.lua', {
        cc = 'cc',
        types = {
            ['sys/types.h'] = {
                'pid_t',
            },
        },
    })
    local output = load_configh_output('tmp_types_slash.lua',
                                       '--out=tmp_types_slash.h')

    -- should succeed silently
    assert(#output == 0, 'should have no output on success')

    -- check output file contains type macro
    local content = read_header_file('tmp_types_slash.h')
    -- header should be found
    assert.match(content, 'HAVE_SYS_TYPES_H')
    -- type should be defined
    assert.match(content, 'HAVE_PID_T')
end

function testcase.features_with_non_integer_index()
    -- test that non-integer index in features results in error
    create_test_config_file('tmp_features_nonint.lua', {
        cc = 'cc',
        features = {
            [1.5] = 'invalid',
        },
    })
    local output = load_configh_output('tmp_features_nonint.lua')
    assert.match(output, 'features index must be an integer, got non-integer')
end

function testcase.features_with_boolean_key()
    -- test that boolean key in features results in error
    create_test_config_file('tmp_features_bool.lua', {
        cc = 'cc',
        features = {
            [true] = 'invalid',
        },
    })
    local output = load_configh_output('tmp_features_bool.lua')
    assert.match(output, 'features index must be an integer, got "boolean"')
end

function testcase.features_array_value_not_string()
    -- test that non-string value in features array part results in error
    create_test_config_file('tmp_features_arrval.lua', {
        cc = 'cc',
        features = {
            123, -- number in array part
        },
    })
    local output = load_configh_output('tmp_features_arrval.lua')
    assert.match(output, 'features[1] value must be a string, got "number"')
end

function testcase.funcs_with_non_string_key()
    -- test that non-string key in funcs results in error
    create_test_config_file('tmp_funcs_nonstr.lua', {
        cc = 'cc',
        funcs = {
            [123] = {
                'printf',
            },
        },
    })
    local output = load_configh_output('tmp_funcs_nonstr.lua')
    assert.match(output, 'funcs[123] must be a string, got "number"')
end

function testcase.members_with_non_string_key()
    -- test that non-string key in members results in error
    create_test_config_file('tmp_members_nonstr.lua', {
        cc = 'cc',
        members = {
            [123] = {
                FILE = {
                    '_flags',
                },
            },
        },
    })
    local output = load_configh_output('tmp_members_nonstr.lua')
    assert.match(output, 'members[123] must be a string, got "number"')
end

function testcase.config_execution_error()
    -- test that config file execution error is handled
    create_test_config_file('tmp_exec_error.lua', [[
return error('config execution error')
]])
    local output = load_configh_output('tmp_exec_error.lua')
    assert.match(output, 'Error: failed to execute config file')
end

function testcase.config_non_table_return()
    -- test that config file returning non-table is handled
    create_test_config_file('tmp_non_table.lua', [[
return "string instead of table"
]])
    local output = load_configh_output('tmp_non_table.lua')
    assert.match(output, 'Error: config file must return a table')
end

function testcase.flush_failure()
    -- test that flush failure is handled
    create_test_config_file('tmp_flush_fail.lua', {
        cc = 'cc',
        -- use invalid output path to trigger flush error
    })
    -- use an invalid output path (directory instead of file)
    local output = load_configh_output('tmp_flush_fail.lua', '--out=/dev/null/')
    assert.match(output, 'Error: failed to write config.h')
end
