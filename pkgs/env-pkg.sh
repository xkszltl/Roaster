# ================================================================
# Environment for Package Installation
# ================================================================

export RPM_MAX_ATTEMPT=10

# TODO: Fix the following issue:
#       LLVM may select the wrong gcc toolchain without libgcc_s integrated.
#       The correct choice is x86_64-redhat-linux instead of x86_64-linux-gnu.
#
#       libasan2 seems to contain libasan.so.3.0.0 and causing a conflict with libasan3
#
#       python-lexicon conflict with python2-lexicon
#       file /usr/lib/python2.7/site-packages/test/__init__.pyc conflicts between attempted installs of python2-ansible-runner-1.0.1-1.el7.noarch and python2-neomodel-3.2.8-1.el7.noarch
#       
#       Python issues from CentOS 7.5:
#           python2-azure-sdk conflict with python-azure-sdk
#           python2-boto3 conflict with python-boto3
#           python2-s3transfer conflict with python-s3transfer
#
export RPM_BLACKLIST=$(echo "
    *-debuginfo
    gcc-x86_64-linux-gnu
    libasan2
    python-lexicon
    python2-ansible-runner
    python2-azure-sdk
    python2-boto3
    python2-s3transfer
" | sed -n 's/^[[:space:]]*\([^[:space:]][^[:space:]]*\).*/--exclude \1/p' | paste -s - | xargs)

export RPM_CACHE_ARGS=$([ -f $RPM_CACHE_REPO ] && echo "--disableplugin=axelget,fastestmirror")

export RPM_INSTALL="sudo yum install -y $RPM_CACHE_ARGS --nogpgcheck $RPM_BLACKLIST"
export RPM_UPDATE="sudo yum update -y $RPM_CACHE_ARGS --nogpgcheck $RPM_BLACKLIST"
export RPM_REINSTALL="sudo yum reinstall -y $RPM_CACHE_ARGS --nogpgcheck $RPM_BLACKLIST"
