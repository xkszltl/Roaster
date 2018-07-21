# Cuda installation script

$DownloadDir = "${Env:TMP}/CUDA"
New-Item -Path $DownloadDir -Type Directory -ErrorAction SilentlyContinue
if (-not $(Test-Path $DownloadDir))
{
    Write-Host "Failed to create path $DownloadDir"
    Exit 1
}

$exe = "cuda_9.2.148_win10.exe"
if (-not $(Test-Path "${DownloadDir}/$exe"))
{
    Write-Host "Downloading CUDA installation files..."
    $wc = [System.Net.WebClient]::new()
    $wc.DownloadFile("https://developer.nvidia.com/compute/cuda/9.2/Prod2/local_installers/$($exe.substring(0, $exe.IndexOf(".exe")))", "${DownloadDir}/$exe")
}

Write-Host "Installing CUDA..."
& $(Join-Path $DownloadDir $exe) -s
