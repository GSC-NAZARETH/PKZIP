
[ -z "$1" ] && exit

file="$1"
shift

awk '

function parse_xml(object,   i) {
 split(object, objects, "/")
 $0 = FILE
 for( i in objects ) {
   if( ! objects[i] ) continue
   FS = "</"objects[i]">"
   $0 = $0
   FS = "<"objects[i]">"
   $0 = $1
   $0 = $2
 }

 if( $0 ) {
  gsub(/\n[ \t]+/, "\n")
  gsub(/^\n[ \t]*|\n[ \t]*$/, "")
  if( (GET = ARGV[++I]) ) {
    split($0, arr, "\n")
    for(i in arr)
     if( index(arr[i], GET"=") ) {
	GET = arr[i]
	gsub(/^[^=]*=|["]/, "", GET)
	print GET
	break
     }
  } else print
 }
}

BEGIN {
 RS = "^$"
 getline FILE < ARGV[++I]
 while( ARGV[++I] )
  parse_xml(ARGV[I])
}
' "$file" "$@"
