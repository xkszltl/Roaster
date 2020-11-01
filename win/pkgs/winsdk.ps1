#Requires -RunAsAdministrator

Get-Content "$PSScriptRoot/utils/re-entry.ps1" -Raw | Invoke-Expression
$ErrorActionPreference="Stop"

$DownloadDir = "${Env:SCRATCH}/Windows_SDK"
New-Item -Path $DownloadDir -Type Directory -ErrorAction SilentlyContinue
if (-not $(Test-Path $DownloadDir))
{
    Write-Host "Failed to create path $DownloadDir"
    Exit 1
}

# Manual crawler:
# curl -sSL 'https://developer.microsoft.com/en-us/windows/downloads/sdk-archive/' | sed -n 's/.*href="\([^"]*\/go\.microsoft\.com\/[^"]*\)".*/\1/p' | sed 's/^\/\//https:\/\//' | xargs -n1 curl -sSIL | sed -n 's/Location: *//p' | grep '[Ss][Dd][Kk]' | grep -v '\.[Ii][Ss][Oo]'
$url_win10_2004="https://download.microsoft.com/download/1/c/3/1c3d5161-d9e9-4e4b-9b43-b70fe8be268c/windowssdk/winsdksetup.exe"
$url_win10_1903="https://download.microsoft.com/download/4/2/2/42245968-6A79-4DA7-A5FB-08C0AD0AE661/windowssdk/winsdksetup.exe"
$url_win10_1809="https://download.microsoft.com/download/5/C/3/5C3770A3-12B4-4DB4-BAE7-99C624EB32AD/windowssdk/winsdksetup.exe"
$url_win10_1803="https://download.microsoft.com/download/5/A/0/5A08CEF4-3EC9-494A-9578-AB687E716C12/windowssdk/winsdksetup.exe"
$url_win10_1709="https://download.microsoft.com/download/8/C/3/8C37C5CE-C6B9-4CC8-8B5F-149A9C976035/windowssdk/winsdksetup.exe"
$url_win10_1703="https://download.microsoft.com/download/E/1/B/E1B0E6C0-2FA2-4A1B-B322-714A5586BE63/windowssdk/winsdksetup.exe"
$url_win10_1607="https://download.microsoft.com/download/C/D/8/CD8533F8-5324-4D30-824C-B834C5AD51F9/standalonesdk/sdksetup.exe"
$url_win10_1511="https://download.microsoft.com/download/2/1/2/2122BA8F-7EA6-4784-9195-A8CFB7E7388E/standalonesdk/sdksetup.exe"
$url_win10_1507="https://download.microsoft.com/download/E/1/F/E1F1E61E-F3C6-4420-A916-FB7C47FBC89E/standalonesdk/sdksetup.exe"
$url_win81="https://download.microsoft.com/download/B/0/C/B0C80BA3-8AD6-4958-810B-6882485230B5/standalonesdk/sdksetup.exe"
$url_win8="https://download.microsoft.com/download/F/1/3/F1300C9C-A120-4341-90DF-8A52509B23AC/standalonesdk/sdksetup.exe"
$url_win7="https://download.microsoft.com/download/A/6/A/A6AC035D-DA3F-4F0C-ADA4-37C8E5D34E3D/winsdk_web.exe"

foreach ($url in @(${url_win10_1709}, ${url_win10_1809}, ${url_win10_1903}, ${url_win10_2004}))
{
    rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${DownloadDir}/setup.exe"
    Write-Host "Downloading Windows SDK installer..."
    [System.Net.WebClient]::new().DownloadFile("$url", "${DownloadDir}/setup.exe")

    Write-Host "Installing Windows SDK..."
    & "${DownloadDir}/setup.exe" -ceip off -features + -quiet | Out-Null

    rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue "${DownloadDir}/setup.exe"
}
