# claude-skills: programming books distilled into Claude Code skills

Claude Code skills distilled from classic programming books. Each skill is a
`SKILL.md` with frontmatter (`name`, `description`) followed by the distilled
principles and a checklist.

| Skill | Sources |
|---|---|
| `clean-code` | Clean Code, Code Complete, The Pragmatic Programmer, SICP |
| `functional-programming` | Functional Programming in Scala, SICP |
| `testing-and-debugging` | The Pragmatic Programmer, Code Complete, Clean Code, FP in Scala (property-based testing) |
| `data-engineering` | Designing Data-Intensive Applications, plus construction practices from Code Complete and The Pragmatic Programmer |
| `design-and-architecture` | Design Patterns (GoF), Code Complete, The Pragmatic Programmer, SICP, Clean Code, DDIA |

Layout: one folder per skill, each with a `SKILL.md` (frontmatter with `name`
and `description`, then the principles and a review checklist).

## Install

Claude Code loads skills from `~/.claude/skills/` (every project) and from a
project's own `.claude/skills/`. Link or copy the folders there.

Every project, Linux, macOS, Git Bash or WSL:

```sh
mkdir -p ~/.claude/skills
for d in ~/dotfiles/claude-skills/*/; do
  ln -sfn "$d" ~/.claude/skills/"$(basename "$d")"
done
```

Every project, Windows PowerShell (a junction needs no admin rights):

```powershell
New-Item -ItemType Directory -Force "$HOME\.claude\skills" | Out-Null
Get-ChildItem "$HOME\dotfiles\claude-skills" -Directory | ForEach-Object {
  New-Item -ItemType Junction -Force -Path "$HOME\.claude\skills\$($_.Name)" -Target $_.FullName | Out-Null
}
```

One project only: copy the folders you want into that project's
`.claude/skills/` and commit them with it.

Invoke with `/clean-code`, `/functional-programming`, etc., or let Claude pick
them up from the description when the task matches.

## Other agents

The files follow the open Agent Skills format, so other tools read them as
is. Kilo Code, for example, loads `.claude/skills/` when its Claude Code
compatibility setting is on, or its own `~/.kilo/skills/` if you link the
folders there instead.
