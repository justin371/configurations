#!/usr/bin/env bash

CHECKOUT_DIR="$( cd "$(dirname "$0")"; pwd -P)"

red='\e[1;31m'   # bold red
yellow='\e[0;33m'
green='\e[1;32m'
blue='\e[1;34m'
NC='\e[0m'       # no colour

function main {
    if [ "$#" == "0" ]; then
        install
    elif [ "$#" == "1" ]; then
        if [ "$1" == "--look-for-updates" ]; then
            look_for_updates
        else
            wtf
        fi
    elif [ "$#" == "2" ]; then
        if [ "$1" == "--update" ]; then
            (cd $CHECKOUT_DIR/../$2; git pull; ./install.sh)
        else
            wtf
        fi
    else
        wtf
    fi
}

function install {
    install_symlink $HOME/.bash_completion       $CHECKOUT_DIR/bash/dot-bash_completion
    install_symlink $HOME/.bash_completion.d     $CHECKOUT_DIR/bash/dot-bash_completion.d
    install_symlink $HOME/.bash_functions        $CHECKOUT_DIR/bash/dot-bash_functions
    install_symlink $HOME/.bash_functions.d      $CHECKOUT_DIR/bash/dot-bash_functions.d
    install_symlink $HOME/.cpandistprefs         $CHECKOUT_DIR/cpandistprefs
    install_symlink $HOME/.parallel              $CHECKOUT_DIR/dot-parallel
    install_symlink $HOME/.treerc                $CHECKOUT_DIR/dot-treerc
    install_symlink $HOME/.screenrc              $CHECKOUT_DIR/dot-screenrc
    install_symlink $HOME/.vim                   $CHECKOUT_DIR/vim/dot-vim
    install_symlink $HOME/.vimrc                 $CHECKOUT_DIR/vim/dot-vimrc

    mkdir $HOME/bin 2>/dev/null
    install_symlink $HOME/bin/lls                $CHECKOUT_DIR/../perlscripts/lls

    mkdir $HOME/.get_iplayer 2>/dev/null
    install_symlink $HOME/.get_iplayer/options   $CHECKOUT_DIR/get_iplayer/options

    (
        cd "$CHECKOUT_DIR/dot-config"
        [ ! -d "$HOME/.config" ] && mkdir "$HOME/.config"
        for file in $(find . -type f); do
            filename=$(basename $file)
            dirname=$(dirname $(echo $file|sed 's/^..//'))
            [ ! -d "$HOME/.config/$dirname" ] && mkdir -p "$HOME/.config/$dirname"
            install_symlink $HOME/.config/$dirname/$filename $CHECKOUT_DIR/dot-config/$dirname/$filename
            if [[ "$dirname" == "bat/syntaxes" ]]; then
                echo -n "Rebuilding bat cache ... "
                bat cache --build > /dev/null
                echo OK
            fi
        done
    )

    if [[ "$(uname)" == "Darwin" ]]; then
        mkdir $HOME/Library/KeyBindings 2>/dev/null || true
        copy_if_not_equal $CHECKOUT_DIR/karabiner/DefaultKeyBinding.dict $HOME/Library/KeyBindings/DefaultKeyBinding.dict
    fi

    grep perlbrew              ~/.profile >/dev/null 2>&1 || echo 'source ~/perl5/perlbrew/etc/bashrc'           >> ~/.profile
    grep bash_completion       ~/.profile >/dev/null 2>&1 || echo '. $HOME/.bash_completion'                     >> ~/.profile
    grep bash_functions        ~/.profile >/dev/null 2>&1 || echo '. $HOME/.bash_functions'                      >> ~/.profile
    grep EDITOR                ~/.profile >/dev/null 2>&1 || echo 'export EDITOR=`which vim`'                    >> ~/.profile
    grep SHELLCHECK_OPTS       ~/.profile >/dev/null 2>&1 || echo 'export SHELLCHECK_OPTS=-C'                    >> ~/.profile
    grep LESS                  ~/.profile >/dev/null 2>&1 || echo 'export LESS=-FRX'                             >> ~/.profile
    grep PS1                   ~/.profile >/dev/null 2>&1 || echo "export PS1='\\h:\\w \$ '"                     >> ~/.profile

    grep PROMPT_COMMAND        ~/.profile >/dev/null 2>&1 || echo set PROMPT_COMMAND in .profile
    # export PROMPT_COMMAND='echo -ne "\033]0;${HOSTNAME}: $(realpath .)\007"'

    grep QUOTING_STYLE         ~/.profile >/dev/null 2>&1 || echo 'export QUOTING_STYLE=literal'                 >> ~/.profile

    grep -- --look-for-updates ~/.profile >/dev/null 2>&1 ||  echo "$CHECKOUT_DIR/install.sh --look-for-updates" >> ~/.profile

    local perlbrew_line=$(grep -n perlbrew ~/.profile |sed 's/:.*//')
    local bash_functions_line=$(grep -n bash_functions ~/.profile |sed 's/:.*//')
    if [ $perlbrew_line -gt $bash_functions_line ]; then
        printf "${red}perlbrew should be loaded before my bash_functions$NC\n"
    fi
}

function wtf {
    printf "${red}WTF!?!?!$NC\n"
}

function look_for_updates {
    cd $CHECKOUT_DIR
    TIMEOUT=timeout
    if [ "$(uname)" == "OpenBSD" ]; then
        TIMEOUT=gtimeout
    fi

    for repo in configurations perlscripts; do
        (
            cd $CHECKOUT_DIR/..
            [ ! -d "$repo" ] && git clone git@github.com:DrHyde/$repo.git

            cd $repo
            $TIMEOUT 5 git fetch -q origin
            if [ "$?" != "0" ]; then
                echo
                printf "${red}Timed out trying to talk to github to see if your $repo repo is up to date$NC\n"
                echo
            elif [ "$(git log -1 --pretty=format:%H origin/master)" != "$(git log -1 --pretty=format:%H)" ]; then
                echo
                printf "${red}Your $repo repo isn\'t the same as Github$NC\n"
                printf "Try ${green}$CHECKOUT_DIR/install.sh --update $repo${NC}\n"
                echo
            fi
        ) &
    done
    wait

    for wanted in rg tldr tree fzf ctags ngrok karabiner; do
        if [[ "$wanted" == "ngrok" && "$(uname)" =~ ^(SunOS|OpenBSD)$ ]]; then
            true
        elif [[ "$wanted" == "karabiner" ]]; then
            if [[ "$(uname)" == "Darwin" ]]; then
                ps auxww|grep -v grep|grep -qi karabiner || \
                printf "${red}Install Karabiner: brew install --cask karabiner-elements$NC\n"
            fi
        elif [[ "$(which $wanted)" == "" || "$(which $wanted)" == "no $wanted in"* ]]; then
            printf "${red}Install '$wanted'$NC\n"
        elif [ "$wanted" == "fzf" ]; then
            grep fzf $HOME/.profile >/dev/null 2>&1 || \
              printf "${red}Install fzf keybindings in .profile (probably run /usr/local/opt/fzf/install)$NC\n"
        fi
    done
    echo

    if [ "$(grep HOME/.bashrc $HOME/.profile)" == "" ]; then
        printf "${red}.profile needs to source .bashrc thus: $NC\n"
        cat << 'SOURCE_BASHRC_SNIPPET'
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
	    . "$HOME/.bashrc"
    fi
fi
SOURCE_BASHRC_SNIPPET
        echo
    fi

    if [ "$(grep bash_functions $HOME/.profile)" == "" ]; then
        printf "${red}.profile needs to source bash functions, run install.sh$NC\n";
    fi
}

function install_symlink {
    LINK=$1
    FILE=$2
    (
        test -L $LINK
    ) || (
        test -e $LINK && (
            printf "$red$LINK already exists but isn't a symlink, leaving it alone$NC\n"
        )
    ) || (
        printf "${green}Create symlink from $LINK to $FILE$NC\n"
        ln -s $FILE $LINK
    )
}

function copy_if_not_equal {
    SOURCE=$1
    TARGET=$2
    if [[ "$(md5sum $SOURCE|awk '{print $1}')" == "$(md5sum $TARGET|awk '{print $1}')" ]]; then
        true
    else
        printf "${red}Updating $TARGET\n  from $SOURCE$NC\n"
        echo Restart running apps to pick that up
        cp $SOURCE $TARGET
    fi
}

if [ "$UID" != "0" ]; then
    main "$@"
fi
