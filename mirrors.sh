#!/bin/bash

set -e

mkdir -p /var/mirrors
cd /var/mirrors
parallel --ungroup 'bash -c '"'"'
set -e
export ROOT=/var/mirrors
if [ ! -d $ROOT/{} ]; then mkdir -p $ROOT/$(dirname {}) && cd $ROOT/$(dirname {}) && git clone --mirror git@github.com:{} && cd $ROOT/{}
else cd $ROOT/{} && git fetch --all
fi &&
git remote set-url --push origin git@git.codingcafe.org:Mirrors/{} && git push --mirror
'"'" ::: {llvm-mirror/{ll{vm,d,db,go},clang{,-tools-extra},polly,compiler-rt,openmp,lib{unwind,cxx{,abi}},test-suite},jemalloc/jemalloc,aws/aws-{cli,sdk-{cpp,go,java,js,net,php,ruby}},shadowsocks/shadowsocks}.git
