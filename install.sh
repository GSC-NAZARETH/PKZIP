#!/data/data/com.termux/files/usr/bin/bash

if ( return ) 2>/dev/null; then
  is_sourced () { true; }
else
  is_sourced () { false; }
fi

INSTALLDIR="${INSTALLDIR:-/data/data/com.termux/files/usr/PKZIP}"
BASH=${BASH:-/data/data/com.termux/files/usr/bin/bash}

printf '\n\t<-- Initializing PKZIP -->\n'
is_sourced && mode="Sourced Script" || mode="Executed Script"
printf '\t '"( mode: %s )"'\n\n' "$mode"

notify_run() {
  local msg="$1"
  printf '  - %s -> ' "$msg"
}

notify_done() {
  local ret=$? msg_done="${1:-done}" msg_failed="${2:-failed}"
  [ $ret -eq 0 ] && echo "$msg_done" || echo "$msg_failed"
  return $ret
}

notify_run 'Install path'
echo "$INSTALLDIR"

notify_run 'Setup directory'
for d in $HOME/bin $INSTALLDIR \
  $INSTALLDIR/bin \
  $INSTALLDIR/modules \
  "$INSTALLDIR/source" ;
do
  mkdir -p $d 2>/dev/null
done

notify_done
unset d

# Setup Startup file
notify_run "Setup startup file"
INITFILE=$INSTALLDIR/source/pk-init.sh
PRELOGINFILE=$INSTALLDIR/source/pre-login.sh
loginfile="$PREFIX/etc/termux-login.sh"
profile="$PREFIX/etc/profile"

if ! grep -q "$PRELOGINFILE" "$loginfile"; then
  echo "[ -r $PRELOGINFILE ] && . $PRELOGINFILE" >> "$loginfile"
fi

if ! grep -q "$INITFILE" "$profile"; then
  echo "[ -r $INITFILE ] && . $INITFILE" >> "$profile"
fi

# create pre login file
echo '
# This file is sourced when
#  Termux startup before executing SHELL

# startup whatcher
grep -q "'$INITFILE'" '$profile' || echo "[ -r '$INITFILE' ] && . '$INITFILE'" >> '$profile'
' > $PRELOGINFILE

# create post init file
echo '
#   POST INIT file
# This file is sourced from profile file
# after shell init completed

# <-- INIT Functions -->

# check interactive shell
is_interactive () { 
  [[ "$-" == *i* ]]; return $?
}

# check root mode
is_root_mode () { 
  [[ $(whoami) == root ]]; return $?
}

# reset PREFIX, HOME, TMPDIR, PKZIP, and PATH
reset_environment() {
 export PREFIX='$PREFIX'
 export HOME='$HOME'
 export TMPDIR='$TMPDIR'
 export LANG='$LANG'
 export PKZIP='$INSTALLDIR'

 # Redefine PATH
 PATH=$PREFIX/bin

 # add root path if on root mode
 if is_root_mode; then
  local p l=""
  for p in /sbin /xbin \
    /system/bin /system/xbin /vendor/bin /vendor/xbin
  do
     # check if exist and not empty
     [ -n "$(ls $p 2>/dev/null)" ] || continue
     l="$l:$p"
  done

  [ -n "$l" ] && PATH="${l#:}:$PATH"
 fi

 # add HOME/bin to first and current directory to last
 PATH="$HOME/bin:$PATH:."

 export PATH
}

# print [function name] code or list declared functions
catfunc () {
  if [ -z "$1" ]; then
    declare -F
    return
  fi

  local regex
  for regex; do
    awk "/^${regex//\*/.\*} ()/"'\'' {
      print
      while( (getline) ) {
	print
	if( $0 == "}" ) break
      }
    }'\'' <(declare -f)
  done
}

# print work in progress [: msgs]
work_in_progress() {
 local string="Work in Progress"
 if [ -n "$1" ]; then
   ! echo "${string} : $@"
 else
   ! echo "$string"
 fi
}

# export all functions
export -f \
 is_interactive is_root_mode catfunc \
 reset_environment work_in_progress

reset_environment

# <-- SETUP MODULES -->
. <(
  for META in $(find $PKZIP/modules -name "*app-meta.xml"); do
    dir=${META%/*}
    name=${dir##*/}
    launcher=$HOME/bin/$name startup=$dir/startup.sh
    
    if [ -e "$dir/.disabled" ]; then
      [ -h "$launcher" ] && unlink "$launcher"
      continue
    fi

    # creating link if not exist
    [ -h "$launcher" ] || ln -s $PKZIP/bin/pkzip $launcher

    # source startup script if any
    [ -r $startup ] && echo "META=$META MODNAME=$name \
     MODDIR=$dir . $startup"
  done
)
' > $INITFILE

notify_done
unset loginfile profile

# Creating PKZIP module launcher
notify_run 'Creating module launcher'

launcher=$INSTALLDIR/bin/pkzip
mode=766

printf '%s\n' '#!'"$BASH" '
return 1 2>/dev/null

if [ -v source_list ]; then
  for src in $source_list; do
    [ -r "$src" ] && . "$src"
  done
  unset src source_list
fi

if ! [ -v PKZIP ]; then
  l='"$INITFILE"'
  [ -r $l ] || {
    ! echo "cannot source init file" >&2
    exit
  }

  . $l
  unset l
fi

# load module-rsc
[ -r $PKZIP/source/module-rsc.sh ] || {
  ! echo "Module resource not found" >&2
  exit
}
. $PKZIP/source/module-rsc.sh

# add PKZIP/bin to first PATH
PATH="$PKZIP/bin:$PATH"

read_pkzip_meta_options () {
  . <( meta_get . PKZIP/METADATA PKZIP/CONFIG )

  case "$1" in
   --verCode) exit 0 $verCode;;
   -v|--version) exit \
     "v.$(parse_verCode)-${relType:-\(unreleased\)}"
     ;;
   --author) exit "$author";;
   --description) exit "$(meta_get . PKZIP/DESCRIPTION)";;
   --metadata) exit "$(meta_get . PKZIP/METADATA)";;
   --config) exit "$(meta_get . PKZIP/CONFIG)";;
  esac
}

if [[ $0 == *pkzip ]]; then
  
  # load pkzip meta file
  META=$PKZIP/pkzip-meta.xml
  read_pkzip_meta_options "${1:-"--description"}"

  case "$1" in
   (manage) x=manage;;
   (install) x=install;;
   (uninstall) x=uninstall;;
   (*) exit 127 "Unkown command: $1";;
  esac
  shift

  # check binary
  exe=$PKZIP/pkzip-$x
  [ -r "$exe" ] || exit "work in progress ($x)"
  . $exe "$@"

else

  # Module launcher mode
  #
  MODNAME=${0##*/}
  MODDIR=$PKZIP/modules/$MODNAME
  META=$MODDIR/app-meta.xml

  # source METADATA AND CONFIG
  #
  read_pkzip_meta_options "$1"

  if ${request_root:-false} && ! is_root_mode; then
    source_list="$source_list $PKZIP/source/pk-init.sh" \
    exec /sbin/su -c "$0 " "$@" 
  fi

  [ -r "$MODDIR/main.sh" ] &&\
    . $MODDIR/main.sh "$@"
fi
' > $launcher
chmod $mode $launcher

# Replace link at home/bin (if exist)
rm -f $HOME/bin/pkzip
ln -s $launcher $HOME/bin/pkzip

notify_done
unset launcher mode

# Creating Module resource
notify_run 'Creating module resource'

module_rsc=$INSTALLDIR/source/module-rsc.sh
echo '
# this file is sourced when
# pkzip | module is called

# <-- Declare additional var and functions -->

# ++ COMMAND EXTENSION ++

exit() {
 #
 # ex: print msg on exit
 #
 local ret=$?
 [[ "$1" == +([0-9]) ]] && { ret=$1; shift; }

 if [ -n "$1" ]; then
   if [ $ret -eq 0 ]; then
	printf '\'"%s\n"\'' "$@"
   else
	printf '\'"E: %s\n"\'' "$@" >&2
   fi
 fi

 command exit $ret
}

clear() {
  if ! [[ "$1" == +([0-9]) ]]; then
    command clear "$@"
    return
  fi

  #
  # ex: clear [n] line above
  #
  local i
  for (( i=$1; $i>0; i-- )); do
    printf '\'"\r\e[K\e[A\e[K"\''
  done
}

parse_verCode () {
  local num=${1:-$verCode} bugfix featcode relcode

  # version number min. 6n
  [[ "$num" == +([0-9]) ]] && [ ${#num} -ge 6 ] || return

  bugfix=${num: -4} num=${num:: -4}
  featcode=${num: -2} num=${num:: -2}
  relcode=${num:-0}

  echo "$relcode.$featcode.$bugfix"
}

meta_get () {
  local file="$1"
  shift

  [ "$file" = . ] && file="$META"
  [ -n "$file" ] || return

  awk '\''
    BEGIN {
      RS = "^$"
      I = 1
      getline META

      while( ARGV[++I] ) {
	arr[2] = META
	split(ARGV[I], path, /[\/\-\._]/)

	for( i in path ) {
	 LE = path[i]
	 split(arr[2], arr, "<[/]*" LE ">")
	}

	if( ! ($0 = arr[2]) ) continue
	if( LE != "DESCRIPTION" ) {
	  gsub(/\n[ \t]+/, "\n")
	  gsub(/^\n|\n$/, "")
	}
	print
      }

    }
  '\'' "$file" "$@"
} 
' > $module_rsc

notify_done
unset module_rsc

notify_run 'creating pkzip metadata'
META=$INSTALLDIR/pkzip-meta.xml

echo '
<PKZIP>
	<METADATA>
	  verCode=1040268
	  relType="beta"
	  author="GSC-NAZARETH"
	</METADATA>

	<CONFIG>
	  install_date="'"$(date)"'"
	</CONFIG>

	<DESCRIPTION>
		TERMUX PKZIP
Manage, Install, Uninstall PKZIP Module App

feature:
* Running Module script/app in extended environment
* Disable script/app from startup and executing without
uninstalling it
  enabling/uninstalling in manager
* Create startup script in own [startup.sh] file in module dir
  do not need to modify bashrc or zshrc

usage:
pkzip [<info>|command]

<command>
manage		Manage Modules
install		Install pkzip module
uninstall	uninstall module

<module/app info>
-v | --version	display version
--verCode	display version code
--author	view app/module Author
--description	view app/module Description
--config	display config
--metadata	display app metadata
	</DESCRIPTION>
</PKZIP>
' > $META

notify_done
unset META

if is_sourced; then
  notify_run 'Running PKZIP'
  . $INITFILE

  notify_done

  # cleanup env if sourced
  unset INSTALLDIR PRELOGINFILE INITFILE
  unset -f notify_run notify_done is_sourced
else
  echo '  # Restart current Shell or open new instance to use pkzip'
fi

printf '\n\t<-- Installing Done -->\n'
