#!/usr/bin/env bash
# Checks the claims encrypt-pdf/SKILL.md makes about \special{pdf:encrypt ...} against the TeX
# installed on this machine, by compiling small documents and reading the result with pdfinfo.
#
# Usage: bash tests/verify.sh
#   Needs xelatex, pdflatex and pdfinfo (poppler) on PATH. Reads no environment variables.
#   Exits 0 when every claim holds, 1 otherwise. Works in a temporary directory it removes.
#
# Run by a person before changing the skill, or after a TeX Live update. Not part of the skill:
# JointTex installs only SKILL.md. The AES-256 check is reported, not enforced, because it
# depends on the TeX Live version (see "Key length" in the skill).
set -u

failures=0
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work" || exit 1

# write_doc NAME PREAMBLE [BODY]: a one-page article with PREAMBLE before \begin{document}.
write_doc() {
  printf '%s\n' '\documentclass{article}' "$2" '\begin{document}' "Hello. ${3:-}" '\end{document}' > "$1.tex"
}

# build ENGINE NAME: compile quietly; the return status is the engine's.
build() {
  rm -f "$2.pdf"
  "$1" -interaction=nonstopmode -halt-on-error "$2.tex" > "$2.stdout" 2>&1
}

# permission_value NAME: the /P entry of the PDF's encryption dictionary, as xdvipdfmx wrote it.
# Bits 4 to 2048 are the ones `perm` sets; with none of them /P is -3904, so /P is perm - 3904.
permission_value() {
  LC_ALL=C tr '\n' ' ' < "$1.pdf" | LC_ALL=C grep -a -o '/P -\{0,1\}[0-9][0-9]*>>' | head -1 | tr -d '/P> '
}

# encryption NAME [pdfinfo options]: the "Encrypted:" line, or pdfinfo's error.
encryption() {
  local name=$1
  shift
  pdfinfo "$@" "$name.pdf" 2>&1 | grep -E 'Encrypted|Incorrect password' | head -1
}

# expect LABEL ACTUAL PATTERN: one claim; ACTUAL must match the extended regex PATTERN.
expect() {
  if printf '%s' "$2" | grep -Eq -- "$3"; then
    echo "ok    $1"
  else
    echo "FAIL  $1: got [$2], wanted /$3/"
    failures=$((failures + 1))
  fi
}

# opens_with LABEL NAME PASSWORD yes|no: whether PASSWORD opens NAME.pdf as the user password.
opens_with() {
  local got=no
  encryption "$2" -upw "$3" | grep -Eq 'Encrypted: +yes' && got=yes
  expect "$1" "$got" "^$4\$"
}

# password_case LABEL AS-WRITTEN-IN-TEX OPENS-WITH [MUST-NOT-OPEN-WITH]
password_case() {
  write_doc pw "\\special{pdf:encrypt userpw ($2) ownerpw (owner1) length 128 perm 2052}"
  build xelatex pw
  opens_with "$1" pw "$3" yes
  [ $# -ge 4 ] && opens_with "$1 (not as written)" pw "$4" no
}

check_engines() {
  local special='\special{pdf:encrypt userpw (open1) ownerpw (owner1) length 128 perm 2052}'
  write_doc base "$special"
  build xelatex base
  expect "xelatex: needs the open password" "$(encryption base)" 'Incorrect password'
  expect "xelatex: AES at length 128, print only" "$(encryption base -upw open1)" 'print:yes copy:no change:no addNotes:no algorithm:AES\)'
  build pdflatex base
  expect "pdflatex: compiles, PDF not encrypted" "$(encryption base)" 'Encrypted: +no'
  expect "pdflatex: the log says nothing about it" "$(grep -ci 'encrypt' base.log)" '^0$'
  if command -v lualatex > /dev/null; then
    build lualatex base
    expect "lualatex: compiles, PDF not encrypted" "$(encryption base)" 'Encrypted: +no'
  fi
  write_doc guard "\\usepackage{iftex}\\RequireXeTeX $special"
  build pdflatex guard
  expect "guard: pdflatex compile fails" "$?" '^1$'
  expect "guard: says why" "$(grep -c 'XeTeX is required to compile this document' guard.stdout)" '^[1-9]'
  build xelatex guard
  expect "guard: xelatex still encrypts" "$(encryption guard -upw open1)" 'Encrypted: +yes'
}

check_placement() {
  local special='\special{pdf:encrypt userpw (open1) ownerpw (owner1) length 128 perm 2052}'
  write_doc late '' "\\newpage $special second page"
  build xelatex late
  expect "special after the first page is ignored" "$(encryption late)" 'Encrypted: +no'
  expect "ignored special leaves nothing in the log" "$(grep -ci 'encrypt' late.log)" '^0$'
  write_doc two '\special{pdf:encrypt userpw (first) ownerpw (o) length 128 perm 2052}\special{pdf:encrypt userpw (second) ownerpw (o) length 128 perm 0}'
  build xelatex two
  opens_with "two specials: the later one decides" two second yes
  opens_with "two specials: the earlier one is dropped" two first no
  printf '%s\n' '\documentclass{article}\usepackage{hyperref}\begin{document}\section{A}Text.\end{document}' > main.tex
  printf '%s\n' '\RequirePackage{iftex}' '\RequireXeTeX' "$special" '\input{main}' > wrapper.tex
  build xelatex wrapper
  expect "second root file encrypts (with hyperref)" "$(encryption wrapper -upw open1)" 'Encrypted: +yes'
}

check_passwords() {
  write_doc owner '\special{pdf:encrypt ownerpw (owner1) length 128 perm 2052}'
  build xelatex owner
  expect "no userpw: opens without a password, restricted" "$(encryption owner)" 'print:yes copy:no'
  write_doc emptyuser '\special{pdf:encrypt userpw () ownerpw (owner1) length 128 perm 2052}'
  build xelatex emptyuser
  expect "userpw (): opens without a password, restricted" "$(encryption emptyuser)" 'print:yes copy:no'
  write_doc noowner '\special{pdf:encrypt userpw (open1) length 128 perm 2052}'
  build xelatex noowner
  expect "no ownerpw: the open password is the owner password" "$(encryption noowner -opw open1)" 'Encrypted: +yes'
  password_case "spaces and plain punctuation" 'A b-c.d,e!f?g:h;i+j=k/l@m*n' 'A b-c.d,e!f?g:h;i+j=k/l@m*n'
  password_case "two spaces collapse to one" 'a  b' 'a b' 'a  b'
  password_case "balanced parentheses" 'a(b)c' 'a(b)c'
  password_case "unbalanced ) ends the password" 'a)b' 'a' 'a)b'
  password_case "\\string\\) gives )" 'a\string\)b' 'a)b'
  password_case "\\string\\( gives (" 'a\string\(b' 'a(b'
  password_case "bare # is doubled" 'a#b' 'a##b' 'a#b'
  password_case "\\# gives #" 'a\#b' 'a#b'
  password_case "\\% gives %" 'a\%b' 'a%b'
  password_case "\\string\\\\ gives one backslash" 'a\string\\b' 'a\b'
  password_case "a macro is expanded" '\jobname' 'pw'
  local long=0123456789012345678901234567890123456789
  password_case "128: over 32 characters is cut to 32" "$long" "${long:0:32}"
  write_doc long256 "\\special{pdf:encrypt userpw ($long) ownerpw (owner1) length 256 perm 2052}"
  build xelatex long256
  expect "256: over 32 characters is encrypted, the owner password opens it" "$(encryption long256 -opw owner1)" 'Encrypted: +yes'
  opens_with "256: over 32 characters does not open (full)" long256 "$long" no
  opens_with "256: over 32 characters does not open (cut)" long256 "${long:0:32}" no
}

check_lengths_and_permissions() {
  write_doc rc4 '\special{pdf:encrypt ownerpw (owner1) length 40 perm 2052}'
  build xelatex rc4
  expect "length 40 is RC4" "$(encryption rc4)" 'algorithm:RC4'
  write_doc aes256 '\special{pdf:encrypt ownerpw (owner1) length 256 perm 2052}'
  build xelatex aes256
  echo "info  length 256 on this TeX: $(encryption aes256 | grep -Eo 'algorithm:[A-Z0-9-]+')"
  write_doc noperm '\special{pdf:encrypt ownerpw (owner1) length 128}'
  build xelatex noperm
  echo "info  no perm on this TeX: /P $(permission_value noperm) (bits $(( $(permission_value noperm) + 3904 )))"
  expect "no perm is a default of its own, not everything" "$(permission_value noperm)" '^-3844$'
  local perm want
  while read -r perm want; do
    write_doc perm "\\special{pdf:encrypt ownerpw (owner1) length 128 perm $perm}"
    build xelatex perm
    expect "perm $perm: flags" "$(encryption perm)" "$want"
    expect "perm $perm: exact bits" "$(permission_value perm)" "^$((perm - 3904))\$"
  done <<'TABLE'
0 print:no copy:no change:no addNotes:no
4 print:yes copy:no change:no addNotes:no
2052 print:yes copy:no change:no addNotes:no
2564 print:yes copy:no change:no addNotes:no
2068 print:yes copy:yes change:no addNotes:no
2308 print:yes copy:no change:no addNotes:no
2340 print:yes copy:no change:no addNotes:yes
TABLE
  if command -v pdftotext > /dev/null; then
    expect "copy restriction does not stop text extraction" "$(pdftotext owner.pdf - 2> /dev/null)" 'Hello'
  fi
}

main() {
  local tool
  for tool in xelatex pdflatex pdfinfo; do
    command -v "$tool" > /dev/null || { echo "missing: $tool"; exit 1; }
  done
  xelatex --version | head -1
  check_engines
  check_placement
  check_passwords
  check_lengths_and_permissions
  echo
  if [ "$failures" -eq 0 ]; then echo "all claims hold"; else echo "$failures claim(s) failed"; exit 1; fi
}

main
