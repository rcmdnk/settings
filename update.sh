#!/usr/bin/env bash

.  ~/.bashrc

link_dir="$HOME/usr/share/"

debug=0
if [ "$1" = "-d" ];then
  debug=1
fi

cd "$(dirname "$0")" || exit 1
curdir=$(pwd)
setting_dir="${link_dir}/$(basename "$curdir")"

function execute_check () {
  if [ "$debug" -eq 1 ];then
    echo
    echo "#################################################################"
    echo "# $(pwd)"
    echo "# $ $*"
    echo "#################################################################"
    echo
    "$@"
  elif ! output=$("$@" 2>&1);then
    echo "Error at the directory: $(pwd)"
    echo "---"
    echo "\$ $*"
    echo "$output"
  fi
}

# Initial installation
if [ ! -L "$setting_dir" ];then
  mkdir -p "$link_dir"
  ln -s "$curdir" "$setting_dir"
fi

# update git
cd "$setting_dir" || exit 1
for dir in dotfiles scripts mac windows private local;do
  [ ! -d $dir ] && continue
  cd "$dir" || exit 1
  if ! git status >&/dev/null;then
    cd ../ || exit 1
    continue
  fi
  if [ -d external ];then
    for d in external/*;do
      cd "$d" || exit 1
      if [ "$(git current-branch)" = "master" ];then
        execute_check git pull
      fi
      cd - || exit 1
    done
  fi

  if [ $dir = private ] || [ $dir = local ];then
    update_options=(1 --nocheck)
  else
    update_options=(1)
  fi
  if [ -d submodules ];then
    for d in submodules/*;do
      cd "$d" || exit 1
      if [ "$(git current-branch)" = "master" ];then
        execute_check git update --nocommit "${update_option[@]}"
      fi
      cd - || exit 1
    done
  fi
  if [ "$(git current-branch)" = "master" ];then
    execute_check git update "${update_option[@]}"
  fi
  if [ -f ./install.sh ];then
    execute_check ./install.sh -b ""
  fi
  cd ../ || exit 1
done

cd "$setting_dir" || exit 1
if [[ "$OSTYPE" =~ darwin ]];then
  cd AppleScript || exit 1
  if [ "$(git current-branch)" = "master" ];then
    execute_check ./osadeall.sh -b ""
    execute_check git update --nocommit
    execute_check ./install.sh -b ""
  fi
fi

# Update settings
cd "$setting_dir" || exit 1
execute_check git update
execute_check git submodule update

# update vim plugins by NeoBundle
vim_proc=$(ps aux |grep "^$USER"|grep -q "[v]im -c")
if [ -n "$vim_proc" ];then
  echo "previous vim -c is still running, kill it."
  kill -kill "$vim_proc"
fi
execute_check vim  -c "silent call dein#update()" -c "quit"

#if [[ "$OSTYPE" =~ darwin ]];then
#  # OS and OS default app update
#  execute_check /usr/sbin/softwareupdate --install --all

#  # App Store app update (may need to open AppStore.app...?)
#  execute_check mas upgrade
#fi

# brew
if type brew >& /dev/null;then
  execute_check brew file update
  execute_check brew file clean -C
fi
