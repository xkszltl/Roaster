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

Write-Host "--------------------------------------------------------------------------------"

Get-ChildItem nuget | Foreach-Object {
    $pkg = $_.Name
    if ($pkg -eq "glog")
    {
        $prefix = "${Env:ProgramFiles}/google-glog"
    }
    elseif ($pkg -eq "mkldnn")
    {
        $prefix = "${Env:ProgramFiles}/Intel(R) MKL-DNN"
    }
    else
    {
        $prefix = "${Env:ProgramFiles}/$pkg"
    }
    if (Test-Path $prefix)
    {
        Write-Host "Packaging ${pkg}..."

        pushd nuget
        cmd /c rmdir /Q "$pkg\$pkg"
        cmd /c mklink /D "$pkg\$pkg" $prefix
        & ${Env:NUGET_HOME}/nuget.exe pack -version $version "$pkg/Roaster.${pkg}.v141.dyn.x64.nuspec"
        cmd /c rmdir /Q "$pkg\$pkg"
        popd

        Write-Host "--------------------------------------------------------------------------------"
    }
}

Write-Host "Completed!"

popd