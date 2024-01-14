
list=$(find $PKZIP/modules -name "*app-meta.xml")

[ -z "$list" ] && exit "<-- No module installed -->"

printf '\t<--( Module list )-->\n'
i=0
for meta in $list; do
 . <( meta-get $meta PKZIP/METADATA )
 ver=$(parse_verCode)
 ver="$ver-${relType:-(not release)}"
 unset relType
 ((i++))
 printf '%5s %-25s ver:%s\n' "($i)" "$id" "$ver"
done

echo "
 [1-9]+)  View detail
      0)  Exit
"

while :; do
 printf "  Select: "
 read sel;
 [[ "$sel" == +([0-9]) ]] &&\
  [ $sel -le $i ] && break
 clear 2
done

[ $sel -eq 0 ] && exit

