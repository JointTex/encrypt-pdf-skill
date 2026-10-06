---
name: encrypt-pdf
description: Produce a password-protected or permission-restricted PDF from the compile itself, by switching to XeLaTeX and using dvipdfmx's pdf:encrypt special.
---

Use this when the collaborator wants the compiled PDF to need a password to open, or to restrict printing, copying or editing.

## What can and cannot encrypt

- pdfLaTeX cannot. pdfTeX had encryption primitives only from 0.14h (2001) to 1.10a (2003); every current pdfTeX lacks them, and the `pdfcrypt` package stops with "PDF encryption is not supported with this pdfTeX". Do not try `pdfcrypt`, `\pdfcryptsetup` or other packages under pdfLaTeX.
- LuaLaTeX cannot, and the `latex` engine (dvips, then ps2pdf) cannot either.
- XeLaTeX can: its PDF is written by xdvipdfmx, which honours `\special{pdf:encrypt ...}`. This is the only route inside the compile.

## Steps

1. Ask for what is missing: the open password (user password), the owner password, and which actions to allow (print, copy, edit). Say which passwords you will use before writing them anywhere.
2. Tell the collaborator, before changing anything, that:
   - the passwords will sit in plain text in the source file, so anyone with access to the project, its history or its git remote can read them;
   - the editor's PDF preview cannot open a PDF that has an open password yet (it reports that the PDF failed to load), so they should download the PDF to check it; with only an owner password the preview still works;
   - print and copy restrictions are advisory and many viewers ignore them; only the open password actually protects the content.
   Go on only when they agree.
3. Read the compile settings with `read_compile_settings`. If the engine is not `xelatex`, ask before changing it, then switch it with `update_compile_settings`.
4. Make the document XeLaTeX-ready if it was written for pdfLaTeX:
   - `\usepackage[utf8]{inputenc}` is unneeded under XeLaTeX; remove it, or leave it since it is ignored with a warning.
   - Prefer `\usepackage{fontspec}` over `\usepackage[T1]{fontenc}` and font packages that only target pdfTeX; for CJK text use `xeCJK` or `ctex`.
   - Remove or guard pdfTeX-only primitives such as `\pdfoutput`, `\pdfminorversion`, `\pdfcompresslevel` (`\ifdefined\pdfoutput ... \fi` or the `iftex` package).
   - `microtype` works with reduced features (no font expansion); keep it.
5. Put the special in the root file's preamble, after `\documentclass` and before `\begin{document}`:

   ```latex
   \special{pdf:encrypt userpw (OPEN-PASSWORD) ownerpw (OWNER-PASSWORD) length 128 perm 2052}
   ```

   - It must be issued before the first page is shipped out. Placed after the first page, xdvipdfmx ignores it silently and the PDF is not encrypted, with nothing in the log.
   - Leave `userpw` out (or empty) for a PDF anyone can open but whose permissions are restricted.
   - `length 128` gives AES-128 and is the value tested. `length 256` was still written as AES-128 by TeX Live 2023's xdvipdfmx; do not claim AES-256 unless the collaborator confirms it with a tool such as `qpdf --show-encryption`.
   - `perm` is the PDF permission bit mask (add the values): 4 print, 8 modify, 16 copy and extract, 32 annotate, 256 fill forms, 512 extract for accessibility, 1024 assemble, 2048 high-quality print. 2052 allows printing only; 0 allows nothing; 2308 allows printing and filling forms.
   - Use passwords of ASCII letters and digits. Characters such as `\ % # { } ( )` have meaning to TeX or to the PDF string syntax and must not appear unescaped.
6. Compile. The log does not report encryption either way, so success there proves nothing beyond a clean compile.
7. Tell the collaborator how to check it: download the PDF and open it in a viewer (it should ask for the open password), or run `qpdf --show-encryption file.pdf`. `read_pdf` and the preview may fail to open an encrypted PDF; that is expected and is not a compile error, so do not undo the change because of it.

## Undoing it

Remove the `\special{pdf:encrypt ...}` line. Switch the engine back to its previous value only if the collaborator asks; the document may now depend on XeLaTeX.

## When the PDF must stay on pdfLaTeX

Encryption then has to happen after the compile, outside JointTex: for example `qpdf --encrypt USER OWNER 256 -- in.pdf out.pdf` on the collaborator's machine. Say so plainly; do not add scripts to the project that cannot run in the compile.
