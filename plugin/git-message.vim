" @Author:      Khoa Nguyen (thanhkhoa.it@gmail.com)
" @Created:     2020-11-03

autocmd   VimEnter * call s:LoadGitLog()
autocmd   BufRead,TabEnter * call s:InitPopup()
autocmd   BufRead,BufWritePost,CursorHold * call s:LoadFileCommits()
autocmd   CursorMovedI * call s:HideGitMessageInlinePopup()
autocmd   CursorMoved * call s:ShowGitMessageInlinePopup()

let g:gmi#popup_id = 0
let g:gmi#cached_git_logs = { '000000': 'Not Committed Yet' }
let g:gmi#modified_time_files = {}
let g:gmi#commit_hash_files = {}
let g:gmi#ignored_files = {}

let s:ignored_filetypes = ['help', 'qf', 'nerdtree', 'fzf']
if !exists('g:gmi#ignored_filetypes') | let g:gmi#ignored_filetypes = s:ignored_filetypes | endif

" Functions
function! s:InitPopup()
  silent call popup_close(g:gmi#popup_id)
  let g:gmi#popup_id = popup_create('', #{
      \ pos: 'botright',
      \ highlight: 'CommitMessage',
      \ hidden: 1
      \ })
endfunction

function! s:ShowGitMessageInlinePopup()
  if index(g:gmi#ignored_filetypes, &filetype) >= 0 | return | endif
  if s:IgnoredFile() | return | endif
  if &modified | return | endif
  if !g:gmi#popup_id | return | endif

  let l:line_length = strwidth(getline('.'))
  let l:window_width = winwidth(0)
  let l:window_left_position = win_screenpos(0)[1]

  let l:message = s:GetGitMessageInline()
  if empty(l:message) | silent call s:HideGitMessageInlinePopup() | return | endif

  if (l:window_width - l:line_length - len(l:message)) < 10
    let l:message = split(l:message, ' ➤ ')

    if (l:window_width - l:line_length - len(l:message[len(l:message) - 1])) < 10
      call s:HideGitMessageInlinePopup()
      return
    endif
  end

  silent call popup_settext(g:gmi#popup_id, l:message)
  silent call popup_move(g:gmi#popup_id, #{
        \ line: 'cursor',
        \ col: l:window_width + l:window_left_position - 2
        \ })

  if !s:PopupDisplayed() | silent call popup_show(g:gmi#popup_id) | endif
endfunction

function! s:HideGitMessageInlinePopup()
  silent call popup_hide(g:gmi#popup_id)
endfunction

function! s:LoadGitLog()
  silent let l:git_check_output = split(system('git status'))
  if empty(l:git_check_output) | return | endif
  if (l:git_check_output[0] == 'fatal:') | return | endif

  silent call job_start(["git", "log", "--format=%h✄%an ✧ %ar ➤ %s"], { 'callback': 'AddGitLogToCache' })
endfunction

function! AddGitLogToCache(_channel, commit)
  let [hash, info] = split(a:commit, '✄')
  let g:gmi#cached_git_logs[hash[1:6]] = info
endfunction

function! s:LoadFileCommits()
  if s:IgnoredFile() | return | endif

  let l:file_path = expand('%:p')

  if (has_key(g:gmi#modified_time_files, l:file_path) && (getftime(l:file_path) == g:gmi#modified_time_files[l:file_path])) | return | endif

  let g:gmi#modified_time_files[l:file_path] = getftime(l:file_path)

  let l:git_command = 'git blame --abbrev=9 ' . l:file_path
  silent let l:lines = split(system(l:git_command), '\n')

  let g:gmi#commit_hash_files[l:file_path] = []
  for line in l:lines
    silent call add(g:gmi#commit_hash_files[l:file_path], split(line)[0][1:6])
  endfor
endfunction

function! s:GetGitMessageInline()
  if s:IgnoredFile() | return | endif

  let l:file_path = expand('%:p')
  let l:line_number = line('.') - 1

  if !has_key(g:gmi#commit_hash_files, l:file_path) | return | endif
  if len(g:gmi#commit_hash_files[l:file_path]) < l:line_number | return | endif

  let l:commit_id = g:gmi#commit_hash_files[l:file_path][l:line_number]
  if !has_key(g:gmi#cached_git_logs, l:commit_id) | return | endif

  return g:gmi#cached_git_logs[l:commit_id]
endfunction

function! s:IgnoredFile()
  let l:file_path = expand('%:p')

  if has_key(g:gmi#ignored_files, l:file_path) | return g:gmi#ignored_files[l:file_path] | endif

  let g:gmi#ignored_files[l:file_path] = 0

  if !filereadable(l:file_path)
    let g:gmi#ignored_files[l:file_path] = 1
    return 1
  endif

  silent let l:git_command_output = system('git ls-files ' . l:file_path)

  if empty(l:git_command_output)
    let g:gmi#ignored_files[l:file_path] = 1
    return 1
  endif

  if split(l:git_command_output)[0] == 'fatal:'
    let g:gmi#ignored_files[l:file_path] = 1
  endif

  return g:gmi#ignored_files[l:file_path]
endfunction

function! s:PopupDisplayed()
  return popup_getpos(g:gmi#popup_id).visible
endfunction

" Styles
hi CommitMessage gui=NONE guibg=NONE guifg=#AAAAAA cterm=NONE ctermbg=NONE ctermfg=59
