#!/data/data/com.termux/files/usr/bin/bash

# return false if script is sourced
[[ "$_" == /* ]] || return 1 2>/dev/null

if [ -n "$include_list" ]; then
 for file in $include_list; do
  [ -r "$file" ] && . $file
 done
 unset file
fi

if [ -z "$PKZIP" ]; then
 # load PKZIP startup file
 l=/data/data/com.termux/files/usr/pkzip/source/pk-init.sh
 [ -r "$l" ] || {
  echo "cannot read pkzip startup file"
  exit 1
 }
 . $l
 unset l
fi

. $PKZIP/source/module-rsc.sh

if [[ "$0" == *pkzip ]]; then

 case "$1" in
  ""|-l|list) x=manager;;
  -c|create) x=create;;
  -u|uninstall) x=uninstall;;
  -i|install) x=install;;
  -v|--version) x=version;;
  *) exit 127 "Unknown command: $cmd";;
 esac

 [ "$x" = version ] && {
  . <(meta-get $PKZIP/pkzip-meta.xml PKZIP/METADATA)
  exit 0 $(parse_verCode)
 }

 file=$PKZIP/bin/pkzip-$x.sh
 [ -r "$file" ] || exit "Work in progress: $x"
  . "$file"

else

 MODNAME=${0##*/}
 MODDIR=$PKZIP/modules/$MODNAME
 META=$MODDIR/app-meta.xml

 [ -r "$META" ] || exit 2 "Module ($MODNAME) not found"
 . <(meta-get $META PKZIP/METADATA PKZIP/CONFIG)

 case "$1" in
  -v|--version) exit 0 \
    "pkzip_module_ver: $(parse_verCode)";;
 esac

 cd $MODDIR

 if ${request_root:-false} && ! is_root_mode; then
     include_list="$PKZIP/source/pk-init.sh" \
      exec /sbin/su -s "${SHELL:-$PREFIX/bin/bash}" -c "$0 " "$@"
 fi

 [ -r "$MODDIR/main.sh" ] && . "$MODDIR/main.sh" "$@"

fi
