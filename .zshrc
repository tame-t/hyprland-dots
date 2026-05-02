# startup things
fastfetch -C ~/.config/fastfetch/zsh.jsonc

# oh-my-zsh things
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="bira"

plugins=(git)

source $ZSH/oh-my-zsh.sh

# Your custom stuff
export EDITOR=nvim
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# alias
alias allfetch='fastfetch -C ~/.config/fastfetch/all.jsonc'
