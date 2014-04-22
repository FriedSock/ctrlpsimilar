let s:dir = "/" . join(split(expand("<sfile>"), "/")[0:-2], "/")
ruby $dir = VIM::evaluate('s:dir')
ruby load File.join($dir, 'init.rb');
"ruby load File.join($dir, 'puts.rb');

"Load guard
if ( exists('g:loaded_ctrlp_sample') && g:loaded_ctrlp_sample )
	\ || v:version < 700 || &cp
	finish
endif
let g:loaded_ctrlp_sample = 1

call add(g:ctrlp_ext_vars, {
	\ 'init': 'sample#init()',
	\ 'accept': 'sample#accept',
	\ 'lname': 'ctrl-similar',
	\ 'sname': 'shortname',
	\ 'type': 'line',
	\ 'enter': 'sample#enter()',
	\ 'exit': 'sample#exit()',
	\ 'opts': 'sample#opts()',
	\ 'sort': 0,
	\ 'specinput': 0,
	\ })


let g:nice_string = ['11']
function! sample#init()
	return g:nice_string
endfunction


" The action to perform on the selected string
"
" Arguments:
"  a:mode   the mode that has been chosen by pressing <cr> <c-v> <c-t> or <c-x>
"           the values are 'e', 'v', 't' and 'h', respectively
"  a:str    the selected string
"
function! sample#accept(mode, str)
	" For this example, just exit ctrlp and run help
	call sample#exit()
	echom a:str
endfunction


" (optional) Do something before enterting ctrlp
function! sample#enter()
endfunction


" (optional) Do something after exiting ctrlp
function! sample#exit()
endfunction


" (optional) Set or check for user options specific to this extension
function! sample#opts()
endfunction


" Give the extension an ID
let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)

" Allow it to be called later
function! sample#id()
	return s:id
endfunction


" Create a command to directly call the new search type
command! CP call ctrlp#init(sample#id())
