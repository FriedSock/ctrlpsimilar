let s:dir = "/" . join(split(expand("<sfile>"), "/")[0:-2], "/")
ruby $dir = VIM::evaluate('s:dir')
ruby load File.join($dir, 'init.rb');

"Load guard
if ( exists('g:loaded_ctrlp_similar') && g:loaded_ctrlp_similar )
	\ || v:version < 700 || &cp
	finish
endif
let g:loaded_ctrlp_similar = 1

call add(g:ctrlp_ext_vars, {
	\ 'init': 'similar#init()',
	\ 'accept': 'similar#accept',
	\ 'lname': 'ctrlp-similar',
	\ 'sname': 'c-similar',
	\ 'type': 'line',
	\ 'enter': 'similar#enter()',
	\ 'exit': 'similar#exit()',
	\ 'opts': 'similar#opts()',
	\ 'sort': 0,
	\ 'specinput': 0,
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
	call similar#exit()
  "edit split(a:str)[0]
  echom a:mode
endfunction


" (optional) Do something before enterting ctrlp
function! similar#enter()
endfunction


" (optional) Do something after exiting ctrlp
function! similar#exit()
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
  let s:buffer = expand('%')
  call ctrlp#init(similar#id())
endfunction

" Create a command to directly call the new search type
command! CP call SimilarWrapper()
