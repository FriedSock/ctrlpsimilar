
#About
ctrlp-similar is an extension for [ctrlp](http://github.com/kien/ctrlp.vim) that helps recommend files for you to open, based on the status and history of your git repository.

#Installation instructions:
This is an extension to the [ctrlp](http://github.com/kien/ctrlp.vim) plugin, it is required that you install it first. It is recommended that you use a plugin manager like [Vundle](http://github.com/gmarik/Vundle.vim) or [Pathogen](http://github.com/tpope/vim-pathogen/). Otherwise, follow the installation insructions on the github page.

After that is done, it is also recommended that you install this plugin using Vundle/Pathogen.

If you don't use either of those, simply clone the repository

	git clone http://github.com/FriedSock/ctrlp-similar.git ~/.vim/bundle/ctrlp-similar
	
And add the directory to your runtime path by adding this line to your .vimrc file

	set rtp+=~/.vim/bundle/ctrlp-similar
	
	
#Usage

By defuault, opening ctrlp-similar is bound to  `<c-s>` (ctrl + s). If you want to rebind this you can add a new mapping to your `.vimrc` file.

	nnoremap <leader>s :CtrlPSimilar<cr>
	
#Requirements
Your version of Vim must be compiled with the `+ruby` option. The plugin depends on your system ruby version, and has been tested on 1.8.7, 1.9.3, and 2.0.0. If you find that you have a different ruby version I would be happy to look into expanding support.
	
