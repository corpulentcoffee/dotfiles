#!/usr/bin/env -S bash -euETo pipefail -O inherit_errexit
#
# Attempt to shrink (and optionally move) individual files.

jpegShrink() (
  set -x
  cp -- "$1" "$2" # TODO
)

pdfShrink() (
  set -x
  gs -q -dBATCH -dNOPAUSE -dCompressFonts=true -dCompressPages=true \
    -dDetectDuplicateImages -dPDFSETTINGS=/screen \
    -sDEVICE=pdfwrite -sOutputFile="$2" "$1"
)

pngShrink() (
  set -x
  optipng "$1" -o7 -zm1-9 -clobber -out "$2"
)

################################################################################

confirm() {
  if ! [[ -t 0 && -t 2 ]]; then
    echo "$1? n" >&2
    return 1
  fi
  read -rp "$1? "
  [[ $REPLY =~ ^[Yy] ]]
}

die() {
  echo "$@" >&2
  exit 1
}

extname() {
  if [[ $1 =~ [^/]\.[a-zA-Z0-9]+$ ]]; then
    echo "${1##*.}"
  else
    echo ''
  fi
}

declare -rA canonicalizations=([jpg]=jpeg)
typename() {
  local extension && extension="$(extname "$1")" && extension="${extension,,}"
  if [[ -v canonicalizations[$extension] ]]; then
    echo "${canonicalizations[$extension]}"
  else
    echo "$extension"
  fi
}

################################################################################

declare -A destinations=() # source path -> destination path
if [[ $# -ge 2 && -d ${!#} ]]; then
  directory=${!#}
  directory=${directory%/} # e.g. './abc/ -> './abc', '/' -> ''
  sources=("${@:1:$#-1}")
  for source in "${sources[@]}"; do
    destinations[$source]=$directory/${source##*/}
  done
elif [[ $# -eq 2 && ! -e $2 ]] && [[ $(typename "$1") == $(typename "$2") ]]; then
  sources=("$1")
  destinations[$1]=$2
else
  sources=("$@")
  for source in "${sources[@]}"; do
    destinations[$source]=$source
  done
fi

errors=()
declare -A sizes=() # source path -> original file size in bytes
for i in "${!sources[@]}"; do
  source=${sources[$i]}
  destination=${destinations[$source]}
  if [[ -v sizes[$source] ]]; then
    unset "sources[$i]" # n.b. will make the array sparse
  elif ! [[ -f $source ]]; then
    errors+=("$source is not a file")
  elif [[ -L $source ]]; then
    errors+=("$source is a symlink")
  elif [[ $source != "$destination" && -e $destination ]]; then
    errors+=("$destination already exists")
    # ... and would catch weird pathological cases too, e.g. a target directory
    # that is actually a symlink to the containing directory of a source file
  elif ! size=$(stat --format='%s' -- "$source"); then
    errors+=("$source is not readable")
  elif ! [[ $size -ge 1 ]]; then
    errors+=("$source is empty")
  else
    sizes[$source]=$size
  fi
done

if ! [[ ${#errors[@]} -eq 0 && ${#sources[@]} -ge 1 ]]; then
  if [[ ${#errors[@]} -gt 0 ]]; then
    for error in "${errors[@]}"; do echo "$error"; done
    echo
  fi
  echo "usage:"
  echo "  $0 file-1.pdf file-2.jpeg ~/directory/  # shrink then move"
  echo "  $0 file-old-name.pdf file-new-name.pdf  # shrink then rename"
  echo "  $0 file-1.pdf file-2.jpeg other-3.jpeg  # shrink in-place"
  exit 1
fi >&2

first=true
for source in "${sources[@]}"; do
  [[ $first == true ]] || echo
  first=false

  size=${sizes[$source]}
  echo "$source ($size)"

  destination=${destinations[$source]}
  type=$(typename "$source")
  test "$(typename "$destination")" == "$type" || die "inconsistent type"

  if [[ -z $type ]]; then
    echo 'refusing to manipulate this file'
  elif shrinker=${type}Shrink && [[ $(type -t "$shrinker") != function ]]; then
    echo "nothing setup to shrink $type files"
  else
    extension=$(extname "$destination")
    test -n "$extension" || die "unexpectedly empty destination extension"
    temporary=$(mktemp --suffix=".$extension")

    if ! "$shrinker" "$source" "$temporary"; then
      echo 'failed trying to shrink this file'
    elif ! shrunken=$(stat -c%s -- "$temporary"); then
      echo "$temporary is not readable"
    elif ! [[ $shrunken -ge 1 ]]; then
      echo "$temporary is empty"
    elif ! [[ $shrunken -lt $size ]]; then
      echo "shrunken file isn't any smaller than original"
    else
      xdg-open "$source"
      xdg-open "$temporary"

      test -L "$temporary" && die "$temporary unexpectedly a symlink"
      if [[ $source == "$destination" ]]; then
        if confirm "shrunk TODO; replace $destination"; then
          mv --verbose -- "$temporary" "$destination"
          continue
        fi
      elif confirm "$source (shrunk TODO) -> $destination"; then
        mv --verbose -- "$temporary" "$destination"
        rm --verbose -- "$source"
        continue
      fi
    fi

    rm --verbose -- "$temporary"
  fi

  if [[ $source != "$destination" ]] && confirm "original $source -> $destination? "; then
    mv --verbose -- "$source" "$destination"
  fi
done
