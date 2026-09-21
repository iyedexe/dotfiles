# Skills

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

## Install

Project scope: they are picked up automatically when Claude Code runs inside
this repo.

Global scope (available in every project):

```sh
mkdir -p ~/.claude/skills
for d in ~/dotfiles/.claude/skills/*/; do
  ln -sfn "$d" ~/.claude/skills/"$(basename "$d")"
done
```

Invoke with `/clean-code`, `/functional-programming`, etc., or let Claude pick
them up from the description when the task matches.
