let s:dir = "/" . join(split(expand("<sfile>"), "/")[0:-2], "/")
ruby $dir = VIM::evaluate('s:dir')

"Load guard
if ( exists('g:loaded_ctrlp_similar') && g:loaded_ctrlp_similar )
	\ || v:version < 700 || &cp
	finish
endif
let g:loaded_ctrlp_similar = 1

let var = system('git ls-files')
if v:shell_error !=0
  let s:no_git_repo = 1
else
  ruby load File.join($dir, '../script/init.rb');
  ruby load File.join($dir, '../script/logging.rb');
  ruby load File.join($dir, '../script/repo_manager.rb');
endif

call add(g:ctrlp_ext_vars, {
	\ 'init': 'similar#init()',
	\ 'accept': 'similar#accept',
	\ 'lname': 'ctrlp-similar',
	\ 'type': 'line',
	\ 'sort': 0,
	\ })
"

function! similar#open_files()
  redir => var
  silent buffers
  redir END
  return map(filter(map(split(var, '\n'), 'split(v:val)'), 'v:val[1] ==# ''%a'' || v:val[1] ==# ''a'''), 'substitute(join(v:val[2:-3]), ''"'', '''', ''g'')')
endfunction

function! similar#focussed_file()
  redir => var
  silent buffers
  redir END
  let focussed_file = map(filter(map(split(var, '\n'), 'split(v:val)'), 'v:val[1] ==# ''%a'''), 'substitute(join(v:val[2:-3]), ''"'', '''', ''g'')')
  return len(focussed_file) ? focussed_file[0] : ''
endfunction

function! similar#init()
  ruby gen_similar_files
  let open_files = similar#open_files()
  call filter(s:ctrlp_similar_files, 'index(open_files, split(v:val)[0]) < 0')
  return s:ctrlp_similar_files
endfunction


" The action to perform on the selected string
"
" Arguments:
"  a:mode   the mode that has been chosen by pressing <cr> <c-v> <c-t> or <c-x>
"           the values are 'e', 'v', 't' and 'h', respectively
"  a:str    the selected string
"
function! similar#accept(mode, str)
	" For this example, just exit ctrlp and run help
  let str = split(a:str)[0]
  call ctrlp#exit()
  call ctrlp#acceptfile(a:mode, str)
  execute 'ruby log_action ''' . str . ''''
endfunction

" Give the extension an ID
let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)

" Allow it to be called later
function! similar#id()
	return s:id
endfunction

function! SimilarWrapper()
  if (!exists('s:repo_is_initialized') || !s:repo_is_initialized)
    echom 'Repo not initialized, reverting to vanilla ctrlp'
    call ctrlp#init(0, { 'dir': '' })
    return
  endif

  ruby determine_if_matrix_has_been_built

  if  (!s:matrix_built)
    echom 'Model for current revision not ready yet, reverting to vanilla ctrlp'
    call ctrlp#init(0, { 'dir': '' })
    return
  endif

  if ( exists('s:no_git_repo') && s:no_git_repo )
    echom 'No git repo present, reverting to vanilla ctrlp'
    call ctrlp#init(0, { 'dir': '' })
    return
  endif


  let mod = system('cd "$(git rev-parse --show-toplevel)"; git ls-files --full-name -m')
  let s:focussed_file = similar#focussed_file()
  let s:full_name = expand('%:p')
  call system('git blame ' . s:full_name)

  if mod ==# '' && (s:focussed_file ==# '' || v:shell_error != 0)
    let s:no_modified = 1
    echom 'No files have been modified, reverting to vanilla ctrlp'
    call ctrlp#init(0, { 'dir': '' })
    return
  endif
  call ctrlp#init(similar#id())
endfunction

function! similar#add_repo()
  ruby add_repo
endfunction

function! similar#determine_if_repo_is_initialized()
  ruby determine_if_repo_is_initialized
endfunction

function! similar#update_model_if_needed()
  if (s:repo_is_initialized)
    ruby update_model_if_needed
  endif
endfunction

augroup ctrlpsimilarinit
  autocmd!
  au VimEnter * :call similar#determine_if_repo_is_initialized()
  au VimEnter * :call similar#update_model_if_needed()
augroup END

" Create a command to directly call the new search type
command! CtrlPSimilar call SimilarWrapper()
command! AddCtrlPSimilarRepo call similar#add_repo()
