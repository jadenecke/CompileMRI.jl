function check_pkg(name)
    app_name = get_appname(name)
    apppath = pathof(app_name)
    if !isdir(apppath)
        download_pkg(app_name)
    end
end

function get_appname(name)
    return Dict("romeo" => "RomeoApp", "clearswi" => "ClearswiApp")[name]
end

function download_pkg(pkg, subpkgs=nothing)
    if pkg == "ClearswiApp" return download_pkg(pkg, ["CLEARSWI"]) end

    Pkg.develop(PackageSpec(;url="https://github.com/korbinian90/$pkg.jl"))
    if !isnothing(subpkgs)
        Pkg.activate(pathof(pkg))
        for subpkg in subpkgs
            Pkg.add(PackageSpec(;url="https://github.com/korbinian90/$subpkg.jl"))
        end
    end
    Pkg.instantiate()
end

function findartifactpath(pth, name)
    for d in readdir(pth; join=true)
        if any(occursin.(lowercase(name), lowercase.(readdir(joinpath(d, "logs")))))
            return d
        end
    end
end

pathof(app) = normpath(homedir(), ".julia/dev", app)

function clean_app(path, app_names)
    # remove all dlls in mkl artifact but keep
    # mkl_core.1.dll and mkl_rt.1.dll

    artifact_path = joinpath(path, "share", "julia", "artifacts")
    if !ispath(artifact_path)
        artifact_path = joinpath(path, "artifacts")
    end
    
    mkl_path = findartifactpath(artifact_path, "mkl")
    if isdir(joinpath(mkl_path, "bin"))
        for f in readdir(joinpath(mkl_path, "bin"); join=true)
            if !(occursin("mkl_core.1.dll", f) || occursin("mkl_rt.1.dll", f))
                rm(f)
            end
        end
    end
    if isdir(joinpath(mkl_path, "lib"))
        for f in readdir(joinpath(mkl_path, "lib"); join=true)
            if !(occursin("libmkl_core.so", f) || occursin("libmkl_rt.so", f))
                rm(f)
            end
        end
    end

    for app_name in app_names
        try
            test_romeo(path, app_name)
        catch
            @warn("Artifact cleaning failed! Please recompile clearswi with the option `clean=false`. The artifacts folder will be very large but some of them might not needed and can be manually removed.")
        end
    end
end

function copy_matlab(path)
    cp(joinpath(dirname(@__DIR__), "matlab"), joinpath(path, "matlab"))
end

function copy_mkl(path)
    mkl_sha1_str = "28c8373199bf79bd94ce76e3f45eeaef6d9c1c47"
    mkl_sha1 = Base.SHA1(mkl_sha1_str)
    if Pkg.artifact_exists(mkl_sha1)
        destination_artifacts_path = joinpath(path, "share", "julia", "artifacts", mkl_sha1_str)
        cp(Pkg.artifact_path(mkl_sha1), destination_artifacts_path)
    end
end

function update(name)
    app_name = get_appname(name)
    try 
        rm(pathof(app_name); force=true, recursive=true)
    catch 
        @warn "Couldn't remove the old $app_name folder! ($(pathof(app_name))) Maybe it is opened in another App"
    end
    download_pkg(app_name)
end

function test(path, app_name)
    file = tempname()
    phasefile = abspath(joinpath(@__DIR__, "..", "test", "data", "small", "Phase.nii"))
    magfile = abspath(joinpath(@__DIR__, "..", "test", "data", "small", "Mag.nii"))
    args_dict = Dict("romeo" => [phasefile, "-o", file, "-t", "1:3", "-k", "nomask"],
                "clearswi" => ["-p", phasefile, "-m", magfile, "-o", file, "-t", "1:3"])
    args = args_dict[app_name]
    name = app_name * (Sys.iswindows() ? ".exe" : "")
    executable = joinpath(path, "bin", name)
    @assert isfile(executable)
    cmd = `$executable $args`
    @assert success(run(cmd))
end