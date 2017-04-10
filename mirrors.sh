#!/bin/bash

mkdir -p /var/mirrors/llvm-mirror
cd /var/mirrors/llvm-mirror
parallel -j0 --ungroup "bash -c 'if [ ! -d '{}' ]; then git clone --mirror git@github.com:llvm-mirror/'{}'; fi && cd '{}' && git fetch --all
git remote set-url --push origin git@git.codingcafe.org:Mirrors/llvm-mirror/'{}' && git push --mirror'"                      \
::: {ll{vm,d,db,go},clang{,-tools-extra},polly,compiler-rt,openmp,lib{unwind,cxx{,abi}},test-suite}.git
