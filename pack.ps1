$ErrorActionPreference="Stop"

Write-Host "Create NuGet Packages"

${Env:NUGET_HOME} = "$(Get-Command -Name nuget -ErrorAction SilentlyContinue | select -ExpandProperty Source | Split-Path -Parent)"

if (${Env:NUGET_HOME} -eq $null -or -not $(Test-Path ${Env:NUGET_HOME}/nuget.exe -ErrorAction SilentlyContinue))
{
    ${Env:NUGET_HOME} = $pwd.Path
}

Test-Path ${Env:NUGET_HOME}/nuget.exe | Out-Null

pushd $PSScriptRoot

$versionPrefix = 'v'

$rawVersion = git describe --long --match ($versionPrefix+'*')
Write-Host 'git version string:' $rawVersion

$time    = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmssfffffff")
$iter    = $rawVersion.split('-')[-2]
$hash    = $rawVersion.split('-')[-1]
$tag     = $rawVersion.split('-')[0].split('/')[-1]
$version = $tag.TrimStart($versionPrefix) + '.' + $iter + '-T' + $time + $hash

Write-Host 'tag'     $tag
Write-Host 'iter'    $iter
Write-Host 'hash'    $hash
Write-Host 'version' $version

if (Test-Path build)
{
    cmd /c rmdir /Q /S build
}
mkdir build
pushd build

Write-Host "--------------------------------------------------------------------------------"

Get-ChildItem ../nuget | Foreach-Object {
    $pkg = $_.Name
    if ($pkg -eq "eigen")
    {
        $prefix = "${Env:ProgramFiles}/Eigen3"
    }
    elseif ($pkg -eq "mkldnn")
    {
        $prefix = "${Env:ProgramFiles}/Intel(R) MKL-DNN"
    }
    elseif ($pkg -eq "ort")
    {
        $prefix = "${Env:ProgramFiles}/onnxruntime"
    }
    elseif ($pkg -eq "daal" -or $pkg -eq "iomp" -or $pkg -eq "ipp" -or $pkg -eq "mkl" -or $pkg -eq "mpi" -or $pkg -eq "tbb")
    {
        $prefix = "${Env:ProgramFiles(x86)}/IntelSWTools"
    }
    else
    {
        $prefix = "${Env:ProgramFiles}/$pkg"
    }
    if (Test-Path $prefix)
    {
        $job = {
            param(${pkg}, ${prefix}, ${version})

            Set-Location $using:PWD

            Write-Host "Packaging ${pkg}..."

            if (Test-Path "..\nuget\${pkg}\${pkg}")
            {
                cmd /c rmdir /Q "..\nuget\${pkg}\${pkg}"
            }
            cmd /c mklink /D "..\nuget\${pkg}\${pkg}" ${prefix}
            & ${Env:NUGET_HOME}/nuget.exe pack -version ${version} "../nuget/${pkg}/Roaster.${pkg}.v141.dyn.x64.nuspec"
            cmd /c rmdir /Q "..\nuget\${pkg}\${pkg}"

            & ${Env:NUGET_HOME}/nuget.exe push -Source "OneOCR" -ApiKey AzureDevOps ./Roaster.${pkg}.v141.dyn.x64.${version}.nupkg
            & ${Env:NUGET_HOME}/nuget.exe locals http-cache -clear

            Write-Host "--------------------------------------------------------------------------------"
        }
        Start-Job $job -ArgumentList @(${pkg}, ${prefix}, ${version})
    }
}

While (Get-Job -State "Running")
{
    Write-Host (Get-Job -State "Completed").count "/" (Get-Job).count
    Start-Sleep 3
}
Get-Job | Receive-Job
Remove-Job *

popd

Write-Host "Completed!"

popd