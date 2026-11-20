# github-permalink.vim

A small Vim9script plugin that copies a permanent GitHub link for the current line or a visual line selection.

The link uses the repository's current `HEAD` commit instead of a branch name:

```text
https://github.com/owner/repository/blob/<commit>/path/to/file#L10-L14
```

## Requirements

- Vim 9 with Vim9script support
- Git
- A repository with at least one remote hosted on `github.com`
- The current file must be tracked and unchanged from `HEAD`

The last requirement prevents a line number from pointing at different code in the committed file.

## Installation

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'torrefatto/github-permalink'
```

Then run:

```vim
:PlugInstall
```

## Usage

The plugin provides a command and `<Plug>` mapping, but no default key binding.

```vim
nmap <Leader>gy <Plug>(github-permalink)
xmap <Leader>gy <Plug>(github-permalink)
```

- In normal mode, `<Leader>gy` copies a permalink for the current line.
- In visual mode, select one or more lines and press `<Leader>gy` to copy a line range.
- `:GitHubPermalink` copies a link for the current line.
- `:'<,'>GitHubPermalink` copies a link for the selected range.

The URL is written to the unnamed register and, when Vim has clipboard support, the `+` register.

## Supported remote formats

```text
git@github.com:owner/repository.git
ssh://git@github.com/owner/repository.git
https://github.com/owner/repository.git
http://github.com/owner/repository.git
git://github.com/owner/repository.git
```

If `origin` is hosted on GitHub, it is preferred. Otherwise, the first GitHub remote is used.

## Testing

```sh
make test
```

## License

MIT
