let s:dir = "/" . join(split(expand("<sfile>"), "/")[0:-2], "/")
ruby $dir = VIM::evaluate('s:dir')

"Load guard
if ( exists('g:loaded_ctrlp_similar') && g:loaded_ctrlp_similar )
	\ || v:version < 700 || &cp
	finish
endif
let g:loaded_ctrlp_similar = 1

let var=system('git ls-files')
if v:shell_error !=0
  let s:no_git_repo = 1
else
  ruby load File.join($dir, '../script/init.rb');
endif

call add(g:ctrlp_ext_vars, {
	\ 'init': 'similar#init()',
	\ 'accept': 'similar#accept',
	\ 'lname': 'ctrlp-similar',
	\ 'type': 'line',
	\ 'exit': 'similar#exit()',
	\ 'sort': 0,
	\ })


function! similar#init()
  ruby gen_similar_files
  let s:buffer = ''
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
	call similar#exit()
  call ctrlp#acceptfile(a:mode, str)
endfunction


" (optional) Do something before enterting ctrlp
function! similar#enter()
endfunction


" (optional) Do something after exiting ctrlp
function! similar#exit()
  "Todo -- Logging
endfunction


" (optional) Set or check for user options specific to this extension
function! similar#opts()
endfunction


" Give the extension an ID
let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)

" Allow it to be called later
function! similar#id()
	return s:id
endfunction

function! SimilarWrapper()
  if ( exists('s:no_git_repo') && s:no_git_repo )
    echom 'No git repo present, reverting to vanilla ctrlp'
    call ctrlp#init(0, { 'dir': '' })
    return
  endif
  let s:buffer = expand('%')
  call ctrlp#init(similar#id())
endfunction

" Create a command to directly call the new search type
command! CtrlPSimilar call SimilarWrapper()
