
#About
ctrlp-similar is an extension for [ctrlp](http://github.com/kien/ctrlp.vim) that helps recommend files for you to open, based on the status and history of your git repository.

#Installation instructions:
This is an extension to the [ctrlp](http://github.com/kien/ctrlp.vim) plugin, it is required that you install it first. It is recommended that you use a plugin manager like [Vundle](http://github.com/gmarik/Vundle.vim) or [Pathogen](http://github.com/tpope/vim-pathogen/). Otherwise, follow the installation insructions on the github page.

After that is done, it is also recommended that you install this plugin using Vundle/Pathogen.

If you don't use either of those, simply clone the repository

	git clone http://github.com/FriedSock/ctrlp-similar.git ~/.vim/bundle/ctrlp-similar

And add the directory to your runtime path by adding this line to your .vimrc file

	set rtp+=~/.vim/bundle/ctrlp-similar

#Setup

The tool requires set up on a per-repository basis. This means if you
want to use it for a particular repository, you should run the command
`:AddCtrlPSimilarRepo`. Depending on the size of your project history,
it may take a few minutes until you are able to use the predictions.

Until then (and for any other reasons why predicitons cannot be made)
the `:CtrlPSimilar` command will fall back to the default `:CtrlP`

Similary, to disable CtrlPSimilar for a particular repo, just run `:DelCtrlPSimilarRepo`

##Git hooks
If you rewrite the git history at any point, via rebasing or `commit --amend`; there will be some files representing commits that are no longer valid (files affected by history rewriting are given new hashes). While this is not a huge problem, the files are no longer needed and are just taking up extra space.

To automatically have these files deleted, it is recommended you add a post-rewrite commit hook. A fixture to accomplish this is provided, but will need to be added on a per-repository basis. To do so, run:

	cp ~/.vim/bundle/ctrlp-similar/fixtures/post_rewrite the/path/to/your/repo/.git/hooks/post_rewrite
	
	chmod u+x the/path/to/your/repo.git/hooks/post_rewrite
	

#Usage

By default, opening ctrlp-similar is bound to  `<c-s>` (ctrl + s). If you want to rebind this you can add a new mapping to your `.vimrc` file.

	nnoremap <leader>s :CtrlPSimilar<cr>

#Requirements
Your version of Vim must be compiled with the `+ruby` option. The plugin depends on your system ruby version, and has been tested on 1.8.7, 1.9.3, and 2.0.0. If you find that you have a different ruby version I would be happy to look into expanding support.

#Disclaimer

I am running a user study on this plugin, thus this plugin has a logfile which records information every time you accept a suggestion. The file will stay on your machine unless you choose to send it to someone(me). The file contains no specific information about the code being worked on, I encourage you to look at its contents at `~/.vim/bundle/ctrlp-similar/.logfile` if you have any concerns.

