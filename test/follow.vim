" Self-contained tests for vim-markdown-follow.
" Loaded after test/run.vim (which sets g:vmf_root, rtp, and filetype detection).

set nomore

let g:out = []
function! Check(name, cond, detail) abort
  call add(g:out, (a:cond ? 'PASS' : 'FAIL') . ': ' . a:name . (a:cond ? '' : ' -> ' . a:detail))
endfunction
function! R(p) abort
  return resolve(a:p)
endfunction

" Stub :Man so exists(':Man')==2 and the sanitize path is really exercised.
function! StubManTopic(topic) abort
  let g:man_topic = a:topic
endfunction
command! -nargs=1 Man call StubManTopic(<q-args>)
let g:man_topic = ''

let tmp = substitute($TMPDIR . '/vmf-test', '//', '/', 'g')
let marker = tmp . '/inject-marker'
call delete(marker)
call mkdir(tmp . '/sub', 'p')
call writefile(['# Target Heading', '', 'body'], tmp . '/sub/target.md')
call writefile(['# No Ext Md'], tmp . '/sub/noext.md')
call writefile(['# Alt Markdown'], tmp . '/sub/alt.markdown')
call writefile([
      \ '# Doc',
      \ '',
      \ '[local](sub/target.md)',
      \ '',
      \ '[noext](sub/noext)',
      \ '',
      \ '[alt](sub/alt)',
      \ '',
      \ '[ref][def]',
      \ '',
      \ '[def]: sub/target.md',
      \ '',
      \ '[shortcut]',
      \ '',
      \ '[shortcut]: sub/noext.md',
      \ '',
      \ '[anchor](#section-two)',
      \ '',
      \ '[fileanchor](sub/target.md#target-heading)',
      \ '',
      \ '[line](sub/target.md:3)',
      \ '',
      \ '[abs](' . tmp . '/sub/target.md)',
      \ '',
      \ '[missing](sub/missing.md)',
      \ '',
      \ '[inj](<man://ls|!touch ' . marker . '>)',
      \ '',
      \ '[web](https://example.com)',
      \ '',
      \ '## Section Two',
      \ '',
      \ 'text',
      \ ], tmp . '/a.md')

" Open a throwaway markdown buffer with the plugin's ftplugin sourced.
function! s:MdBuffer(lines) abort
  enew
  call setline(1, a:lines)
  setlocal nomodified
  setfiletype markdown
  execute 'source' fnameescape(g:vmf_root . '/after/ftplugin/markdown.vim')
endfunction

let g:abuf = 0
try
  execute 'edit ' . fnameescape(tmp . '/a.md')
  setfiletype markdown
  execute 'source' fnameescape(g:vmf_root . '/after/ftplugin/markdown.vim')
  let g:abuf = bufnr('%')

  " gx tests: the plugin opens links via a job (no netrw). Capture the argument
  " passed to the opener by writing it to a file.
  let g:vim_markdown_follow_local_opener = ['sh','-c','printf %s "$1" > ' . tmp . '/gx.txt', '--']
  function! GxRead() abort
    sleep 150m
    let f = g:tmp . '/gx.txt'
    return filereadable(f) ? readfile(f, 'b', 1) : []
  endfunction

  let m = maparg('ge', 'n', 0, 1)
  call Check('ge mapped (buffer-local)', get(m, 'buffer', 0) == 1, string(m))
  let m = maparg('gx', 'n', 0, 1)
  call Check('gx mapped (buffer-local)', get(m, 'buffer', 0) == 1, string(m))
  let m = maparg('<CR>', 'n', 0, 1)
  call Check('<CR> not mapped by default', get(m, 'rhs', '') !~# 'MarkdownFollow', string(m))

  call cursor(1, 1)
  call Check('JumpToHeading matches GitHub slug', markdownfollow#JumpToHeading('section-two') && line('.') == 31, line('.'))

  call cursor(3, 3)
  execute 'normal ge'
  call Check('ge opens relative link', bufname('%') =~# 'target.md$' && getline(1) ==# '# Target Heading', expand('%:p'))

  execute 'buffer ' . g:abuf
  call cursor(5, 3)
  execute 'normal ge'
  call Check('ge appends .md', bufname('%') =~# 'noext.md$', expand('%:p'))

  execute 'buffer ' . g:abuf
  call cursor(7, 3)
  execute 'normal ge'
  call Check('ge prefers existing .markdown', bufname('%') =~# 'alt.markdown$', expand('%:p'))

  execute 'buffer ' . g:abuf
  call cursor(9, 3)
  execute 'normal ge'
  call Check('ge follows [text][ref]', bufname('%') =~# 'target.md$', expand('%:p'))

  execute 'buffer ' . g:abuf
  call cursor(13, 3)
  execute 'normal ge'
  call Check('ge follows shortcut reference', bufname('%') =~# 'noext.md$', expand('%:p'))

  execute 'buffer ' . g:abuf
  call cursor(17, 3)
  execute 'normal ge'
  call Check('ge jumps to same-file heading', bufnr('%') == g:abuf && line('.') == 31, line('.'))

  execute 'buffer ' . g:abuf
  call cursor(19, 3)
  execute 'normal ge'
  call Check('ge opens file and jumps to heading', bufname('%') =~# 'target.md$' && line('.') == 1, expand('%:p') . ' @' . line('.'))

  " #14: same-file anchor ge uses a jump motion (G) so CTRL-O returns.
  execute 'buffer ' . g:abuf
  call cursor(17, 3)
  execute 'normal ge'
  execute "normal! \<C-O>"
  call Check('same-file ge records jump (CTRL-O returns)', bufnr('%') == g:abuf && line('.') == 17, 'buf=' . bufnr('%') . ' line=' . line('.'))

  execute 'buffer ' . g:abuf
  call cursor(21, 3)
  execute 'normal ge'
  call Check('ge honors :line suffix', bufname('%') =~# 'target.md$' && line('.') == 3, expand('%:p') . ' @' . line('.'))

  execute 'buffer ' . g:abuf
  call cursor(23, 3)
  execute 'normal ge'
  call Check('ge opens absolute path', R(expand('%:p')) ==# R(tmp . '/sub/target.md'), expand('%:p'))

  execute 'buffer ' . g:abuf
  call cursor(25, 3)
  execute 'normal ge'
  call Check('ge opens new buffer only for truly missing', R(expand('%:p')) ==# R(tmp . '/sub/missing.md'), expand('%:p'))

  " man:// with | is rejected by the whitelist (never reaches :Man).
  execute 'buffer ' . g:abuf
  call cursor(27, 3)
  let g:man_topic = ''
  execute 'normal ge'
  call Check('man:// with | is sanitized', !filereadable(marker) && g:man_topic ==# '', 'topic=' . string(g:man_topic))

  call delete(tmp . '/gx.txt')
  execute 'buffer ' . g:abuf
  call cursor(29, 3)
  execute 'normal gx'
  call Check('gx opens web link', GxRead() ==# ['https://example.com'], string(GxRead()))

  call delete(tmp . '/gx.txt')
  execute 'buffer ' . g:abuf
  call cursor(17, 3)
  execute 'normal gx'
  call Check('gx on #heading jumps (no handler)', GxRead() ==# [] && line('.') == 31, 'line=' . line('.') . ' cap=' . string(GxRead()))

  " Slug handling: CJK, underscore, trailing dash, closing ATX '#'.
  call s:MdBuffer(['# 中文', '', '# foo_bar'])
  call Check('slug keeps CJK', markdownfollow#JumpToHeading('中文') && line('.') == 1, line('.'))
  call Check('slug keeps underscore', markdownfollow#JumpToHeading('foo_bar') && line('.') == 3, line('.'))
  bwipe!
  call s:MdBuffer('# Foo -')
  call Check('slug trims trailing dash', markdownfollow#JumpToHeading('foo') && line('.') == 1, line('.'))
  bwipe!
  call s:MdBuffer('# Foo #')
  call Check('closing ATX hash stripped', markdownfollow#JumpToHeading('foo') && line('.') == 1, line('.'))
  bwipe!

  " Nested parentheses and multi-line inline links.
  call s:MdBuffer('[a](f(1).md)')
  call cursor(1, 2)
  call Check('nested parens parsed', markdownfollow#UrlAtCursor() ==# 'f(1).md', markdownfollow#UrlAtCursor())
  bwipe!
  call s:MdBuffer('[a](/wiki/Article_(disambiguation))')
  call cursor(1, 2)
  call Check('balanced parens parsed', markdownfollow#UrlAtCursor() ==# '/wiki/Article_(disambiguation)', markdownfollow#UrlAtCursor())
  bwipe!
  call s:MdBuffer(['[a](target.md', '"title")'])
  call cursor(1, 2)
  call Check('multi-line inline link parsed', markdownfollow#UrlAtCursor() ==# 'target.md', markdownfollow#UrlAtCursor())
  bwipe!

  " #2: ge on a non-link line keeps <CR> behavior (moves to next line).
  execute 'buffer ' . g:abuf
  call cursor(2, 1)
  execute 'normal ge'
  call Check('ge on non-link moves down', line('.') == 3, line('.'))

  " #3: gx on a bare URL opens <cfile> with the system handler.
  call delete(tmp . '/gx.txt')
  call s:MdBuffer('see https://bare.example.com here')
  call cursor(1, 8)
  execute 'normal gx'
  call Check('gx bare URL opens <cfile>', get(GxRead(), 0, '') =~# 'bare.example.com', string(GxRead()))
  bwipe!

  " #4: web_re requires ://, is case-insensitive, and does not eat filenames.
  call s:MdBuffer('[r](https-release.md)')
  call cursor(1, 2)
  execute 'normal ge'
  call Check('https-release.md treated as local', bufname('%') =~# 'https-release.md$', bufname('%'))
  bwipe!
  call delete(tmp . '/gx.txt')
  call s:MdBuffer('[x](HTTPS://example.com)')
  call cursor(1, 2)
  execute 'normal gx'
  call Check('HTTPS:// recognized as web', GxRead() ==# ['HTTPS://example.com'], string(GxRead()))
  bwipe!

  " #5: reference definition drops title and trailing space.
  call s:MdBuffer(['[ref][d]', '', '[d]: ' . tmp . '/sub/target.md "tip"'])
  call cursor(1, 2)
  execute 'normal ge'
  call Check('reference def drops title', R(expand('%:p')) ==# R(tmp . '/sub/target.md') && getline(1) ==# '# Target Heading', expand('%:p') . ' | ' . getline(1))
  bwipe!

  " #13: reference label matches case-insensitively.
  call s:MdBuffer(['[Foo][BAR]', '[bar]: ' . tmp . '/sub/noext.md'])
  call cursor(1, 2)
  execute 'normal ge'
  call Check('reference label case-insensitive', R(expand('%:p')) ==# R(tmp . '/sub/noext.md'), expand('%:p'))
  bwipe!

  " #11: following a missing directory link does not create it.
  call delete(tmp . '/newdir', 'rf')
  call writefile(['[d](newdir/)'], tmp . '/dirlink.md')
  execute 'edit ' . fnameescape(tmp . '/dirlink.md')
  setfiletype markdown
  execute 'source' fnameescape(g:vmf_root . '/after/ftplugin/markdown.vim')
  call cursor(1, 2)
  execute 'normal ge'
  call Check('missing dir link does not create', !isdirectory(tmp . '/newdir'), tmp . '/newdir')

  " #15: a valid man:// topic reaches :Man.
  call s:MdBuffer('[m](man://printf(3))')
  call cursor(1, 2)
  let g:man_topic = ''
  execute 'normal ge'
  call Check('man:// valid topic reaches :Man', g:man_topic ==# 'printf(3)', string(g:man_topic))
  bwipe!
  " #2: gx on man:// also routes to :Man (consistent with ge).
  call s:MdBuffer('[m](man://printf(3))')
  call cursor(1, 2)
  let g:man_topic = ''
  execute 'normal gx'
  call Check('gx man:// routes to :Man', g:man_topic ==# 'printf(3)', string(g:man_topic))
  bwipe!

  " #1: gx on a local link opens the resolved path with the system handler.
  call delete(tmp . '/gx.txt')
  execute 'buffer ' . g:abuf
  call cursor(3, 3)
  execute 'normal gx'
  call Check('gx opens local link', get(GxRead(), 0, '') =~# 'target.md$', string(GxRead()))

  " Non-markdown buffers are left alone.
  execute 'buffer ' . g:abuf
  enew
  setfiletype text
  call Check('ge unmapped outside markdown', empty(maparg('ge', 'n', 0, 1)), string(maparg('ge', 'n', 0, 1)))
catch
  call add(g:out, 'ABORT ' . v:exception . ' @ ' . v:throwpoint)
finally
  call writefile(g:out, tmp . '/out.txt')
endtry

let s:fails = len(filter(copy(g:out), 'v:val =~# "^FAIL\\|^ABORT"'))
if s:fails
  cquit 1
endif
qa!
