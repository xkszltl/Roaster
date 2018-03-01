# ================================================================
# Install TeX Live
# ================================================================

[ -e $STAGE/tex ] && ( set -xe
    export TEXLIVE_MIRROR=$(
        if [ $GIT_MIRROR = $GIT_MIRROR_CODINGCAFE ]; then
            echo 'https://repo.codingcafe.org/CTAN'
        else
            echo 'http://mirror.ctan.org'
        fi
    )'/systems/texlive/tlnet'

    cd $SCRATCH
    curl -sSL $TEXLIVE_MIRROR/install-tl-unx.tar.gz | tar -zxvf -
    cd install-tl-*
    ./install-tl --version

    ./install-tl --repository $TEXLIVE_MIRROR --profile <(
    # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    cat << EOF
selected_scheme scheme-full
instopt_adjustpath 1
EOF
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    )

    cd
    rm -rf $SCRATCH/install-tl-*
)
rm -rvf $STAGE/tex
sync || true
