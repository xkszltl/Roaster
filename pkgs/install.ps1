# TODO: Consider what scripts may be parallelizable in order to reduce installation time
$prefix = pwd
Write-Host Root script execution path: $prefix
cd $prefix
Write-Host 'Invoking zlib.ps1'
./zlib.ps1
cd $prefix
Write-Host 'Invoking openssl.ps1'
./openssl.ps1
cd $prefix
Write-Host 'Invoking curl.ps1'
./curl.ps1
cd $prefix
Write-Host 'Invoking cuda.ps1'
./cuda.ps1
cd $prefix
Write-Host 'Invoking cudnn.ps1'
./cudnn.ps1
cd $prefix
Write-Host 'Invoking intel_download.ps1'
./intel_download.ps1
cd $prefix
Write-Host 'Invoking intel_link.ps1'
./intel_link.ps1
cd $prefix
Write-Host 'Invoking boost.ps1'
./boost.ps1
cd $prefix
Write-Host 'Invoking jsoncpp.ps1'
./protobuf.ps1
cd $prefix
Write-Host 'Invoking eigen.ps1'
./eigen.ps1
cd $prefix
Write-Host 'Invoking pybind11.ps1'
./pybind11.ps1
cd $prefix
Write-Host 'Invoking mkl-dnn.ps1'
./mkl-dnn.ps1
cd $prefix
Write-Host 'Invoking gflags.ps1'
./gflags.ps1
cd $prefix
Write-Host 'Invoking glog.ps1'
./glog.ps1
cd $prefix
Write-Host 'Invoking gtest.ps1'
./gtest.ps1
cd $prefix
Write-Host 'Invoking snappy.ps1'
./snappy.ps1
cd $prefix
Write-Host 'Invoking protobuf.ps1'
./protobuf.ps1
cd $prefix
Write-Host 'Invoking rocksdb.ps1'
./rocksdb.ps1
cd $prefix
Write-Host 'Invoking caffe2.ps1'
./caffe2.ps1
cd $prefix
Write-Host 'Installation Complete!'
