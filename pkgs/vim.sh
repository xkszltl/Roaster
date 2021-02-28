# ================================================================
# Account Configuration
# ================================================================

[ -e $STAGE/vim ] && ( set -xe
    cd
    cat << EOF > ~/.vimrc
syntax on
set number
set nocompatible
set backspace=indent,eol,start
set cindent
set nobackup
set expandtab
set softtabstop=4
set shiftwidth=4
set tabstop=4
set guifont=Courier_New
set cinoptions=:0,g0
colorscheme default
nmap <F2> :vs %:r.in <CR>
autocmd FileType cpp nmap <F5> :!./%:r < %:r.in <CR>
autocmd FileType cpp nmap <F6> :!./%:r <CR>
autocmd FileType cpp nmap <F9> :!g++ %:r.cpp -o %:r -g -Wall <CR>
autocmd FileType cpp nmap <F10> :!g++ %:r.cpp -o %:r -O2 <CR>
autocmd FileType cpp nmap <F3> :vs %:r.cpp <CR>
autocmd FileType java nmap <F5> :!java %:r < %:r.in <CR>
autocmd FileType java nmap <F9> :!javac %:r.java <CR>
autocmd FileType make set noexpandtab
EOF
)
sudo rm -vf $STAGE/vim
sync || true
