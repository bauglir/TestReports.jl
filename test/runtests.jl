using TestReports
using Test
using ReferenceTests
using UUIDs
using Pkg

# Include utils
include("utils.jl")

# Strip the filenames from the string, so that the reference strings work on different computers
strip_filepaths(str) = replace(str, r" at .*\d+$"m => "")

# Replace direction of windows slashes so reference strings work on windows
replace_windows_filepaths(str) = replace(str, ".\\" => "./")

# Replace Int32s so reference strings work on x86 platforms
replace_Int32s(str) = replace(str, "Int32" => "Int64")

@testset "SingleNest" begin
    @test_reference "references/singlenest.txt" read(`$(Base.julia_cmd()) -e "using Test; using TestReports; (@testset ReportingTestSet \"blah\" begin @testset \"a\" begin @test 1 ==1 end end) |> report |> print"`, String) |> strip_filepaths |> replace_windows_filepaths |> replace_Int32s
end

@testset "Complex Example" begin
    if VERSION >= v"1.4.0"
        @test_reference "references/complexexample.txt" read(`$(Base.julia_cmd()) $(@__DIR__)/example.jl`, String) |> strip_filepaths |> replace_windows_filepaths |> replace_Int32s
    else
        @warn "skipping complex reference test on pre-Julia 1.4"
    end
end


@testset "any_problems" begin

    fail_code = """
    using Test
    using TestReports
    ts = @testset ReportingTestSet "eg" begin
        @test false == true
    end;
    exit(any_problems(ts))
    """

    @test_throws Exception run(`$(Base.julia_cmd()) -e $(fail_code)`)


    pass_code = """
    using Test
    using TestReports
    ts = @testset ReportingTestSet "eg" begin
        @test true == true
    end;
    exit(any_problems(ts))
    """

    @test run(`$(Base.julia_cmd()) -e $(pass_code)`) isa Any #this line would error if fail



end

@testset "Runner tests" begin
    # Simple tests passing
    test_package_expected_pass("PassingTests")
    # Errors
    test_package_expected_fail("FailedTest")
    test_package_expected_fail("ErroredTest")
    test_package_expected_fail("NoTestFile")
    # Various test deps
    test_pkgs = [
        "TestsWithDeps",
        "TestsWithTestDeps"
    ]
    for pkg in test_pkgs
        test_package_expected_pass(pkg)
    end
    # Test file project file tests, 1.2 and above
    @static if VERSION >= v"1.2.0"
        test_pkgs = [
            "TestsWithProjectFile",
            "TestsWithProjectFileWithTestDeps"
        ]
        for pkg in test_pkgs
            test_package_expected_pass(pkg)
        end
    end
end
