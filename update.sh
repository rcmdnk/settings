#!/usr/bin/env bash

source ~/.bashrc

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
if [ ! -d "$setting_dir" ] && [ ! -L "$setting_dir" ];then
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
        execute_check git pull --rebase
      fi
      cd - > /dev/null || exit 1
    done
  fi

  if [ $dir = private ] || [ $dir = local ];then
    update_options=(--nocheck)
  else
    update_options=()
  fi
  if [ -d submodules ];then
    for d in submodules/*;do
      cd "$d" || exit 1
      if [ "$(git current-branch)" = "master" ];then
        execute_check git update --nocommit "${update_options[@]}"
      fi
      cd - > /dev/null || exit 1
    done
  fi
  if [ "$(git current-branch)" = "master" ];then
    execute_check git update --commit "${update_options[@]}"
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
    execute_check git update
    execute_check ./install.sh -b ""
  fi
fi

# Update settings
cd "$setting_dir" || exit 1
execute_check git update
execute_check git submodule update

if [[ "$OSTYPE" =~ darwin ]];then
  # OS and OS default app update
  execute_check /usr/sbin/softwareupdate --install --all --force

  # App Store app update (may need to open AppStore.app...?)
  execute_check mas upgrade
fi

# brew
if type brew >& /dev/null;then
  execute_check brew file init
  execute_check brew file update
  if [[ "$OSTYPE" =~ darwin ]];then
    # Restart Google IME, as it requires restart after update
    inputmethod=$(launchctl list | grep application.com.google.inputmethod.Japanese | awk '{print $3}')
    if [ -n "$inputmethod" ];then
      launchctl remove "$inputmethod"
    fi
    converter=$(launchctl list | grep com.google.inputmethod.Japanese.Converter | awk '{print $3}')
    if [ -n "$converter" ];then
      launchctl remove "$converter"
    fi
    renderer=$(launchctl list | grep com.google.inputmethod.Japanese.Renderer | awk '{print $3}')
    if [ -n "$renderer" ];then
      launchctl remove "$renderer"
    fi
    launchctl load /Library/LaunchAgents/com.google.inputmethod.Japanese.Converter.plist
    launchctl load /Library/LaunchAgents/com.google.inputmethod.Japanese.Renderer.plist
  fi
fi

# mise, set MISE_CEILING_PATHS to avoid accessing security required paths
MISE_CEILING_PATHS=/tmp mise cfg mise install > /dev/null 2>&1 || true
MISE_CEILING_PATHS=/tmp mise cfg mise upgrade --bump > /dev/null 2>&1 || true
MISE_CEILING_PATHS=/tmp mise cfg mise prune -y > /dev/null 2>&1 || true

# Install packages
#_pip_install () {
#  pip3 install -U pip install pynvim ruff mypy autopep8 black pep8 flake8 pyflakes pylint jedi
#}
#execute_check _pip_install

_npm_install () {
  npm i -g textlint textlint-rule-max-ten textlint-rule-spellcheck-tech-word textlint-rule-no-mix-dearu-desumasu textlint-rule-preset-ja-technical-writing textlint-filter-rule-allowlist textlint-rule-preset-ja-spacing textlint-rule-preset-jtf-style textlint-rule-preset-japanese textlint-rule-terminology
}
execute_check _npm_install


if [ -x ~/.local_update.sh ];then
  execute_check ~/.local_update.sh
fi
