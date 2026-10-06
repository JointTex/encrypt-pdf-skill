---
name: encrypt-pdf
description: Produce a password-protected or permission-restricted PDF from the compile itself, by switching to XeLaTeX and using the pdf:encrypt special of dvipdfmx.
---

Use this when the collaborator wants the compiled PDF to need a password to open, or to restrict printing, copying or editing.

## What can and cannot encrypt

- pdfLaTeX cannot. pdfTeX had encryption primitives only from 0.14h (2001) to 1.10a (2003); every current pdfTeX lacks them, and the `pdfcrypt` package stops with "PDF encryption is not supported with this pdfTeX". Do not try `pdfcrypt`, `\pdfcryptsetup` or other packages under pdfLaTeX.
- LuaLaTeX cannot, and the `latex` engine (dvips, then ps2pdf) cannot either.
- XeLaTeX can: its PDF is written by xdvipdfmx, which honours `\special{pdf:encrypt ...}`. This is the only route inside the compile.
- On pdfLaTeX and LuaLaTeX the special is not an error: the compile succeeds and the PDF comes out unprotected, with nothing in the log. This is why step 5 adds a guard.

## When not to do it

Say so before starting if the project looks like one of these, and let the collaborator decide:

- a submission to a journal, a conference system or a preprint server: these generally reject encrypted PDFs, including ones that only restrict permissions;
- a PDF that has to conform to an archival standard such as PDF/A, which does not allow encryption;
- a project synced to a git remote or shared with people who should not know the password (see step 2).

## Steps

1. Ask for what is missing: the open password (user password), the owner password, and which actions to allow (print, copy, edit). Say which passwords you will use before writing them anywhere. Do not make up a password yourself; if asked for one, tell the collaborator to generate it with a password manager, since the open password is the whole protection and a guessable one can be found by trying.
2. Tell the collaborator, before changing anything, that:
   - the passwords will sit in plain text in the source file, so anyone with access to the project, its history or its git remote can read them, and changing the password later does not remove the old one from the history;
   - the editor's PDF preview cannot open a PDF that has an open password yet (it reports that the PDF failed to load), so they should download the PDF to check it; with only an owner password the preview still works;
   - print and copy restrictions are advisory and many viewers and tools ignore them (a command-line text extractor reads the text of a copy-restricted PDF without any password); only the open password actually protects the content.
   Go on only when they agree.
3. Read the compile settings with `read_compile_settings`. If the engine is not `xelatex`, ask before changing it, then switch it with `update_compile_settings`. Note the TeX Live version it reports; it matters for the key length below.
4. Make the document XeLaTeX-ready if it was written for pdfLaTeX:
   - `\usepackage[utf8]{inputenc}` is unneeded under XeLaTeX; remove it, or leave it since it is ignored with a warning.
   - Prefer `\usepackage{fontspec}` over `\usepackage[T1]{fontenc}` and font packages that only target pdfTeX; for CJK text use `xeCJK` or `ctex`.
   - Remove or guard pdfTeX-only primitives such as `\pdfoutput`, `\pdfminorversion`, `\pdfcompresslevel` (`\ifdefined\pdfoutput ... \fi` or the `iftex` package).
   - `microtype` works with reduced features (no font expansion); keep it.
   Compile once after this and fix what the engine change broke before adding the encryption, so the two kinds of problem are not mixed.
5. Put the guard and the special in the root file's preamble, after `\documentclass` and before `\begin{document}`:

   ```latex
   \usepackage{iftex}
   \RequireXeTeX
   \special{pdf:encrypt userpw (OPEN-PASSWORD) ownerpw (OWNER-PASSWORD) length 128 perm 2052}
   ```

   - `\RequireXeTeX` stops the compile with "XeTeX is required to compile this document" on any other engine. Without it, someone switching the engine back later gets an unprotected PDF and no warning. Keep the two lines together with the special and remove them together.
   - The special must be issued before the first page is shipped out. Placed after the first page, xdvipdfmx ignores it silently and the PDF is not encrypted, with nothing in the log.
   - Use one `pdf:encrypt` special only. If there are two, the later one decides the passwords and permissions, so search the project for an existing one before adding yours (`grep` for `pdf:encrypt`).
   - Works the same with `hyperref`, `beamer` and `ctex` classes.
6. Compile. The log does not report encryption either way, so success there proves nothing beyond a clean compile.
7. Tell the collaborator how to check it: download the PDF and open it in a viewer (it should ask for the open password), or on their own computer run `pdfinfo file.pdf` (it prints `Encrypted: yes`, the permissions and the algorithm; add `-upw PASSWORD` when there is an open password) or `qpdf --show-encryption file.pdf`. `read_pdf` and the preview may fail to open an encrypted PDF; that is expected and is not a compile error, so do not undo the change because of it. You cannot confirm the encryption yourself, so do not report it as verified; say that it compiled and how to check.

## The special's options

Passwords:

- `userpw` is the password to open the PDF. Leave it out, or write `userpw ()`, for a PDF anyone can open but whose permissions are restricted.
- `ownerpw` is the password that lifts the restrictions. Always give one, and make it different from the open password: if `ownerpw` is left out the open password becomes the owner password too, and when the two are equal anyone who can open the PDF is its owner, so the restrictions mean nothing.
- Keep each password to 32 characters or fewer. At `length 128` a longer password is cut to its first 32 characters without notice; at `length 256` an open password of 33 characters or more produced a PDF that would not open with either the full or the cut password (only the owner password still opened it).
- Use ASCII letters, digits, spaces and plain punctuation such as `- . , ! ? : ; + = / @ *`. The passwords are read by TeX and then as a PDF string, and several characters change on the way without any error:

  | Character | What happens | If it is needed |
  | --- | --- | --- |
  | `(` `)` | fine when balanced; an unbalanced `)` ends the password there, so `a)b` becomes `a` | `\string\)` or `\string\(` |
  | `#` | doubled: `a#b` becomes `a##b` | `\#` |
  | `%` | starts a TeX comment and breaks the line | `\%` |
  | `\` | read as a TeX command | `\string\\` for one backslash |
  | two or more spaces in a row | collapsed to one: `a  b` becomes `a b` | avoid |
  | `{` `}` `~` | have a meaning to TeX | avoid |

  Accented and CJK characters did work in testing, but how a viewer encodes what is typed differs between viewers, so advise against them.
- A macro inside the parentheses is expanded, so the passwords can be defined once (`\newcommand{\OpenPassword}{...}`) and used in the special. That keeps them in one place; it does not hide them.

Key length:

- `length 128` gives AES-128 and is the safe default (checked on TeX Live 2023 and 2026).
- `length 256` gives AES-256 on TeX Live 2026 but was still written as AES-128 by TeX Live 2023's xdvipdfmx. Use it only when the collaborator asks, and tell them to confirm the algorithm with `pdfinfo` or `qpdf --show-encryption` before relying on it.
- Never use `length 40`: it selects RC4 with a 40-bit key, which is broken.

Permissions:

- `perm` is the PDF permission bit mask (add the values): 4 print, 8 modify, 16 copy and extract, 32 annotate, 256 fill forms, 512 extract for accessibility, 1024 assemble, 2048 high-quality print.
- Always write `perm`. Leaving it out is neither "no restrictions" nor a useful set: xdvipdfmx then falls back to a default of its own (on TeX Live 2026: low-resolution printing, modifying, copying and annotating allowed; forms, accessibility extraction, assembly and high-quality printing not).
- Common values:

  | perm | Allows |
  | --- | --- |
  | 0 | nothing |
  | 4 | low-resolution printing only |
  | 2052 | printing |
  | 2564 | printing, and text extraction for screen readers |
  | 2068 | printing and copying |
  | 2308 | printing and filling forms |
  | 2340 | printing, annotating and filling forms |

  Suggest adding 512 (accessibility) unless the collaborator objects, so the restriction does not lock out screen readers.

## Keeping the working file unprotected

If the collaborator wants to keep editing with the preview working and only sometimes produce the protected PDF, leave the main file alone and add a second root file beside it, for example `main-protected.tex`:

```latex
\RequirePackage{iftex}
\RequireXeTeX
\special{pdf:encrypt userpw (OPEN-PASSWORD) ownerpw (OWNER-PASSWORD) length 128 perm 2052}
\input{main}
```

The protected PDF is then produced by setting this file as the root (`update_compile_settings`, with the collaborator's agreement) and compiling; setting the root back to the main file returns to the ordinary PDF. The engine is one setting for the project, so the main file still has to compile under XeLaTeX. The passwords are in this one file, which is still part of the project and its history.

## Changing or undoing it

- To change a password or the permissions, edit the special and compile again. Copies of the PDF already downloaded keep the old password.
- To undo it, remove the special together with the `\RequireXeTeX` line (and the `iftex` line if nothing else uses it), or delete the second root file and set the root back. Switch the engine back to its previous value only if the collaborator asks; the document may now depend on XeLaTeX.
- The old passwords remain in the project history. If they are used anywhere else, tell the collaborator to change them there.

## When the PDF must stay on pdfLaTeX

Encryption then has to happen after the compile, outside JointTex: for example `qpdf --encrypt USER OWNER 256 -- in.pdf out.pdf` on the collaborator's machine. Say so plainly; do not add scripts to the project that cannot run in the compile. This route also keeps the passwords out of the project source.
