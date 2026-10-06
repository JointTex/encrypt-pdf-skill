# encrypt-pdf

A skill for the [JointTex](https://jointtex.com) Agent that makes the compiled PDF password-protected or permission-restricted, from the compile itself.

## What it does

When a collaborator asks for a PDF that needs a password to open, or that restricts printing, copying or editing, the Agent follows this skill to:

1. ask for the open password, the owner password and the actions to allow;
2. explain the trade-offs before changing anything (the passwords sit in plain text in the source, and print and copy restrictions are advisory), and say when encryption is the wrong thing to do (a journal or preprint submission, PDF/A);
3. switch the project to XeLaTeX if it is on another engine, and adjust a pdfLaTeX document so it still compiles;
4. add a `\special{pdf:encrypt ...}` line to the preamble, which xdvipdfmx turns into an encrypted PDF, behind a `\RequireXeTeX` guard so that a later switch to another engine fails instead of quietly producing an unprotected PDF;
5. say how to check the result (`pdfinfo` or `qpdf --show-encryption`), without claiming a verification the Agent cannot make.

It also covers:

- which characters are safe in a password and how to escape the ones that are not;
- the key lengths and what each TeX Live version really writes;
- the permission values, with a table of common combinations;
- a second root file that produces the protected PDF while the working file stays unprotected and previewable;
- changing or undoing it, and what to do when the document has to stay on pdfLaTeX (encrypt after the compile, outside JointTex, for example with `qpdf`).

## Why XeLaTeX

pdfLaTeX and LuaLaTeX cannot write an encrypted PDF, and neither can the `latex` engine through dvips. XeLaTeX can, because its PDF is written by xdvipdfmx, which honours the `pdf:encrypt` special. That is the only route inside a compile.

## Install

- **From the plugin marketplace.** Open **Plugins** in JointTex, find this skill set, and install `encrypt-pdf` into a project.
- **By hand.** Copy [`encrypt-pdf/SKILL.md`](encrypt-pdf/SKILL.md) into a project as `.jointtex/skills/encrypt-pdf/SKILL.md`.

Either way the skill is an ordinary project file: every collaborator's Agent can load it, and removing it is deleting the file.

## Limits

- The passwords are stored in plain text in the project source, so anyone with access to the project, its history or its git remote can read them.
- Only the open password protects the content. Many viewers ignore print and copy restrictions.
- `length 128` (AES-128) is the default. `length 256` gives AES-256 on TeX Live 2026 but AES-128 on TeX Live 2023, so it has to be checked on the PDF.
- Passwords should be ASCII, 32 characters at most. Some characters change silently on the way from the source to the PDF: an unbalanced `)` cuts the password short and a bare `#` is doubled. The skill lists them with their escapes.
- Other engines do not fail on the special; they ignore it. The guard the skill adds is what turns that into an error.

## Repository layout

```
encrypt-pdf/SKILL.md   the skill
tests/verify.sh        checks the skill's claims against a real TeX installation
README.md
LICENSE
```

A JointTex skill is the `SKILL.md` alone, in a folder named after the skill. Files beside it are not part of the skill.

## Checking the claims

Most of what the skill says about the special (that pdfLaTeX and LuaLaTeX ignore it, where it may be placed, how passwords are read, what each key length and permission value produces) is checked by a script that compiles small documents and reads the result with `pdfinfo` and from the PDF's encryption dictionary:

```sh
bash tests/verify.sh
```

It needs `xelatex`, `pdflatex` and `pdfinfo` (poppler). Last run against TeX Live 2026, where every claim held. Run it again before changing the skill and after a TeX Live update; the result for `length 256` is printed, not enforced, because it depends on the version. Not covered by the script: the `latex` (dvips) route, the `beamer` and `ctex` classes (checked by hand), TeX Live versions other than the installed one, and how individual PDF viewers treat the restrictions.

## License

[MIT](LICENSE)
