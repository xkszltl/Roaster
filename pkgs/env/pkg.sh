# ================================================================
# Environment for Package Installation
# ================================================================

export DEB_MAX_ATTEMPT=10
export RPM_MAX_ATTEMPT=10

# Note: Do not leak $DISTRO_* because this script is only for package management environment.
case "$(. <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release') && bash -c 'printf "$DISTRO_ID"')" in
'centos' | 'fedora' | 'rhel')
    export PKG_MAX_ATTEMPT="$RPM_MAX_ATTEMPT"
    ;;
'debian' | 'linuxmint' | 'ubuntu')
    export PKG_MAX_ATTEMPT="$DEB_MAX_ATTEMPT"
    ;;
*)
    export PKG_MAX_ATTEMPT=10
    ;;
esac

# TODO: Fix the following issue:
#   - LLVM may select the wrong gcc toolchain without libgcc_s integrated.
#     The correct choice is x86_64-redhat-linux instead of x86_64-linux-gnu.
#   - python-lexicon conflict with python2-dns-lexicon
#     file /usr/lib/python2.7/site-packages/test/__init__.pyc conflicts between attempted installs of python2-ansible-runner-1.0.1-1.el7.noarch and python2-neomodel-3.2.8-1.el7.noarch
#   - Python issues from CentOS 7.5:
#     * python2-s3transfer conflict with python-s3transfer
#   - rh-ruby26-rubygem-bundler-doc has version mismatch between 1.16/1.17.

export RPM_BLACKLIST=$(echo "
    *-debuginfo
    git-cola
    python-lexicon
    python2-ansible-runner
    python2-s3transfer
    rh-ruby26-rubygem-bundler-doc
" | sed -n 's/^[[:space:]]*\([^[:space:]][^[:space:]]*\).*/--exclude \1/p' | paste -s - | xargs)

export RPM_CACHE_ARGS=$([ -f "$RPM_CACHE_REPO" ] && echo "--disableplugin=axelget,fastestmirror")

export RPM_INSTALL="sudo dnf install -y $RPM_CACHE_ARGS --nogpgcheck $RPM_BLACKLIST"
export RPM_UPDATE="sudo dnf update -y $RPM_CACHE_ARGS --nogpgcheck $RPM_BLACKLIST"
export RPM_REINSTALL="sudo dnf reinstall -y $RPM_CACHE_ARGS --nogpgcheck $RPM_BLACKLIST"
