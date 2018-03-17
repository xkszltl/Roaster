# ================================================================
# Environment for Package Installation
# ================================================================

export RPM_MAX_ATTEMPT=10

# TODO: Fix the following issue:
#       LLVM may select the wrong gcc toolchain without libgcc_s integrated.
#       The correct choice is x86_64-redhat-linux instead of x86_64-linux-gnu.
#
#       libasan2 seems to contain libasan.so.3.0.0 and causing a conflict with libasan3
export RPM_BLACKLIST=$(echo "
    *-debuginfo
    gcc-x86_64-linux-gnu
    libasan2
    python-lexicon
    python-qpid-common
    python2-paramiko
" | sed -n 's/^[[:space:]]*\([^[:space:]][^[:space:]]*\).*/--exclude \1/p' | paste -s - | xargs)

export RPM_CACHE_ARGS=$([ -f $RPM_CACHE_REPO ] && echo "--disableplugin=axelget,fastestmirror")

export RPM_INSTALL="yum install -y $RPM_CACHE_ARGS --nogpgcheck $RPM_BLACKLIST"
export RPM_UPDATE="yum update -y $RPM_CACHE_ARGS --nogpgcheck $RPM_BLACKLIST"
