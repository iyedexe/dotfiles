---
name: clean-code
description: Write, review, and refactor code for readability and maintainability. Use when writing new code, reviewing a diff, naming things, splitting functions or modules, removing duplication, or deciding how much to comment. Distilled from Clean Code (Martin), Code Complete (McConnell), The Pragmatic Programmer (Hunt & Thomas) and SICP (Abelson & Sussman).
---

# Clean Code

The goal is code that a reader who did not write it can understand quickly and
change safely. Readability wins over cleverness; the reader's time is worth more
than the writer's. Every rule below is a heuristic, not a law: when a rule makes
the code harder to understand, break the rule and say why in a comment.

## 1. The core idea: manage complexity (Code Complete)

Software's primary technical imperative is managing complexity. Nobody can hold
a whole system in their head, so the job is to make each piece understandable in
isolation.

- **Minimize what a reader must keep in mind at once.** Small interfaces, few
  parameters, local reasoning.
- **Hide information.** Ask "what does this module need to hide?" (a data
  format, a business rule, a third-party API). Expose the minimum.
- **Form consistent abstractions.** A class or module should present one level
  of abstraction; do not mix "open socket" with "compute invoice total".
- **Prefer the obvious solution.** If a technique needs an explanation, it is
  probably wrong for this codebase.

## 2. Naming (Clean Code, Code Complete)

Names are the primary documentation. Spend time on them.

- **Reveal intent.** `elapsed_days` not `d`. `is_eligible_for_refund` not `check`.
- **Name length ≈ scope size.** `i` is fine for a three-line loop; a module-level
  variable needs a full name. Code Complete's data: names of 10 to 16 characters
  were easiest to debug.
- **Be searchable and pronounceable.** No `genymdhms`. No single-letter globals.
- **One word per concept.** Do not mix `fetch`, `retrieve`, `get` for the same
  operation across a codebase.
- **Say what, not how.** `user_count` not `user_array_length`.
- **Booleans read as predicates.** `is_open`, `has_children`, `can_retry`.
- **Avoid encodings and noise words.** No Hungarian notation, no `Manager`,
  `Processor`, `Data`, `Info` suffixes that add nothing. Avoid `the_`, `a_`.
- **Functions are verbs, classes are nouns.** `render_invoice()`, `Invoice`.
- **Opposites are precise pairs.** `begin/end`, `first/last`, `min/max`,
  `open/close`, `source/target`, not `begin/last`.

## 3. Functions (Clean Code, with a critical perspective)

Martin's rules, and where to push back:

- **Do one thing** at one level of abstraction. A function that both parses input
  and writes to a database is two functions. Test: can you extract a meaningful
  chunk with a name that is not just a restatement of its body?
- **Small, but not dogmatically.** Martin says 2 to 4 lines. Take that as
  "shorter than you think" rather than a hard limit. Extracting every fragment
  into a named function scatters the logic across 20 tiny methods and forces the
  reader to jump around. A 30-line function with clear sequential steps and no
  nested branching is often clearer than six 5-line ones. McConnell's data:
  routines up to ~100-200 lines are not measurably worse; deep nesting is.
- **Few arguments.** 0-2 ideal, 3 needs justification, more means a parameter
  object or the function does too much. Never pass boolean flags that switch
  behaviour; split into two functions.
- **No side effects hidden behind a name.** `check_password()` must not also
  initialise a session. If it mutates, the name says so.
- **Command-query separation.** Return a value or change state, not both.
  `set_and_return` is a smell.
- **Prefer exceptions to error codes**, and keep try/except bodies small: put the
  guarded work in its own function.
- **One return is not required.** Early guard returns at the top of a function
  are clearer than nested `if`.
- **Limit nesting depth.** More than 2-3 levels means: extract, invert the
  condition, or use early return. Nesting is the strongest predictor of
  comprehension difficulty in McConnell's data.

## 4. Comments (Clean Code, Code Complete)

- **Comments compensate for failure to express in code.** First try renaming or
  extracting; comment only when the code genuinely cannot say it.
- **Good comments:** intent ("we retry because the upstream API drops ~1%"),
  warnings of consequences, legal headers, explanations of a non-obvious
  decision, TODOs that are tracked, public API docs.
- **Bad comments:** restating the code, journal/changelog comments (git does
  this), commented-out code (delete it, git remembers), closing-brace comments,
  noise (`// constructor`), attribution (`// added by X`).
- **Comments rot.** A comment that lies is worse than none. Update or delete.
- **Comment the "why", not the "what".** The code says what.

## 5. Formatting and structure (Clean Code)

- **Vertical density:** related lines together, blank lines between concepts.
- **Newspaper metaphor:** high-level first, details below. Callers above callees.
- **Declare variables close to use.** Not all at the top.
- **Use the team's formatter and stop arguing.** Consistency beats preference.

## 6. Duplication and orthogonality (Pragmatic Programmer)

- **DRY: every piece of knowledge has one authoritative representation.** This
  is about knowledge, not text. Two identical-looking functions that encode
  different business rules are not duplication. Two different-looking functions
  that both know "orders over 100 get free shipping" are.
- **Don't DRY prematurely.** Two similar lines are not a pattern. Wait for three
  and for evidence that they change together (Rule of Three).
- **Orthogonality:** unrelated things should not affect each other. A change to
  the database layer should not touch the UI. Test: "If I dramatically change
  one component, how many others are affected?" Answer should be one.
- **ETC: Easier To Change.** Every design decision is judged by whether it makes
  the code easier to change later. When unsure, pick the reversible option.
- **Decoupling:** Tell, don't ask. Don't chain method calls through other
  objects' internals (Law of Demeter: talk to your direct collaborators only).
  Avoid global data. Avoid inheritance for code reuse; use composition,
  interfaces, or mixins.

## 7. Classes and modules (Clean Code, Code Complete)

- **Single Responsibility:** a class has one reason to change. If you need "and"
  to describe it, split it.
- **High cohesion:** methods use most of the instance fields. Many methods that
  each touch a different subset of fields means two classes are hiding inside.
- **Encapsulate.** Expose behaviour, not data. Getters and setters for every
  field is a data structure pretending to be an object; either is fine, but pick
  one (Clean Code's "objects vs data structures").
- **Open for extension, closed for modification:** adding a new case should
  add code, not edit every switch statement. If there is one switch on a type,
  keep it in one place (a factory) instead of duplicating it.
- **Dependencies point inward** toward abstractions. Concrete details (DB, HTTP,
  filesystem) depend on the domain, never the reverse.

## 8. Abstraction (SICP)

- **Build abstraction barriers.** A layer uses only the interface of the layer
  below, never its representation. Change the representation of a rational
  number, a point, a queue, and nothing above the barrier changes.
- **Constructors and selectors first.** Decide how data is created and accessed
  before deciding how it is stored.
- **Closure property:** combinators that produce the same kind of thing they
  consume (lists of lists, functions returning functions) compose without
  limit. Prefer these to special-case APIs.
- **Stratified design:** a system is a sequence of languages, each built on the
  one below (primitives, then means of combination, then means of abstraction).
  Write your domain layer as a small vocabulary, not a pile of procedures.

## 9. Error handling and defensive code (Clean Code, Code Complete)

- **Fail fast, close to the cause.** Validate inputs at boundaries; inside the
  trusted core, use assertions for "this can never happen".
- **Don't return null; don't pass null.** Return empty collections, Optionals,
  or raise.
- **Wrap third-party APIs** behind your own thin interface so their exceptions
  and churn stay at the boundary.
- **Exceptions carry context:** what was attempted, with what values, and why it
  failed.
- **Barricade:** public inputs are dirty and get sanitised at the edge; internal
  code assumes clean data and asserts.

## 10. Refactoring habits (Pragmatic Programmer, Code Complete)

- **Boy Scout Rule:** leave the code slightly cleaner than you found it, in the
  same commit if small, a separate commit if larger.
- **Refactor early, refactor often,** but never while adding a feature. Change
  structure or behaviour, not both at once.
- **Broken windows:** one tolerated hack signals that hacks are acceptable. Fix
  or board it up (a tracked TODO with a reason).
- **Don't live with a smell you can name:** long parameter lists, feature envy
  (a method that uses another class's data more than its own), shotgun surgery
  (one change touches many files), primitive obsession, magic numbers.
- **Good-enough software:** know when to stop. Perfect is the enemy of shipped;
  the user, not the developer, decides how good is good enough.

## Review checklist

When reviewing or writing code, walk through:

1. Can I understand each function without reading its callees?
2. Does every name say what the thing is or does, at the right level?
3. Is there a hidden side effect, a boolean flag, or a null return?
4. Is nesting deeper than 3? Can a guard clause flatten it?
5. Is knowledge duplicated (not just text)?
6. Does a comment explain why, or just restate what?
7. Would a change to one concern ripple into another (orthogonality)?
8. Are boundaries (I/O, third parties) wrapped and validated?
9. Is there dead code, commented-out code, or an unused parameter?
10. Is this the simplest thing that works, and easy to change later?
