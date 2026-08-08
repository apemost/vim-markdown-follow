" Minimal test harness: add the plugin to 'runtimepath', enable filetype
" detection so after/ftplugin/markdown.vim loads on Markdown buffers, and
" install a stub netrw autoload (real netrw unavailable under -u NONE).
"
" Usage: vim -Es -u NONE -N -S test/run.vim -S test/follow.vim
"     or: nvim --headless -u NONE -S test/run.vim -S test/follow.vim

let g:vmf_root = expand('<sfile>:p:h:h')
execute 'set runtimepath+=' . fnameescape(g:vmf_root)

let s:stub = substitute($TMPDIR . '/vmf-rtp', '//', '/', 'g')
call mkdir(s:stub . '/autoload', 'p')
call writefile([
      \ 'function! netrw#BrowseX(url, ...) abort',
      \ '  " Simulate a strict 2-arg netrw: a 1-arg call raises E119 (via echoerr,',
      \ '  " which carries the Vim(echoerr): prefix the fallback catch expects),',
      \ '  " exercising s:OpenBrowser''s try/catch fallback to the 2-arg form.',
      \ '  if a:0 == 0',
      \ '    echoerr ''E119: Not enough arguments for function: netrw#BrowseX''',
      \ '  endif',
      \ '  let g:mf_captured = a:url',
      \ '  return',
      \ 'endfunction',
      \ ], s:stub . '/autoload/netrw.vim')
" Prepend so the stub wins over any bundled netrw.
execute 'set runtimepath=' . fnameescape(s:stub) . ',' . &runtimepath
let g:mf_captured = ''

filetype plugin indent on
syntax enable
