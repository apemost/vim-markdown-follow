# vim-markdown-follow

Follow Markdown links under the cursor with `ge` / `gx`.

## Features

- **`ge`** — follow the link inside Vim (edit the target).
- **`gx`** — open the link with the system handler (browser, file manager, …).

Supported targets:

- Relative and absolute paths, and `~`: `[a](dir/file.md)`, `[a](/abs/file.md)`, `[a](~/file.md)`.
- Extensionless links: `[a](file)` opens `file.md` (or `file.markdown`).
- Heading anchors: `[a](file.md#heading)` and `[a](#heading)` jump to the heading (GitHub-style slugs).
- Line numbers: `[a](file.md:42)` opens the file at line 42.
- Reference links: `[a][ref]`, `[a][]`, and `[ref]`.
- Web links like `[a](https://example.com)` open in the browser.
- `man://topic` opens the topic with `:Man`.

Relative paths resolve against the current file's directory. `:Man` arguments are sanitized.

## Requirements

- Vim 8.0+ or Neovim 0.2+.

## Installation

**[vim-plug](https://github.com/junegunn/vim-plug)**

```vim
Plug 'apemost/vim-markdown-follow'
```

**[lazy.nvim](https://github.com/folke/lazy.nvim)**

```lua
{ 'apemost/vim-markdown-follow', ft = 'markdown' }
```

## Configuration

Defaults map `ge` and `gx` in Markdown buffers. You may also map `<CR>` to
follow links:

```vim
autocmd FileType markdown nmap <buffer> <CR> <Plug>(MarkdownFollow)
```

To disable the defaults and bind your own keys:

```vim
let g:vim_markdown_follow_no_default_maps = 1
autocmd FileType markdown nmap <buffer> ge <Plug>(MarkdownFollow)
autocmd FileType markdown nmap <buffer> gx <Plug>(MarkdownFollowOpen)
```

| Plug mapping                 | Action                       |
| ---------------------------- | ---------------------------- |
| `<Plug>(MarkdownFollow)`     | Follow the link inside Vim   |
| `<Plug>(MarkdownFollowOpen)` | Open with the system handler |

## Acknowledgements

Inspired by [`follow-md-links.nvim`](https://github.com/jghauser/follow-md-links.nvim).
Reference-link and anchor handling follow [`preservim/vim-markdown`](https://github.com/preservim/vim-markdown)'s approach.

## Related projects

- [`jghauser/follow-md-links.nvim`](https://github.com/jghauser/follow-md-links.nvim): follow Markdown links in Neovim.
- [`prashanthellina/follow-markdown-links`](https://github.com/prashanthellina/follow-markdown-links): follow Markdown links in Vim.
- [`preservim/vim-markdown`](https://github.com/preservim/vim-markdown): Markdown syntax and folding.
- [`tadmccorkle/markdown.nvim`](https://github.com/tadmccorkle/markdown.nvim): a Markdown toolkit for Neovim.

## License

[MIT](LICENSE)
