" @Author:      Khoa Nguyen (thanhkhoa.it@gmail.com)
" @Created:     2020-11-03

autocmd   BufRead * call s:CacheCommitMessages()
autocmd   BufRead,BufWritePost,CursorHold * call s:CacheFileCommitIDs()
autocmd   CursorMoved * call s:ShowGitMessageInlinePopup()
autocmd   CursorMovedI * call s:HideGitMessageInlinePopup()
autocmd   TabEnter * call s:ReInitPopup()

let g:gitCommitMessagesCached = {}
let g:fileModifiedCached = {}
let g:commitIDsCached = {}
let g:ignoredFilesCached = {}
let g:gitMessageInlinePopupID = popup_create('', #{
      \ pos: 'topright',
      \ highlight: 'CommitMessage',
      \ hidden: 1
      \ })

let s:ignored_filetypes = ['help', 'qf', 'nerdtree', 'fzf']
if !exists('g:gmi_ignored_filetypes')
  let g:gmi_ignored_filetypes = s:ignored_filetypes
endif

function! s:ShowGitMessageInlinePopup()
  if index(g:gmi_ignored_filetypes, &filetype) >= 0 | return | endif
  if s:IgnoredFile() | return | endif
  if &modified | return | endif
  if !g:gitMessageInlinePopupID | return | endif

  let l:currentLineLength = strwidth(getline('.'))
  let l:currentWindowWidth = winwidth(0)
  let l:currentWindowLeft = win_screenpos(0)[1]

  let l:message = s:GetGitMessageInline()

  if empty(l:message) | return | endif

  let l:toHide = (l:currentWindowWidth - l:currentLineLength - len(l:message)) < 10
  if l:toHide | silent call popup_hide(g:gitMessageInlinePopupID) | return | endif

  silent call popup_settext(g:gitMessageInlinePopupID, l:message)
  silent call popup_move(g:gitMessageInlinePopupID, #{
        \ line: 'cursor',
        \ col: l:currentWindowWidth + l:currentWindowLeft - 2
        \ })

  if !s:PopupDisplayed() | silent call popup_show(g:gitMessageInlinePopupID) | endif
endfunction

function! s:HideGitMessageInlinePopup()
  call popup_hide(g:gitMessageInlinePopupID)
endfunction

function! s:ReInitPopup()
  call popup_close(g:gitMessageInlinePopupID)
  let g:gitMessageInlinePopupID = popup_create('', #{
      \ pos: 'topright',
      \ highlight: 'CommitMessage',
      \ hidden: 1
      \ })
endfunction

" Functions
function! s:CacheCommitMessages()
  if s:IgnoredFile() | return | endif

  let l:filePath = expand('%:p')
  let l:gitCommand = "git log --format='%h✄%an ✧ %ar ➤ %s' " . l:filePath

  silent let l:gitCommits = split(system(l:gitCommand), '\n')

  if l:gitCommits[0][0:5] == 'fatal:' | return | endif

  for commit in l:gitCommits
    let commitData = split(commit, '✄')
    let g:gitCommitMessagesCached[commitData[0]] = commitData[1]
  endfor
endfunction

function! s:CacheFileCommitIDs()
  let l:filePath = expand('%:p')
  if s:IgnoredFile() | return | endif

  if (has_key(g:fileModifiedCached, l:filePath) && (getftime(l:filePath) == g:fileModifiedCached[l:filePath])) | return | endif

  let g:fileModifiedCached[l:filePath] = getftime(l:filePath)

  let l:gitCommand = "git blame --abbrev=9 " . l:filePath
  silent let l:commitAllLines = split(system(l:gitCommand), '\n')

  let g:commitIDsCached[l:filePath] = []

  for line in l:commitAllLines
    let l:commitID = split(line)[0]
    if l:commitID[0] == '^'
      call add(g:commitIDsCached[l:filePath], l:commitID[1:9])
    else
      call add(g:commitIDsCached[l:filePath], l:commitID[0:8])
    endif
  endfor
endfunction

function! s:GetGitMessageInline()
  if s:IgnoredFile() | return | endif

  let l:filePath = expand('%:p')
  let l:lineNr = line('.') - 1

  if !has_key(g:commitIDsCached, l:filePath) | return | endif
  if len(g:commitIDsCached[l:filePath]) < l:lineNr | return | endif

  let l:commitID = g:commitIDsCached[l:filePath][l:lineNr]

  if l:commitID == '000000000' | return 'Not Committed Yet' | endif
  if !has_key(g:gitCommitMessagesCached, l:commitID) | return '' | endif

  return g:gitCommitMessagesCached[l:commitID]
endfunction

function! s:IgnoredFile()
  let l:filePath = expand('%:p')

  if has_key(g:ignoredFilesCached, l:filePath) | return g:ignoredFilesCached[l:filePath] | endif

  let g:ignoredFilesCached[l:filePath] = 0

  if !filereadable(l:filePath)
    let g:ignoredFilesCached[l:filePath] = 1
    return 1
  endif

  silent let l:gitCommandOutput = system("git ls-files " . l:filePath)

  if empty(l:gitCommandOutput)
    let g:ignoredFilesCached[l:filePath] = 1
    return 1
  endif

  if split(l:gitCommandOutput)[0] == 'fatal:'
    let g:ignoredFilesCached[l:filePath] = 1
  endif

  return g:ignoredFilesCached[l:filePath]
endfunction

function! s:PopupDisplayed()
  return popup_getpos(g:gitMessageInlinePopupID).visible
endfunction

" Styles
hi CommitMessage gui=NONE guibg=NONE guifg=#AAAAAA cterm=NONE ctermbg=NONE ctermfg=59
