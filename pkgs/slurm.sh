# ================================================================
# SLURM
# ================================================================

[ -e $STAGE/slurm ] && ( set -xe
    cd $SCRATCH

    until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/SchedMD/slurm.git" | sed -n 's/.*[[:space:]]refs\/tags\/\(slurm-[0-9\.]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/SchedMD/slurm.git"; do echo 'Retrying'; done
    git clone --depth 1 --no-checkout --no-single-branch $GIT_MIRROR/SchedMD/slurm.git
    cd slurm
    git checkout $(git tag | sed -n '/^slurm-[0-9\-]*$/p' | sort -V | tail -n1)

    . scl_source enable devtoolset-8 || true

    for i in $(sed -n 's/^[[:space:]]*\(.*:\).* META .*/\1/p' slurm.spec); do
        sed -i "s/^\([[:space:]]*$i[[:space:]]*\).* META .*/\1"$(sed -n "s/[[:space:]]*$i[[:space:]]*\(.*\)/\1/p" META | head -n1)"/" slurm.spec
    done

    export SLURM_NAME=$(for i in Name Version Release; do
        sed -n "s/^[[:space:]]*$i:[[:space:]]*\(.*\)/\1/p" META | head -n1
    done | xargs | sed 's/[[:space:]][[:space:]]*/-/g')

    export SLURM_EXT=$(sed -n "s/^[[:space:]]*Source:[^\.]*\(.*\)/\1/p" slurm.spec | head -n1)

    export SLURM_TAR=$SLURM_NAME$SLURM_EXT

    cd ..
    mkdir -p $SLURM_NAME
    cp -rf slurm/* $_/
    tar -acvf $SLURM_TAR $SLURM_NAME
    rm -rf $SCRATCH/$SLURM_NAME

    rpmbuild -ta $SLURM_TAR --with lua --with multiple_slurmd --with mysql --with openssl

    rm -rf $SCRATCH/slurm*

    dnf install $HOME/rpmbuild/RPMS/$(uname -i)/slurm{,-*}.rpm
    rm -rf $HOME/rpmbuild
)
sudo rm -vf $STAGE/slurm
sync || true

