#!/usr/bin/pwsh

$ErrorActionPreference="Stop"

cd $PSScriptRoot

ls -Name -Path "${Env:ProgramFiles}/opencv/x64/vc16/lib/*.lib" | sort
(ls -Name -Path ("${Env:ProgramFiles}/opencv/bin/*.pdb", "${Env:ProgramFiles}/opencv/x64/vc16/bin/*.pdb", "${Env:ProgramFiles}/opencv/x64/vc16/lib/*.lib") | sort) -Replace '^(.*)$',"<Content Include=`"`$(MSBuildThisFileDirectory)/../lib/native/lib/Release/$1`">`n  <Link>`$1</Link>`n  <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>`n</Content>"
