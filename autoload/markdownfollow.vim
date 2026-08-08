"*********************************************************************
" vim-markdown-follow: follow/open Markdown links under the cursor.
" Autoloaded (loaded once). Called from after/ftplugin/markdown.vim.
"
" vim-markdown's syntax groups locate links more precisely when available;
" without it the line text is parsed directly.
"*********************************************************************

" Web URI scheme detection: any 'scheme://' (case-insensitive) or 'mailto:'.
let s:web_re = '^\c\a[a-z0-9+.-]*://\|^\cmailto:'

function! s:SynName(lnum, col) abort
  return synIDattr(synID(a:lnum, a:col, 1), 'name')
endfunction

" Column range [left, right] (1-indexed, inclusive) of the syntax run at col.
function! s:SynRange(lnum, col, syn) abort
  let left = a:col
  while left > 1 && s:SynName(a:lnum, left - 1) ==# a:syn
    let left -= 1
  endwhile
  let last = col([a:lnum, '$']) - 1
  let right = a:col
  while right < last && s:SynName(a:lnum, right + 1) ==# a:syn
    let right += 1
  endwhile
  return [left, right]
endfunction

" Extract the link destination from the content of a link construct (the first
" non-blank token, or the inside of '<...>'; a trailing title is dropped).
function! s:DestFromInner(inner) abort
  let s = substitute(a:inner, '^\_s\+', '', '')
  let s = substitute(s, '\_s\+$', '', '')
  if strlen(s) > 0 && s[0] ==# '<'
    let close = stridx(s, '>')
    if close > 0
      return strpart(s, 1, close - 1)
    endif
  endif
  " The destination ends at the first whitespace (a newline separates it from
  " an optional title when the link is split across lines).
  let sp = match(s, '\_s')
  return sp >= 0 ? strpart(s, 0, sp) : s
endfunction

" Resolve a reference label to the destination of its '[label]: dest' def.
" Labels match case-insensitively (CommonMark); the destination is trimmed and
" titles/trailing whitespace dropped via s:DestFromInner.
function! s:ResolveReference(label) abort
  let pat = '\c^\s*\[\s*' . escape(a:label, '^$.*~/[]\') . '\s*\]:\s*\%(<\([^>]*\)>\|\(\S.*\)\)\s*$'
  let lnum = 1
  while lnum <= line('$')
    let m = matchlist(getline(lnum), pat)
    if !empty(m) && m[0] !=# ''
      return s:DestFromInner(m[1] !=# '' ? m[1] : m[2])
    endif
    let lnum += 1
  endwhile
  return ''
endfunction

" Scan text from `start` for a balanced '(...)' region (the opening '(' is at
" start-1). Parentheses may nest; newlines are allowed. Returns
" [inner_content, close_index] or ['', -1] if unbalanced.
function! s:ScanBalanced(text, start) abort
  let depth = 1
  let i = a:start
  let n = strlen(a:text)
  while i < n
    let ch = a:text[i]
    if ch ==# '('
      let depth += 1
    elseif ch ==# ')'
      let depth -= 1
      if depth == 0
        return [strpart(a:text, a:start, i - a:start), i]
      endif
    endif
    let i += 1
  endwhile
  return ['', -1]
endfunction

" Find an inline link '[label](dest)' in text whose span contains coff (a
" 0-indexed offset). Handles balanced/nested parens and a destination/title
" split across a newline. Returns the destination, or ''.
function! s:InlineLinkInText(text, coff) abort
  let i = 0
  let n = strlen(a:text)
  while i < n
    if a:text[i] ==# '['
      let j = stridx(a:text, ']', i + 1)
      if j < 0
        break
      endif
      if a:text[j + 1] ==# '('
        let [inner, close] = s:ScanBalanced(a:text, j + 2)
        if close >= 0
          if a:coff >= i && a:coff <= close
            let dest = s:DestFromInner(inner)
            if dest !=# ''
              return dest
            endif
          endif
          let i = close + 1
          continue
        endif
      endif
      let i = j + 1
      continue
    endif
    let i += 1
  endwhile
  return ''
endfunction

" Inline link under the cursor at (lnum, col), considering a link split across
" the adjacent line. Returns the destination, or ''.
function! s:InlineLinkAt(lnum, col) abort
  let line = getline(a:lnum)
  let coff = a:col - 1
  let dest = s:InlineLinkInText(line, coff)
  if dest !=# '' | return dest | endif
  if a:lnum < line('$')
    let dest = s:InlineLinkInText(line . "\n" . getline(a:lnum + 1), coff)
    if dest !=# '' | return dest | endif
  endif
  if a:lnum > 1
    let prev = getline(a:lnum - 1)
    let dest = s:InlineLinkInText(prev . "\n" . line, strlen(prev) + 1 + coff)
    if dest !=# '' | return dest | endif
  endif
  return ''
endfunction

" Parse a link under the cursor at (lnum, col): inline first (char-level),
" then reference links on the line. Returns the destination, or ''.
function! s:UrlFromConstruct(lnum, col) abort
  let dest = s:InlineLinkAt(a:lnum, a:col)
  if dest !=# '' | return dest | endif

  let line = getline(a:lnum)
  let c = a:col - 1
  " Full/collapsed reference: [text][label] / [text][]
  let pos = 0
  while 1
    let start = match(line, '\m\[\([^]]*\)\]\[\([^]]*\)\]', pos)
    if start < 0 | break | endif
    let m = matchlist(line, '\m\[\([^]]*\)\]\[\([^]]*\)\]', pos)
    if c >= start && c < start + strlen(m[0])
      let label = m[2] !=# '' ? m[2] : m[1]
      let d = s:ResolveReference(label)
      if d !=# '' | return d | endif
    endif
    let pos = start + 1
  endwhile
  " Shortcut reference: [label]
  let pos = 0
  while 1
    let start = match(line, '\m\[\([^]]*\)\]', pos)
    if start < 0 | break | endif
    let m = matchlist(line, '\m\[\([^]]*\)\]', pos)
    if c >= start && c < start + strlen(m[0])
      let d = s:ResolveReference(m[1])
      if d !=# '' | return d | endif
    endif
    let pos = start + 1
  endwhile
  return ''
endfunction

" Public: link destination under the cursor, or ''.
function! markdownfollow#UrlAtCursor() abort
  let lnum = line('.')
  let col = col('.')
  let line = getline(lnum)
  let syn = s:SynName(lnum, col)

  if syn ==# 'mkdDelimiter'
    let ch = line[col - 1]
    if ch ==# '<' | let col += 1
    elseif ch ==# '>' || ch ==# ')' | let col -= 1 | endif
    let syn = s:SynName(lnum, col)
  endif

  if index(['mkdInlineURL', 'mkdURL', 'mkdLinkDefTarget'], syn) >= 0
    let [l, r] = s:SynRange(lnum, col, syn)
    return strpart(line, l - 1, r - l + 1)
  endif

  return s:UrlFromConstruct(lnum, col)
endfunction

" GitHub-style slug: lowercase, drop ASCII punctuation (keeping '_', '-', and
" non-ASCII bytes), whitespace run -> '-', trim leading/trailing '-'.
function! s:Slugify(text) abort
  let t = tolower(a:text)
  let t = substitute(t, "[^a-z0-9 _\\x80-\\xff-]", '', 'g')
  let t = substitute(t, '\s\+', '-', 'g')
  let t = substitute(t, '^-\+\|-\+$', '', 'g')
  return t
endfunction

" Public: jump to the heading whose slug matches anchor; returns 1 if found.
function! markdownfollow#JumpToHeading(anchor) abort
  let want = s:Slugify(a:anchor)
  let lnum = 1
  while lnum <= line('$')
    let heading = matchstr(getline(lnum), '^#\+\s*\zs.*\ze\s*$')
    " Strip a closing ATX '#': `# Foo #` -> `Foo`.
    let heading = substitute(heading, '\s*#\+\s*$', '', '')
    if heading !=# '' && s:Slugify(heading) ==# want
      execute 'normal! ' . lnum . 'G'
      normal! zt
      return 1
    endif
    let lnum += 1
  endwhile
  return 0
endfunction

" Open a path or URL with the system handler (open / xdg-open / cmd start),
" via a job argument list (no shell) so metacharacters are safe. Avoids netrw,
" which may be disabled (e.g. by NvimTree).
function! s:OpenLocal(path) abort
  let custom = get(g:, 'vim_markdown_follow_local_opener', [])
  let cmd = empty(custom)
        \ ? (has('macunix') ? ['open', a:path]
        \    : has('win32') ? ['cmd.exe', '/c', 'start', '', a:path]
        \    : ['xdg-open', a:path])
        \ : add(copy(custom), a:path)
  if exists('*jobstart')
    call jobstart(cmd)
  elseif exists('*job_start')
    call job_start(cmd)
  else
    echohl WarningMsg
    echom 'vim-markdown-follow: opening local links needs job support'
    echohl None
  endif
endfunction

" Split 'file.md#heading' -> ['file.md', 'heading']; '#h' -> ['', 'h'].
function! s:SplitAnchor(url) abort
  let idx = stridx(a:url, '#')
  if idx < 0 | return [a:url, ''] | endif
  return [strpart(a:url, 0, idx), strpart(a:url, idx + 1)]
endfunction

" Resolve a link path to an absolute path, relative to the file's directory.
function! s:ResolvePath(path) abort
  if a:path =~# '^\~/'
    return $HOME . strpart(a:path, 1)
  endif
  if a:path =~# '^\~[A-Za-z0-9_.-]*/'
    return expand(a:path)
  endif
  if a:path =~# '^/' || a:path =~# '^[A-Za-z]:[\\/]'
    return a:path
  endif
  let dir = expand('%:p:h')
  if dir ==# '' | let dir = getcwd() | endif
  return dir . '/' . a:path
endfunction

" Peel a trailing ':line' suffix; ['path', '42'] or [path, ''].
function! s:SplitLine(full) abort
  let m = matchlist(a:full, '\(.\+\):\(\d\+\)$')
  if !empty(m) | return [m[1], m[2]] | endif
  return [a:full, '']
endfunction

" Append a markdown extension only if the bare target does not exist.
function! s:MaybeAppendExt(full) abort
  if a:full =~# '\.\(md\|markdown\)$' || filereadable(a:full) || isdirectory(a:full)
    return a:full
  endif
  if filereadable(a:full . '.md') | return a:full . '.md' | endif
  if filereadable(a:full . '.markdown') | return a:full . '.markdown' | endif
  return a:full . '.md'
endfunction

" Warn that a directory link target does not exist (navigation never creates).
function! s:WarnMissingDir(dir) abort
  echohl WarningMsg
  echom 'vim-markdown-follow: directory does not exist: ' . a:dir
  echohl None
endfunction

" Public: follow the link under the cursor inside Vim (edit the target).
function! markdownfollow#Follow() abort
  let url = markdownfollow#UrlAtCursor()
  if url ==# ''
    " Not on a link: advance one line (first non-blank) so the mapping is not a no-op.
    normal! +
    return
  endif

  " man:// before the generic scheme:// check, which would otherwise match it.
  if strpart(url, 0, 6) ==# 'man://'
    let topic = strpart(url, 6)
    if topic =~# '^[A-Za-z0-9_+.\- ()]\+$' && exists(':Man') == 2
      execute 'Man' topic
    endif
    return
  endif

  if url =~# s:web_re
    call s:OpenLocal(url)
    return
  endif

  let [path, anchor] = s:SplitAnchor(url)
  if path ==# ''
    if anchor !=# ''
      call markdownfollow#JumpToHeading(anchor)
    endif
    return
  endif

  let full = s:ResolvePath(path)
  let [full, lnum] = s:SplitLine(full)

  if full =~# '[/\\]$'
    let dir = substitute(full, '[/\\]$', '', '')
    if isdirectory(dir)
      execute 'edit' fnameescape(dir)
    else
      call s:WarnMissingDir(dir)
    endif
  else
    let full = s:MaybeAppendExt(full)
    execute 'edit' . (lnum !=# '' ? ' +' . lnum : '') . ' ' . fnameescape(full)
  endif

  if anchor !=# ''
    call markdownfollow#JumpToHeading(anchor)
  endif
endfunction

" Public: open the link under the cursor with the system handler (browser, file manager, …).
function! markdownfollow#Open() abort
  let url = markdownfollow#UrlAtCursor()
  if url ==# ''
    " Not on a link: open the <cfile> under the cursor with the system handler.
    call s:OpenLocal(expand('<cfile>'))
    return
  endif

  if url =~# s:web_re || strpart(url, 0, 6) ==# 'man://'
    call s:OpenLocal(url)
    return
  endif

  let [path, anchor] = s:SplitAnchor(url)
  if path ==# ''
    if anchor !=# ''
      call markdownfollow#JumpToHeading(anchor)
    endif
    return
  endif

  let full = s:ResolvePath(path)
  let [full, lnum] = s:SplitLine(full)
  if full =~# '[/\\]$'
    let dir = substitute(full, '[/\\]$', '', '')
    if isdirectory(dir)
      call s:OpenLocal(dir)
    else
      call s:WarnMissingDir(dir)
    endif
    return
  endif
  let full = s:MaybeAppendExt(full)
  call s:OpenLocal(full)
endfunction
