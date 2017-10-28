# ================================================================
# Install TeX Live
# ================================================================

[ -e $STAGE/tex ] && ( set -e set -e
    export TEXLIVE_MIRROR=https://repo.codingcafe.org/CTAN/systems/texlive/tlnet

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
) && rm -rvf $STAGE/tex
sync || true
