# Git commit message inline VIM Plugin

### Installation

Recommended installation with `vundle`:

```vim
  Plugin 'ThanhKhoaIT/git-message.vim'
```

### Configuration
#### Ignore file-types to display git message
Overwrite the `g:gmi_ignored_filetypes` variable

Example: (it is Default)
```vim
let g:gmi_ignored_filetypes = ['help', 'qf', 'nerdtree', 'fzf']
```
