"*********************************************************************
" vim-markdown-follow: follow/open Markdown links under the cursor.
"
" Activates on the markdown filetype. vim-markdown is optional: its syntax
" groups are used only to locate links more precisely when available.
"*********************************************************************

if exists('b:did_markdown_follow')
  finish
endif
let b:did_markdown_follow = 1

" Plug mappings for users who want to bind their own keys.
nnoremap <buffer> <silent> <Plug>(MarkdownFollow)     :call markdownfollow#Follow()<CR>
nnoremap <buffer> <silent> <Plug>(MarkdownFollowOpen) :call markdownfollow#Open()<CR>

if !get(g:, 'vim_markdown_follow_no_default_maps', 0)
  nmap <buffer> ge <Plug>(MarkdownFollow)
  nmap <buffer> gx <Plug>(MarkdownFollowOpen)
endif
