" Minimal test harness: add the plugin to 'runtimepath' and enable filetype
" detection so after/ftplugin/markdown.vim loads on Markdown buffers.
"
" Usage: vim -Es -u NONE -N -S test/run.vim -S test/follow.vim
"     or: nvim --headless -u NONE -S test/run.vim -S test/follow.vim

let g:vmf_root = expand('<sfile>:p:h:h')
execute 'set runtimepath+=' . fnameescape(g:vmf_root)

filetype plugin indent on
syntax enable
