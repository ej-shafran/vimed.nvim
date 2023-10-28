" Grabbing refactoring code
set rtp+=.

set rtp+=../plenary.nvim
set rtp+=../nui.nvim

" If you use vim-plug if you got it locally
set rtp+=~/.vim/plugged/plenary.nvim
set rtp+=~/.vim/plugged/nui.nvim

" If you are using packer
set rtp+=~/.local/share/nvim/site/pack/packer/start/plenary.nvim
set rtp+=~/.local/share/nvim/site/pack/packer/start/nui.nvim

" If you are using lunarvim
set rtp+=~/.local/share/lunarvim/site/pack/packer/start/plenary.nvim
set rtp+=~/.local/share/lunarvim/site/pack/packer/start/nui.nvim

" If you are using lazy
set rtp+=~/.local/share/nvim/lazy/plenary.nvim
set rtp+=~/.local/share/nvim/lazy/nui.nvim

set autoindent
set tabstop=4
set expandtab
set shiftwidth=4
set noswapfile

runtime! plugin/plenary.vim
runtime! plugin/nui.lua
