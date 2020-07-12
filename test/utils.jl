using Pkg, Test

"""
copy_test_package copied from Pkg.jl.
https://github.com/JuliaLang/Pkg.jl
"""
function copy_test_package(tmpdir::String, name::String; use_pkg=true)
    target = joinpath(tmpdir, name)
    cp(joinpath(@__DIR__, "test_packages", name), target)
    use_pkg || return target

    # The known Pkg UUID, and whatever UUID we're currently using for testing
    known_pkg_uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
    pkg_uuid = Pkg.TOML.parsefile(joinpath(dirname(@__DIR__), "Project.toml"))["uuid"]

    # We usually want this test package to load our pkg, so update its Pkg UUID:
    test_pkg_dir = joinpath(@__DIR__, "test_packages", name)
    for f in ("Manifest.toml", "Project.toml")
        fpath = joinpath(tmpdir, name, f)
        if isfile(fpath)
            write(fpath, replace(read(fpath, String), known_pkg_uuid => pkg_uuid))
        end
    end
    return target
end

function isolate(fn::Function; loaded_depot=false)
    old_load_path = copy(LOAD_PATH)
    old_depot_path = copy(DEPOT_PATH)
    old_home_project = Base.HOME_PROJECT[]
    old_active_project = Base.ACTIVE_PROJECT[]
    old_working_directory = pwd()
    old_general_registry_url = Pkg.Types.DEFAULT_REGISTRIES[1].url
    try
        # Clone the registry only once
        if !isdir(REGISTRY_DIR)
            mkpath(REGISTRY_DIR)
            Base.shred!(LibGit2.CachedCredentials()) do creds
                LibGit2.with(Pkg.GitTools.clone(Pkg.Types.Context(),
                                                "https://github.com/JuliaRegistries/General.git",
                    REGISTRY_DIR, credentials = creds)) do repo
                end
            end
        end

        empty!(LOAD_PATH)
        empty!(DEPOT_PATH)
        Base.HOME_PROJECT[] = nothing
        Base.ACTIVE_PROJECT[] = nothing
        Pkg.UPDATED_REGISTRY_THIS_SESSION[] = false
        Pkg.Types.DEFAULT_REGISTRIES[1].url = REGISTRY_DIR
        Pkg.REPLMode.TEST_MODE[] = false
        withenv("JULIA_PROJECT" => nothing,
                "JULIA_LOAD_PATH" => nothing,
                "JULIA_PKG_DEVDIR" => nothing) do
            target_depot = nothing
            try
                target_depot = mktempdir()
                push!(LOAD_PATH, "@", "@v#.#", "@stdlib")
                push!(DEPOT_PATH, target_depot)
                loaded_depot && push!(DEPOT_PATH, LOADED_DEPOT)
                fn()
            finally
                if target_depot !== nothing && isdir(target_depot)
                    try
                        Base.rm(target_depot; force=true, recursive=true)
                    catch err
                        @show err
                    end
                end
            end
        end
    finally
        empty!(LOAD_PATH)
        empty!(DEPOT_PATH)
        append!(LOAD_PATH, old_load_path)
        append!(DEPOT_PATH, old_depot_path)
        Base.HOME_PROJECT[] = old_home_project
        Base.ACTIVE_PROJECT[] = old_active_project
        cd(old_working_directory)
        Pkg.REPLMode.TEST_MODE[] = false # reset unconditionally
        Pkg.Types.DEFAULT_REGISTRIES[1].url = old_general_registry_url
    end
end

function test_package_expected_pass(pkg::String)
    mktempdir() do tmp
        copy_test_package(tmp, pkg)
        Pkg.activate(joinpath(tmp, pkg))
        TestReports.test(pkg)
    end
end

function test_package_expected_fail(pkg::String)
    mktempdir() do tmp
        copy_test_package(tmp, pkg)
        Pkg.activate(joinpath(tmp, pkg))
        @test_throws Exception TestReports.test(pkg)
    end
end
