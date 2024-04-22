#!/usr/bin/env -S bash -euETo pipefail -O inherit_errexit
#
# Attempt to shrink (and optionally move) individual files.

readonly JPEG_WIDTH=900
readonly JPEG_HEIGHT=900
readonly JPEG_COLORSPACE=gray
readonly JPEG_QUALITY=70
jpegShrink() (
  IFS=' ' read -r format width height colorspace quality \
    <<<"$(identify -ping -format '%m %w %h %[colorspace] %Q' -- "$1")"

  if [[ "${format,,}" != 'jpeg' ]]; then
    echo 'not a JPEG'
  elif [[ $width -le $JPEG_WIDTH && "$height" -le $JPEG_HEIGHT &&
    ${colorspace,,} == "$JPEG_COLORSPACE" && $quality -le $JPEG_QUALITY ]]; then
    echo "already ${width}x$height in ${colorspace} @ ${quality}%"
  else
    set -x
    convert -resize "${JPEG_WIDTH}x${JPEG_HEIGHT}>" \
      -colorspace "$JPEG_COLORSPACE" -quality "$JPEG_QUALITY" -- "$1" "$2"
  fi
)

pdfShrink() (
  set -x
  gs -q -dBATCH -dNOPAUSE -dCompressFonts=true -dCompressPages=true \
    -dDetectDuplicateImages -dPDFSETTINGS=/screen \
    -sDEVICE=pdfwrite -sOutputFile="$2" -- "$1"
)

pngShrink() (
  set -x
  optipng -o7 -zm1-9 -clobber -out "$2" -- "$1"
)

################################################################################

assumeYes=false # can be enabled during parsing of `$@` below

compare() {
  if [[ $assumeYes != true ]]; then
    xdg-open "$1"
    sleep 0.25s
    xdg-open "$2"
    sleep 0.25s
  fi
}

confirm() {
  if [[ $assumeYes == true ]]; then
    echo "$1? y" >&2
    return 0
  elif ! [[ -t 0 && -t 2 ]]; then
    echo "$1? n" >&2
    return 1
  fi
  read -rp "$1? "
  [[ $REPLY =~ ^[Yy] ]]
}

descshrink() {
  local delta="$(($1 - $2))"
  printf "%s \u2212 %s[%.0f%%] = %s\n" \
    "$(descsize "$1")" \
    "$(descsize "$delta")" "$(bc -l <<<"$delta / $1 * 100")" \
    "$(descsize "$2")"
}

descsize() { # roughly like size output w/ `ls -hl` *without* `--si`
  if [[ $1 -ge 1073741824 ]]; then
    printf '%.0fG\n' "$(bc -l <<<"$1 / 1073741824")"
  elif [[ $1 -ge 1048576 ]]; then
    printf '%.0fM\n' "$(bc -l <<<"$1 / 1048576")"
  elif [[ $1 -ge 1024 ]]; then
    printf '%.0fK\n' "$(bc -l <<<"$1 / 1024")"
  else
    echo "$1b"
  fi
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

errors=()
paths=()
sawDashdash=false
for arg in "$@"; do # ... or use `getopt` if this becomes more complicated
  if [[ -z $arg ]]; then
    :
  elif [[ $sawDashdash == false && $arg =~ ^- ]]; then
    if [[ $arg =~ ^(-y|--yes|--assume-yes)$ ]]; then
      assumeYes=true
    elif [[ $arg == -- ]]; then
      sawDashdash=true
    else
      errors+=("unrecognized option '$arg'")
    fi
  elif [[ -n $arg ]]; then
    paths+=("$arg")
  fi
done

declare -A destinations=() # source path -> destination path
if [[ ${#paths[@]} -ge 2 && -d ${paths[-1]} ]]; then
  directory=${paths[-1]}
  directory=${directory%/} # e.g. './abc/ -> './abc', '/' -> ''
  sources=("${paths[@]:0:${#paths[@]}-1}")
  for source in "${sources[@]}"; do
    destinations[$source]=$directory/${source##*/}
  done
elif
  [[ ${#paths[@]} -eq 2 && ! -e ${paths[1]} ]] &&
    [[ $(typename "${paths[0]}") == $(typename "${paths[1]}") ]]
then
  sources=("${paths[0]}")
  destinations[${paths[0]}]=${paths[1]}
else
  sources=("${paths[@]}")
  for source in "${sources[@]}"; do
    destinations[$source]=$source
  done
fi

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
  echo "$source"

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
      compare "$source" "$temporary"

      test -L "$temporary" && die "$temporary unexpectedly a symlink"
      if [[ $source == "$destination" ]]; then
        if
          confirm "replace $destination ($(descshrink "$size" "$shrunken"))"
        then
          mv --verbose -- "$temporary" "$destination"
          continue
        fi
      elif
        confirm \
          "shrunken $source ($(descshrink "$size" "$shrunken")) -> $destination"
      then
        mv --verbose -- "$temporary" "$destination"
        rm --verbose -- "$source"
        continue
      fi
    fi

    rm --verbose -- "$temporary"
  fi

  if
    [[ $source != "$destination" ]] &&
      confirm "original $source ($(descsize "$size")) -> $destination"
  then
    mv --verbose -- "$source" "$destination"
  fi
done
