" @Author:      Khoa Nguyen (thanhkhoa.it@gmail.com)
" @Created:     2020-11-03

let g:gmi#loaded = 0
let g:gmi#popup_id = 0
let g:gmi#render_timer_id = 0
let g:gmi#cached_git_logs = { '000000': 'You ➤ Not Committed Yet' }
let g:gmi#modified_time_files = {}
let g:gmi#commit_hash_files = {}
let g:gmi#ignored_files = {}
let g:gmi#current_line_cursor = ''
let g:gmi#current_window_size = ''

let s:ignored_filetypes = ['help', 'qf', 'nerdtree', 'fzf', 'terminal']
let s:prefix = '❥ '
let s:delay_time = 100

if !exists('g:gmi#ignored_filetypes') | let g:gmi#ignored_filetypes = s:ignored_filetypes | endif
if !exists('g:gmi#prefix') | let g:gmi#prefix = s:prefix | endif
if !exists('g:gmi#delay_time') | let g:gmi#delay_time = s:delay_time | endif

if exists('*popup_create')
  autocmd   VimEnter * call s:LoadGitLog()
  autocmd   BufRead,TabEnter * call s:InitPopup()
  autocmd   BufRead,BufWritePost,CursorHold * call s:LoadFileCommits()
  autocmd   CursorMovedI * call s:HideGitMessageInlinePopup()
  autocmd   CursorMoved,VimResized,BufWritePost,WinEnter,CmdlineEnter * call s:DelayToShowPopup()

  call timer_start(g:gmi#delay_time * 4, 'GMIReloading', { 'repeat': -1 })
  call timer_start(g:gmi#delay_time * 4, 'GMIEventScanner', { 'repeat': -1 })
else
  echomsg 'Your vim not support popup'
endif

" Functions
function! s:InitPopup()
  if !exists('*popup_create') | return | endif
  silent call popup_clear()

  hi CommitMessage gui=NONE guibg=NONE guifg=#AAAAAA cterm=NONE ctermbg=NONE ctermfg=59

  let g:gmi#popup_id = popup_create('', #{
      \ pos: 'botleft',
      \ highlight: 'CommitMessage',
      \ zindex: 1,
      \ hidden: 1,
      \ fixed: 1,
      \ wrap: 0,
      \ })
endfunction

function! s:DelayToShowPopup()
  if !s:LineChanged() | return | endif

  call s:HideGitMessageInlinePopup()
  if !empty(timer_info(g:gmi#render_timer_id)) | call timer_stop(g:gmi#render_timer_id) | endif
  let g:gmi#render_timer_id = timer_start(g:gmi#delay_time, 'GMICheckToShow')
endfunction

function! GMIReloading(_timer)
  if !g:gmi#loaded | call s:LoadGitLog() | endif
endfunction

function! GMIEventScanner(_timer)
  if g:gmi#current_window_size != s:WinSize() " WinSize changed
    call GMICheckToShow(a:_timer)
  else
    let g:gmi#current_window_size = s:WinSize()
  endif
endfunction

function! GMICheckToShow(_timer)
  if index(g:gmi#ignored_filetypes, &filetype) >= 0 | return | endif
  if s:IgnoredFile() | return | endif
  if &modified | return | endif
  if !g:gmi#popup_id | call s:InitPopup() | endif

  call s:ShowGitMessageInlinePopup()
endfunction

function! s:ShowGitMessageInlinePopup()
  let l:window_left_position = win_screenpos(0)[1]
  let l:line_length = strwidth(getline('.'))
  let l:window_width = winwidth(0)
  let l:max_width_popup = l:window_width - l:line_length - 8

  if l:max_width_popup <= 5 | call s:HideGitMessageInlinePopup() | return | endif

  let l:message = s:GetGitMessageInline()
  if empty(l:message) | call s:HideGitMessageInlinePopup() | return | endif


  silent call popup_settext(g:gmi#popup_id, g:gmi#prefix . l:message)
  silent call popup_move(g:gmi#popup_id, #{
        \ line: 'cursor',
        \ col: l:line_length + l:window_left_position + 8,
        \ maxwidth: l:max_width_popup,
        \ mask: [[-10, -1, -1, -1]],
        \ })

  if !s:PopupDisplayed() | call popup_show(g:gmi#popup_id) | endif
endfunction

function! s:HideGitMessageInlinePopup()
  if &buftype == 'terminal' | return | endif
  silent call popup_hide(g:gmi#popup_id)
endfunction

function! s:LoadGitLog()
  if g:gmi#loaded | return | endif

  silent let l:git_check_output = split(system('git status'))
  if empty(l:git_check_output) | return | endif
  if (l:git_check_output[0] == 'fatal:') | return | endif

  silent call job_start(["git", "log", "--format=%h✄%an ✧ %ar ➤ %s"], { 'callback': 'AddGitLogToCache' })

  let g:gmi#loaded = 1
endfunction

function! AddGitLogToCache(_channel, commit)
  if a:commit[0:5] == 'fatal:' | return | endif

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
    let g:gmi#ignored_files[l:file_path] = 1 | return 1
  endif

  silent let l:git_command_output = system('git ls-files ' . l:file_path)

  if empty(l:git_command_output)
    let g:gmi#ignored_files[l:file_path] = 1 | return 1
  endif

  if split(l:git_command_output)[0] == 'fatal:'
    let g:gmi#ignored_files[l:file_path] = 1
  endif

  return g:gmi#ignored_files[l:file_path]
endfunction

function! s:PopupDisplayed()
  return popup_getpos(g:gmi#popup_id).visible
endfunction

function! s:LineChanged()
  let l:current_line_cursor = @% . ':' . line('.')
  let l:line_changed = g:gmi#current_line_cursor != l:current_line_cursor
  let g:gmi#current_line_cursor = l:current_line_cursor
  return l:line_changed
endfunction

function! s:WinSize()
  return winwidth(0) . 'x' . winheight(0)
endfunction
