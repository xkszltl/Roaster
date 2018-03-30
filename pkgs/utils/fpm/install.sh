#!/bin/bash

rm -rf "$INSTALL_ABS" &

sudo yum install -y "./codingcafe-$(basename $(pwd))-"*".rpm"

wait
