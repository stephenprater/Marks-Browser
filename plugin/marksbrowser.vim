" marks2browser.vim
" Author: Viktor Kojouharov / Stephen Prater
" Version: 0.9
" License: BSD
"
" Description:
" This script provides a graphical browsers of the user marks for the local
" file [a-z] Most of the window management routines are stolen from Buffergator
"
" Help:
" To open the browser, use the :MarksBrowser command
" The select the a mark to jump to, use <CR> or <2-LeftMouse>
" To delete a mark, press d
"
" To have the browser window not close itself after you jump to a mark, set the
" marksCloseWhenSelected in your ~/.vimrc file
" 	Example: let marksCloseWhenSelected = 0
"
" Installation:
" Put this file into your $HOME/.vim/plugin directory.

" Reload and Compatibility Guard {{{1
" ============================================================================
" Reload protection.
if (exists('g:did_marks_browswer') && g:did_marks_browswer) || &cp || version < 700
    finish
endif
let g:did_buffergator = 1

" avoid line continuation issues (see ':help user_41.txt')
let s:save_cpo = &cpo
set cpo&vim
" 1}}}

" Global Plugin Options {{{1
" =============================================================================
if !exists("g:marksbrowser_viewport_split_policy")
    let g:marksbrowser_viewport_split_policy = "L"
endif
if !exists("g:marksbrowser_marks_sort_regime")
    let g:marksbrowser_marks_sort_regime = "name"
endif
if !exists("g:marksbrowser_subdivide_marks")
    let g:marksbrowser_subdivide_marks = 1
endif
if !exists("g:marksbrowser_show_marks_type")
    let g:marksbrowser_show_marks_type = 'bvrf'
endif
if !exists("g:marksbrowser_move_wrap")
    let g:marksbrowser_move_wrap = 1
endif
if !exists("g:marksbrowser_autodismiss_on_select")
    let g:marksbrowser_autodismiss_on_select = 1
endif
if !exists("g:marksbrowser_autoupdate")
    let g:marksbrowser_autoupdate = 1
endif
if !exists("g:marksbrowser_autoexpand_on_split")
    let g:marksbrowser_autoexpand_on_split = 1
endif
if !exists("g:marksbrowser_split_size")
    let g:marksbrowser_split_size = 40
endif
if !exists("g:marksbrowser_display_regime")
    let g:marksbrowser_display_regime = "basename"
endif
if !exists("g:marksbrowser_show_full_directory_path")
    let g:marksbrowser_show_full_directory_path = 1 
endif
if !exists("g:marksbrowser_show_cross_file_marks")
    let g:marksbrowser_show_cross_file_marks
endif
if !exists("g:marksbrowser_listed_marks")
    let g:marksbrowser_listed_marks = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'`^<>\""
endif
"}}}1


" Script Data and Variables {{{1
" =============================================================================

" Split Modes {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" Split modes are indicated by a single letter. Upper-case letters indicate
" that the SCREEN (i.e., the entire application "window" from the operating
" system's perspective) should be split, while lower-case letters indicate
" that the VIEWPORT (i.e., the "window" in Vim's terminology, referring to the
" various subpanels or splits within Vim) should be split.
" Split policy indicators and their corresponding modes are:
"   ``/`d`/`D'  : use default splitting mode
"   `n`/`N`     : NO split, use existing window.
"   `L`         : split SCREEN vertically, with new split on the left
"   `l`         : split VIEWPORT vertically, with new split on the left
"   `R`         : split SCREEN vertically, with new split on the right
"   `r`         : split VIEWPORT vertically, with new split on the right
"   `T`         : split SCREEN horizontally, with new split on the top
"   `t`         : split VIEWPORT horizontally, with new split on the top
"   `B`         : split SCREEN horizontally, with new split on the bottom
"   `b`         : split VIEWPORT horizontally, with new split on the bottom
let s:buffergator_viewport_split_modes = {
            \ "d"   : "sp",
            \ "D"   : "sp",
            \ "N"   : "buffer",
            \ "n"   : "buffer",
            \ "L"   : "topleft vert sbuffer",
            \ "l"   : "leftabove vert sbuffer",
            \ "R"   : "botright vert sbuffer",
            \ "r"   : "rightbelow vert sbuffer",
            \ "T"   : "topleft sbuffer",
            \ "t"   : "leftabove sbuffer",
            \ "B"   : "botright sbuffer",
            \ "b"   : "rightbelow sbuffer",
            \ }
" 2}}}

" Marks Sort Regimes {{{2
" =============================================================================
let s:marksbrowser_sort_regimes = ['lineno', 'name']
let s:marksbrowser_sort_regime_desc = {
  \ 'lineno' : ['lineno',"by mark linenumber"],
  \ 'name'   : ['name', "by mark name"],
  \ }

" }}}2
"
" Marks Subdivide Regims {{{2
let s:marksbrowser_subdivide_regime_desc = {
  \ 'f' : ['File', "marks in other files"],
  \ 'b' : ['Buffer', "marks in this buffer"],
  \ 'v' : ['Vim', "marks set automatically by vim"],
  \ 'r' : ['Recent', "viminfo marks (most recently edited spots)"],
  \}
" }}}2


" Utilities {{{1
" ==============================================================================

" Text Formatting {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function! s:_format_align_left(text, width, fill_char)
    let l:fill = repeat(a:fill_char, a:width-len(a:text))
    return a:text . l:fill
endfunction

function! s:_format_align_right(text, width, fill_char)
    let l:fill = repeat(a:fill_char, a:width-len(a:text))
    return l:fill . a:text
endfunction

function! s:_format_time(secs)
    if exists("*strftime")
        return strftime("%Y-%m-%d %H:%M:%S", a:secs)
    else
        return (localtime() - a:secs) . " secs ago"
    endif
endfunction

function! s:_format_escaped_filename(file)
  if exists('*fnameescape')
    return fnameescape(a:file)
  else
    return escape(a:file," \t\n*?[{`$\\%#'\"|!<")
  endif
endfunction

" trunc: -1 = truncate left, 0 = no truncate, +1 = truncate right
function! s:_format_truncated(str, max_len, trunc)
    if len(a:str) > a:max_len
        if a:trunc > 0
            return strpart(a:str, a:max_len - 4) . " ..."
        elseif a:trunc < 0
            return '... ' . strpart(a:str, len(a:str) - a:max_len + 4)
        endif
    else
        return a:str
    endif
endfunction

" Pads/truncates text to fit a given width.
" align: -1 = align left, 0 = no align, 1 = align right
" trunc: -1 = truncate left, 0 = no truncate, +1 = truncate right
function! s:_format_filled(str, width, align, trunc)
    let l:prepped = a:str
    if a:trunc != 0
        let l:prepped = s:_format_truncated(a:str, a:width, a:trunc)
    endif
    if len(l:prepped) < a:width
        if a:align > 0
            let l:prepped = s:_format_align_right(l:prepped, a:width, " ")
        elseif a:align < 0
            let l:prepped = s:_format_align_left(l:prepped, a:width, " ")
        endif
    endif
    return l:prepped
endfunction

" 2}}}

" Messaging {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function! s:NewMessenger(name)

    " allocate a new pseudo-object
    let l:messenger = {}
    let l:messenger["name"] = a:name
    if empty(a:name)
        let l:messenger["title"] = "buffergator"
    else
        let l:messenger["title"] = "buffergator (" . l:messenger["name"] . ")"
    endif

    function! l:messenger.format_message(leader, msg) dict
        return self.title . ": " . a:leader.a:msg
    endfunction

    function! l:messenger.format_exception( msg) dict
        return a:msg
    endfunction

    function! l:messenger.send_error(msg) dict
        redraw
        echohl ErrorMsg
        echomsg self.format_message("[ERROR] ", a:msg)
        echohl None
    endfunction

    function! l:messenger.send_warning(msg) dict
        redraw
        echohl WarningMsg
        echomsg self.format_message("[WARNING] ", a:msg)
        echohl None
    endfunction

    function! l:messenger.send_status(msg) dict
        redraw
        echohl None
        echomsg self.format_message("", a:msg)
    endfunction

    function! l:messenger.send_info(msg) dict
        redraw
        echohl None
        echo self.format_message("", a:msg)
    endfunction

    return l:messenger

endfunction
" 2}}}

" Sorting {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

" comparison function used for sorting dictionaries by value
function! s:_compare_dicts_by_value(m1, m2, key)
    if a:m1[a:key] < a:m2[a:key]
        return -1
    elseif a:m1[a:key] > a:m2[a:key]
        return 1
    else
        return 0
    endif
endfunction

function! s:_compare_dicts_by_lineno(m1,m2)
  return s:_compare_dicts_by_value(a:m1, a:m2, "lineno")
endfunction

function! s:_compare_dicts_by_name(m1,m2)
  return s:_compare_dicts_by_value(a:m1, a:m2, "name")
endfunction


"}}}2

"}}}1
"
" MarksBrowser {{{1
" ============================================================================

function! s:NewMarksBrowser(name, title)
  " initialize

  let l:marks_browser = {}
  let l:marks_browser["bufname"] = a:name
  let l:marks_browser["title"] = a:title
  let l:marks_browser_bufs = s:_find_buffers_with_var("is_marksbrowser_buffer",1)
  if len(l:marks_browser_bufs) > 0
    let l:marks_browser["bufnum"] = l:buffergator_bufs[0]
  endif
  let l:marks_browser["split_mode"] = s:_get_split_mode()
  let l:marks_browser["sort_regime"] = g:marksbrowser_marks_sort_regime
  let l:marks_browser["subdivide"] = g:marksbrowser_subdivide_marks
  let l:marks_browser["show_types"] = g:marksbrowser_show_marks_type
  let l:marks_browser["is_zoomed"] = 0
  let l:marks_browser["bufnum"] = -1
  let l:marks_browser["max_mark_preview_length"] = 30

  function! l:marks_browser.list_marks() dict
    let mcat = []
    redir => marks_output
      execute('silent marks ' . g:marksbrowser_listed_marks)
    redir END
  
    let l:marks_output_rows = split(l:marks_output,"\n")[1:]
    for l:marks_output_row in l:marks_output_rows
      let l:parts = matchlist('^\s*\([^\s]+\)\s+\(\d+\)\s+\(\d+\)\s+\(.+\)$'
      let l:info = {}
      " 1 mark name
      " 2 line nummber
      " 3 column
      " 4 file or text 
      let l:info["markname"] = l:parts[1]
      if l:info["markname"] =~ '[A-Z]'
        " marks in external files
        l:info["line"] = l:parts[2]
        l:info["filename"] = s:format_filled(split(l:parts[4],"/")[-1], self.max_buffer_basename_len, left, 1)
        l:info["type"] = 'f'
      elseif l:info["markname"] =~ '[0-9]'
        l:info["line"] = l:parts[2]
        l:info["filename"] = s:format_filled(split(l:parts[4],"/")[-1], self.max_buffer_basename_len, left, 1)
        l:info["type"] = 'r'
        " basicaly these are recent edit marks 
      elseif l:info["markname"] =~ '[a-z]'
        l:info["line"] = l:parts[2]
        l:info["preview"] = s:format_filled(l:parts[4],self.max_buffer_basename_len,left,1)
        l:info["type"] = 'b'
        " user marks
      elseif l:info["markname"] =~ '[\[\]\^.<>\'`"]'
        l:info["line"] = l:parts[2]
        l:info["preview"] = s:format_filled(l:parts[4],self.max_buffer_basename_len,left,1)
        l:info["type"] = 'v'
        " automatic vim marks 
      endif
      call add(mcat,l:info)
    endfor

    let l:sort_func = "s:_compare_dicts_by_" . self.sort_regime
    return sort(mcat,l:sort_func)
      ""mark line  col file/text
      "" 0     76   14 ~/.vimrc
      "" 1    154    9 ~/Documents/personal/gadgetsalvage/app/controllers/labels_controller.rb
      "" 2      1    0 ~/california_craftsman.agr.html
      "" 3      3    0 ~/.homesick/repos/stephenprater/vim_config/home/.vim/vundle/vim-buffergator/.git/COMMIT_EDITMSG
      "" 4      4    6 ~/.homesick/repos/stephenprater/vim_config/home/.vim/vundle/vim-buffergator/.git/rebase-merge/git-rebase-todo
      "" 5     18   36 ~/.homesick/repos/stephenprater/vim_config/home/.vim/vundle/vim-buffergator/plugin/buffergator.vim
      "" 6   1761    0 ~/.homesick/repos/stephenprater/vim_config/home/.vim/vundle/vim-buffergator/plugin/buffergator.vim
      "" 7      7    0 ~/Sites/wpro-work/testing/features/12_address_page.feature
      "" 8      1    0 NERD_tree_1
      "" 9    469    0 NERD_tree_1
      "" "      1    0 " marks2browser.vim
      "" [    264    3 
      "" ]    264    4 
      "" ^    264    4 
      "" .    264    3 
      "" <    105    0 
      "" >    105    0   
  endfunction
  
  " Opens viewer if closed, closes viewer if open.
  function! l:marks_browser.toggle() dict
    if self.bufnum < 0 || !bufexists(self.bufnum)
      call self.open()
    else
      let l:bfwn = bufwinnr(self.bufnum)
      if l:bfwn >= 0
        call self.close(1)
      else
        call self.open()
      endif
    endif
  endfunction

  function! l:marks_browser.create_buffer() dict
    " get a new buf reference
    let self.bufnum = bufnr(self.bufname, 1)
    " get a viewport onto it
    call self.activate_viewport()
    " initialize it (includes "claiming" it)
    call self.initialize_buffer()
    " render it
    call self.render_buffer()
  endfunction

  " Opens a viewport on the buffer according, creating it if neccessary
  " according to the spawn mode. Valid buffer number must already have been
  " obtained before this is called.
  function! l:marks_browser.activate_viewport() dict
    let l:bfwn = bufwinnr(self.bufnum)
    if l:bfwn == winnr()
      " viewport wth buffer already active and current
      return
    elseif l:bfwn >= 0
      " viewport with buffer exists, but not current
      execute(l:bfwn . " wincmd w")
    else
      " create viewport
      let self.split_mode = s:_get_split_mode()
      call self.expand_screen()
      execute("silent keepalt keepjumps " . self.split_mode . " " . self.bufnum)
      if g:buffergator_viewport_split_policy =~ '[RrLl]' && g:buffergator_split_size
        execute("vertical resize " . g:buffergator_split_size)
        setlocal winfixwidth
      elseif g:buffergator_viewport_split_policy =~ '[TtBb]' && g:buffergator_split_size
        execute("resize " . g:buffergator_split_size)
        setlocal winfixheight
      endif
    endif
  endfunction

  function! l:marks_browser.initialize_buffer() dict
    call self.claim_buffer()
    call self.setup_buffer_opts()
    call self.setup_buffer_syntax()
    call self.setup_buffer_commands()
    call self.setup_buffer_keymaps()
    call self.setup_buffer_folding()
    call self.setup_buffer_statusline()
  endfunction

  " 'Claims' a buffer by setting it to point at self.
  function! l:marks_browser.claim_buffer() dict
    call setbufvar("%", "is_marksbrowser_buffer", 1)
    call setbufvar("%", "marksbrowser_browser", self)
    call setbufvar("%", "marksbrowser_last_render_time", 0)
  endfunction

  " 'Unclaims' a buffer by stripping all buffergator vars
  function! l:marks_browser.unclaim_buffer() dict
    for l:var in ["is_marksbrowser_buffer",
              \ "marksbrowser_browser",
              \ "marksbrowser_last_render_time",
              \ ]
      if exists("b:" . l:var)
        unlet b:{l:var}
      endif
    endfor
  endfunction

  " Sets buffer options.
  function! l:marks_browser.setup_buffer_opts() dict
      setlocal buftype=nofile
      setlocal noswapfile
      setlocal nowrap
      set bufhidden=hide
      setlocal nobuflisted
      setlocal nolist
      setlocal noinsertmode
      setlocal nonumber
      setlocal cursorline
      setlocal nospell
      setlocal matchpairs=""
  endfunction

  " Sets buffer commands.
  function! l:marks_browser.setup_buffer_commands() dict
    " don't think there are any 
    return
  endfunction

  function! l:marks_browser.disable_editing_keymaps() dict
    """" Disabling of unused modification keys
    for key in [".", "p", "P", "C", "x", "X", "r", "R", "i", "I", "a", "A", "D", "S", "U"]
      try
          execute "nnoremap <buffer> " . key . " <NOP>"
      catch //
      endtry
    endfor
  endfunction

  function! l:marks_browser.close(restore_prev_window) dict
    if self.bufnum < 0 || !bufexists(self.bufnum)
      return
    endif
    call self.contract_screen()
    if a:restore_prev_window
      if !self.is_usable_viewport(winnr("#")) && self.first_usable_viewport() ==# -1
      else
        try
          if !self.is_usable_viewport(winnr("#"))
              execute(self.first_usable_viewport() . "wincmd w")
          else
              execute('wincmd p')
          endif
        catch //
        endtry
      endif
    endif
    execute("bwipe " . self.bufnum)
  endfunction

  function! l:marks_browser.expand_screen() dict
    if has("gui_running") && g:marksbrowser_autoexpand_on_split && g:marksbrowser_split_size
      if g:marksbrowser_viewport_split_policy =~ '[RL]'
        let self.pre_expand_columns = &columns
        let &columns += g:marksbrowser_split_size
        let self.columns_expanded = &columns - self.pre_expand_columns
      else
        let self.columns_expanded = 0
      endif
      if g:markbrowser_viewport_split_policy =~ '[TB]'
        let self.pre_expand_lines = &lines
        let &lines += g:marksbrowser_split_size
        let self.lines_expanded = &lines - self.pre_expand_lines
      else
        let self.lines_expanded = 0
      endif
    endif
  endfunction

  function! l:marks_browser.contract_screen() dict
      if self.columns_expanded
                  \ && &columns - self.columns_expanded > 20
          let new_size  = &columns - self.columns_expanded
          if new_size < self.pre_expand_columns
              let new_size = self.pre_expand_columns
          endif
          let &columns = new_size
      endif
      if self.lines_expanded
                  \ && &lines - self.lines_expanded > 20
          let new_size  = &lines - self.lines_expanded
          if new_size < self.pre_expand_lines
              let new_size = self.pre_expand_lines
          endif
          let &lines = new_size
      endif
  endfunction
    
  function! l:marks_browser.highlight_current_line()
    if self.current_buffer_index
      execute ":" . self.current_buffer_index
    endif
  endfunction

  " Clears the buffer contents.
  function! l:marks_browser.clear_buffer() dict
    call cursor(1, 1)
    exec 'silent! normal! "_dG'
  endfunction
  
  " Rebuilds catalog.
  function! l:marks_browser.rebuild_catalog() dict
    call self.open(1)
  endfunction

  " Populates the buffer list
  function! l:marks_browser.update_buffers_info() dict
    let self.marks_catalog= self.list_marks()
    return self.marks_catalog
  endfunction

  function! l:marks_browser.setup_buffer_syntax() dict
    if has("syntax") && !(exists("b:did_syntax"))
      setlocal ft=marksbuffer
      syn region MarksBrowserLine start='^' keepend oneline end='$'
      syn match MarkTypeLine '^--(Buffer|Files|Vim|Recent)$'containedin=MarksBrowserLine
      syn match MarkNameUser "\[[a-zA-Z]\]" containedin=MarksBrowserLine nextgroup=MarkLineNumber
      syn match MarkNameVim "\[[0-9\"'`.^<>\[\]]\]" containedin=MarksBrowserLine nextgroup=MarkLineNumber
      syn match MarkLineNumber "\d\{-\}\s" containedin=MarksBrowserLine nextgroup=MarkPreview
      syn match MarkPreview ".*$" containedin=MarksBrowserLine

      highlight link MarksTypeLine StatuslineNC
      highlight link MarksNameUser Statement
      highlight link MarksNameVim Constant
      highlight link MarksLineNumber Number
      highlight link MarksPreview Comment
    endif
  endfunction

  function! l:marks_browser.append_line(text, jump_to_bufnum) dict
    let l:line_map = {
          \ "target" : [a:jump_to_bufnum],
          \ }
    if a:0 > 0
      call extend(l:line_map, a:1)
    endif
    let self.jump_map[line("$")] = l:line_map
    call append(line("$")-1, a:text)
  endfunction

  function! l:marks_browser.setup_buffer_statusline() dict
    setlocal statusline="[Marks]"
  endfunction

  function! l:marks_browser.setup_buffer_keymaps() dict
    call self.disable_editing_keymaps()
    noremap <buffer> <silent> <CR> :call b:marksbrowser_browser.jump_to_mark()<CR>
    noremap <buffer> <silent> <2-LeftMouse> call b:marksbrowser_browser.jump_to_mark()<CR>
    noremap <buffer> <silent> d :call b:marksbrowser_browser.delete_current_mark()<CR>
    noremap <buffer> <silent> q :call b:marksbrowser_browser.toggle()<CR>
  endfunction

  function! l:marks_browser.render_buffer() dict
    setlocal modifiable
    call self.claim_buffer()
    call self.clear_buffer()
    call self.setup_buffer_syntax()

    for l:marktype split(g:marksbrowser_show_marks_type,"")
      let l:filtered_marks = filter(self.marks_catalog,"v:val['type'] == " . l:marktype)
      cursor(1,1)
      let l:type_field = "=== " . s:marksbrowser_subdivide_regime_desc[l:marktype][0] . " ==="
      call self.append_line(l:type_field,-1)
      for l:mark in l:filtered_marks
        let l:mark_name = "[" + s:_format_align_right(l:mark.name,3) + "]"
        let l:line_number = s:_format_align_right(l:mark.line,5)


      endfor
    endfor
    
  endfunction

endfunction


com! -nargs=0 MarksBrowser :call <sid>ToggleMarksBrowser()

fun! s:ShowMarksWin(winNo)
  if winnr() != a:winNo
    let lines = s:FetchMarks()
    let lnum = line('.')
    if a:winNo != -1
      call s:switchTo(a:winNo)
    else
      exec "to sp" . escape(s:win_title, ' ')
      let s:bufNo = bufnr('%')
    endif
    call s:setupBindings()
    let s:isShown = 1
    call s:Fill(lines, lnum)
  else
    close
  endif
endf

fun! s:switchTo(winNo)
  exec a:winNo . "wincmd w"
endf

fun! s:Fill(lines, lnum)
  setlocal modifiable
  1,$d _
  let blnum = 0
  let glnum = 0
  let didSeparate = 0
  put =s:Header()
  for item in a:lines
    if didSeparate == 0 && item[2] !~# '[A-Za-z]'
      let didSeparate = 1
      put ='----------------------------------- Special ------------------------------------'
    endif
    put =item[0]
    if item[1] == a:lnum && item[2] =~# '[A-Za-z]'
      let blnum = line('.')
    endif
    if len(s:pos) == 4 && item[1] == s:pos[1]
      let glnum = line('.')
    endif
  endfor
  1d _

  if !blnum
    let blnum = glnum ? glnum : 3
  endif
  call cursor(blnum - 1, 0)

  call s:setupSyntax()
  setlocal nomodifiable
  setlocal nobuflisted
  setlocal nonumber
  setlocal noswapfile
  setlocal buftype=nofile
  setlocal bufhidden=delete
  setlocal noshowcmd
  setlocal nowrap
endf

fun! s:Header()
  return "Mark\tLine\tText"
endf

fun! s:FetchMarks()
  let maxmarks = strlen(s:all_marks)
  let n = 0
  let res = []
  while n < maxmarks
    let c = strpart(s:all_marks, n, 1)
    let lnum = line("'" . c)
    if lnum != 0
      let line = getline(lnum)
      let string = "'" . c . "\t" . lnum . "\t" . line
      call add(res, [string, lnum, c])
    endif
    let n += 1
  endwhile
  return res
endf

fun! s:setupSyntax()
  syn clear
  setlocal ft=marksbuffer

  syn keyword 	MarkHeader 	Mark Line Text
  syn match 	MarkText 	"\%(\d\+\t\)\@<=.\+$"
  syn match 	MarkLine 	"\%(^'.\t\)\@<=\d\+"
  syn match 	MarkMark 	"^'."
  syn match 	MarkSeparator 	"^-\+ Special -\+$"

  hi def link MarkHeader 	Statement
  hi def link MarkMark 		Type
  hi def link MarkLine 		Number
  hi def link MarkText 		Comment
  hi def link MarkSeparator	Special
endf

fun! s:goToMark()
  let line = getline('.')
  if line !~ "^'.\t"
    return
  endif

  let pos = []
  let s:pos = []
  if s:marksCloseWhenSelected
    close
  endif
  call s:switchTo(bufwinnr(s:originalBuff))
  let mark = matchstr(line, "^'.")
  let pos = getpos(mark)
  if len(pos)
    let s:pos = pos
    call setpos('.', pos)
  endif
endf

fun! s:deleteCurrent()
  let line = getline('.')
  if line !~ "^'.\t"
    return
  endif

  let mark = strpart(line, 1, 1)
  if mark == "'" || mark == '`'
    call cursor(line('.') + 1, 0)
    return
  endif
  call s:switchTo(bufwinnr(s:originalBuff))
  if mark =~ '"'
    let mark = '\' . mark
  endif
  exec "delmarks " . mark
  call s:switchTo(bufwinnr(s:bufNo))

  setlocal modifiable
  d _
  setlocal nomodifiable
endf

fun! s:setupBindings()
  noremap <buffer> <silent> <CR> :call <sid>goToMark()<CR>
  noremap <buffer> <silent> <2-LeftMouse> :call <sid>goToMark()<CR>
  noremap <buffer> <silent> d :call <sid>deleteCurrent()<CR>
  noremap <buffer> <silent> q :call <sid>ToggleMarksBrowser()<CR>
endf
