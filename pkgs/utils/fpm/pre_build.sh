#!/bin/bash

[ "$INSTALL_PREFIX" ] || export INSTALL_PREFIX="/usr/local"
export INSTALL_ROOT="$(mktemp -dp . 'install.XXXXXXXXXX')"
export INSTALL_REL="$INSTALL_ROOT/$INSTALL_PREFIX"
mkdir -p "$INSTALL_REL"
export INSTALL_ABS=$(readlink -e "$INSTALL_REL")

[ "$FPM_EXCLUDE" ] || ! rpm -q filesystem || export FPM_EXCLUDE="$(repoquery -l filesystem)" > /dev/null &
