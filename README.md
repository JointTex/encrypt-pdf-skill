# encrypt-pdf

A skill for the [JointTex](https://jointtex.com) Agent that makes the compiled PDF password-protected or permission-restricted, from the compile itself.

## What it does

When a collaborator asks for a PDF that needs a password to open, or that restricts printing, copying or editing, the Agent follows this skill to:

1. ask for the open password, the owner password and the actions to allow;
2. explain the trade-offs before changing anything (the passwords sit in plain text in the source, and print and copy restrictions are advisory);
3. switch the project to XeLaTeX if it is on another engine, and adjust a pdfLaTeX document so it still compiles;
4. add a `\special{pdf:encrypt ...}` line to the preamble, which xdvipdfmx turns into an encrypted PDF;
5. say how to check the result.

It also covers how to undo the change, and what to do when the document has to stay on pdfLaTeX (encrypt after the compile, outside JointTex, for example with `qpdf`).

## Why XeLaTeX

pdfLaTeX and LuaLaTeX cannot write an encrypted PDF, and neither can the `latex` engine through dvips. XeLaTeX can, because its PDF is written by xdvipdfmx, which honours the `pdf:encrypt` special. That is the only route inside a compile.

## Install

- **From the plugin marketplace.** Open **Plugins** in JointTex, find this skill set, and install `encrypt-pdf` into a project.
- **By hand.** Copy [`encrypt-pdf/SKILL.md`](encrypt-pdf/SKILL.md) into a project as `.jointtex/skills/encrypt-pdf/SKILL.md`.

Either way the skill is an ordinary project file: every collaborator's Agent can load it, and removing it is deleting the file.

## Limits

- The passwords are stored in plain text in the project source, so anyone with access to the project, its history or its git remote can read them.
- Only the open password protects the content. Many viewers ignore print and copy restrictions.
- `length 128` (AES-128) is the tested key length.
- Passwords should be ASCII letters and digits; characters with a meaning in TeX or in PDF strings need escaping.

## Repository layout

```
encrypt-pdf/SKILL.md   the skill
README.md
LICENSE
```

A JointTex skill is the `SKILL.md` alone, in a folder named after the skill. Files beside it are not part of the skill.

## License

[MIT](LICENSE)
