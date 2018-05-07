################################################################################
# Intel may ask you to register on their website before downloading libraries.
# Please follow their instructions and procedures.
#
# You agree to take full responsibility for using this script, and relief
# authors from any liability of not acquiring data in the normal way.
################################################################################

#Requires -RunAsAdministrator

$ErrorActionPreference="Stop"

$intel_url="http://registrationcenter-download.intel.com/akdlm/irc_nas/tec"

pushd ~/Downloads
mkdir Intel
pushd Intel

# Update the URL as new version releases.
Invoke-WebRequest ${intel_url}/12694/w_daal_2018.2.185.exe -OutFile daal.exe
& ./daal.exe
Invoke-WebRequest ${intel_url}/12693/w_ipp_2018.2.185.exe -OutFile ipp.exe
& ./ipp.exe
Invoke-WebRequest ${intel_url}/12692/w_mkl_2018.2.185.exe -OutFile mkl.exe
& ./mkl.exe
Invoke-WebRequest ${intel_url}/12745/w_mpi_2018.2.185.exe -OutFile mpi.exe
& ./mpi.exe
Invoke-WebRequest ${intel_url}/12566/w_tbb_2018.2.185.exe -OutFile tbb.exe
& ./tbb.exe

popd