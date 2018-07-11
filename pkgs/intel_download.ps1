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

# TODO: Consider parallelizing downloads

# Update the URL as new version releases.
Invoke-WebRequest ${intel_url}/13039/w_daal_2018.3.210.exe -OutFile daal.exe
& ./daal.exe
Invoke-WebRequest ${intel_url}/13038/w_ipp_2018.3.210.exe -OutFile ipp.exe
& ./ipp.exe
Invoke-WebRequest ${intel_url}/13037/w_mkl_2018.3.210.exe -OutFile ipp.exe
& ./mkl.exe
Invoke-WebRequest ${intel_url}/13111/w_mpi_p_2018.3.210.exe -OutFile mpi.exe
& ./mpi.exe
Invoke-WebRequest ${intel_url}/13111/w_tbb_2018.4.210.exe -OutFile tbb.exe
& ./tbb.exe

popd
