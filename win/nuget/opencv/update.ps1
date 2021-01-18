#!/usr/bin/env powershell

$ErrorActionPreference="Stop"

cd $PSScriptRoot

(ls -Name -Path ("${Env:ProgramFiles}/opencv/bin/*.dll", "${Env:ProgramFiles}/opencv/bin/*.exe", "${Env:ProgramFiles}/opencv/x64/vc16/bin/*.dll", "${Env:ProgramFiles}/opencv/x64/vc16/bin/*.exe") | sort) -Replace '^(.*)$',"<Content Include=`"`$(MSBuildThisFileDirectory)/../lib/native/lib/Release/$1`">`n  <Link>`$1</Link>`n  <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>`n</Content>"
