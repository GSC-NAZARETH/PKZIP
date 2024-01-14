
[ -z "$1" ] && exit

file="$1"; shift
case "$file" in
  .) file="$META";;
shift

awk '
function get_value(object,   i) {
 split(object, objects, "/")
 arr[2] = FILE
 for( i in objects ) {
   split(arr[2], arr, "<[/]*" object[i] ">")
 }

 if( ($0 = arr[2]) ) {
  gsub(/^\n[ \t]*|\n[ \t]*$/, "")
  gsub(/\n[ \t]+/, "\n")
  print
 }
}

BEGIN {
 RS = "^$"
 getline FILE
 I = 1
 while( ARGV[++I] )
  get_value(ARGV[I])
}
' "$file" "$@"
