---
name: testing-and-debugging
description: Write effective tests and debug systematically. Use when adding unit, integration, or property-based tests, deciding what to test, structuring a test suite, reproducing a bug, reading a stack trace, bisecting a regression, or diagnosing flaky and intermittent failures. Distilled from The Pragmatic Programmer (Hunt & Thomas), Code Complete (McConnell), Clean Code (Martin) and Functional Programming in Scala (Chiusano & Bjarnason).
---

# Testing and Debugging

Testing is about finding out what the code does, not proving it works.
Debugging is the scientific method applied to a program. Both reward
discipline over intuition.

## Part A: Testing

### 1. Why and when (Pragmatic Programmer, Code Complete)

- **Test early, test often, test automatically.** A test that is not run on
  every change will rot. Put it in CI.
- **Testing is design.** If code is hard to test, it is badly coupled. Writing
  the test first (or at least thinking about it first) forces good interfaces:
  small units, injected dependencies, pure logic separated from I/O.
- **Cost of a defect rises with time.** A bug caught in construction costs
  10-100x less than one caught in production (Code Complete's data). Test at
  the level where the bug is cheapest to find.
- **Tests are the first client of your API.** They show how it is meant to be
  used. If the test is awkward, the API is awkward.
- **Ruthless testing:** test until it hurts, then test more. Coverage of
  *behaviours and edge cases*, not lines, is the goal. 100% line coverage with
  no assertions is worth nothing.

### 2. Test structure (Clean Code ch. 9)

- **FIRST:** tests are **F**ast (milliseconds), **I**ndependent (any order, no
  shared state), **R**epeatable (any environment, no network, no clock),
  **S**elf-validating (pass/fail, no manual inspection), **T**imely (written
  with or before the code).
- **One concept per test.** Multiple asserts are fine if they check one
  behaviour; a test that checks three behaviours is three tests.
- **Arrange / Act / Assert** (Given / When / Then). Keep each block short and
  visible. Build a small domain-specific test API (builders, fixtures, custom
  assertions) so the test reads as a specification.
- **Test names are sentences:** `test_refund_is_rejected_after_30_days`, not
  `test_refund_2`. The failing test name should tell you what broke.
- **Tests are production code.** Keep them clean, DRY within reason, no
  duplication of setup, no dead tests. Dirty tests get deleted when they break,
  and then you have no tests.
- **Do not test the implementation.** Test observable behaviour through the
  public interface. A test that breaks on every refactor is coupled to the
  wrong thing.

### 3. What to test (Code Complete ch. 22)

Choose cases deliberately; random poking finds little.

- **Structured basis testing:** at least one test per straight-line path
  through the function. Each `if`, `while`, `and`, `or`, and `case` adds one.
- **Boundaries:** off by one is the most common bug. Test exactly at,
  just below, and just above every boundary: 0, 1, n-1, n, n+1, empty
  collection, single element, max int, empty string, midnight, leap day.
- **Data-flow:** each variable should be defined, used, and killed in a sane
  sequence. Test defined-then-used pairs.
- **Bad data:** too little, too much, wrong type, uninitialised, malformed,
  out of range, negative where positive expected.
- **Good data:** nominal case, minimum normal, maximum normal, old data that
  must still work (compatibility).
- **Error classes that are likely in this code:** look at the bug tracker.
  Defects cluster: 80% of defects are in 20% of routines. Test those harder.
- **Equivalence partitioning:** if two inputs exercise the same path, test
  one of them. Spend the saved budget on a different partition.

### 4. Test levels (Pragmatic Programmer, Code Complete)

| Level | What it checks | Speed | Mocks? |
|---|---|---|---|
| Unit | one function/class in isolation | ms | yes, at boundaries only |
| Integration | components together, real DB/queue in a container | s | few |
| Contract | your service honours the interface consumers rely on | s | consumer-driven |
| End-to-end | user journey through the real system | min | none |
| Property | invariants over generated inputs | ms-s | no |
| Performance | latency/throughput under load | min | no |

- The pyramid: many unit tests, fewer integration, few E2E. E2E tests are
  slow, flaky, and hard to diagnose; use them for critical paths only.
- **Mock only at architectural boundaries** (network, clock, filesystem,
  randomness). Mocking your own classes couples tests to implementation.
  Prefer fakes (in-memory implementations) to mocks that verify calls.
- **Inject the clock and randomness.** `now()` and `random()` as parameters or
  an injected provider. Every flaky time-based test is an un-injected clock.

### 5. Property-based testing (FP in Scala ch. 8)

- Instead of example inputs, state a **law** and generate thousands of cases:
  `reverse(reverse(xs)) == xs`; `sorted(xs)` is sorted and a permutation of
  `xs`; `decode(encode(x)) == x`; `max(xs)` is >= every element.
- **Generators** (`Gen[A]`) compose: `Gen.choose`, `listOf`, `map`,
  `flatMap`. Build domain generators once and reuse them.
- **Shrinking:** on failure, the library minimises the input. A failing case
  with a 2-element list is far easier to debug than one with 500.
- **Where it shines:** serialisation round-trips, parsers, algebraic laws
  (monoid associativity, functor composition), invariants after any sequence
  of operations (stateful/model-based testing), anything with a
  simpler reference implementation (`fast_sort(xs) == slow_sort(xs)`).
- Libraries: ScalaCheck, Hypothesis (Python), fast-check (TS), QuickCheck,
  proptest (Rust).

### 6. Testing pure vs. effectful code (FP in Scala)

- **Pure code needs no mocks.** Inputs in, outputs out. Most tests should be
  of this kind; push logic into the pure core to make that true.
- **Effectful code:** test the description, not the execution. If `IO` /
  commands are values, assert on the value produced. Run the interpreter only
  in a small number of integration tests with a fake interpreter.
- **Test the laws** of your abstractions with property tests.

### 7. Defensive programming and assertions (Code Complete ch. 8)

- **Assertions** document and check assumptions that must be true: "list is
  sorted here", "pointer is not null", "state machine is in X". They catch
  bugs; they are not error handling for expected bad input.
- **Validate at boundaries, assert inside.** Public inputs get validation
  with proper errors; internal invariants get assertions.
- **Fail fast in development, degrade gracefully in production**, and make
  the choice explicit per subsystem.
- **Leave assertions in production** if they are cheap. They turn silent
  corruption into loud failure with a stack trace.
- **Design by contract (Pragmatic Programmer):** preconditions the caller
  guarantees, postconditions the callee guarantees, invariants that always
  hold. Write them down in docstrings even if the language cannot enforce.

## Part B: Debugging

### 8. Mindset (Pragmatic Programmer ch. 3)

- **Don't panic.** Step back, breathe, do not thrash.
- **Fix the problem, not the blame.** It does not matter whose bug it is.
- **Don't assume it, prove it.** "That can't be the cause" is not evidence.
  Every assumption is a candidate hypothesis.
- **"select" isn't broken.** The bug is almost never in the OS, compiler,
  database, or well-used library. It is in your code or your understanding.
  Suspect yourself first; suspect the platform last.
- **Read the error message.** All of it. Then read it again. The answer is
  often in the second line of the stack trace, or the first line you skipped.

### 9. The scientific method for debugging (Code Complete ch. 23)

1. **Stabilise the error.** Make it reproduce reliably. An intermittent bug
   is a bug whose trigger you have not yet found: narrow the conditions
   (data, timing, environment, concurrency) until it fails every time.
   Turn it into a failing automated test before fixing.
2. **Locate the source.**
   - Gather data: logs, inputs, stack trace, git blame, last known good.
   - Form a hypothesis that explains *all* the data, not some.
   - Design an experiment that would *disprove* it.
   - Run, observe, refine. Keep a written log of what you tried.
3. **Fix the defect.** Understand it fully before touching code. A fix you
   do not understand is a new bug. Fix the cause, not the symptom (do not
   special-case the failing input).
4. **Test the fix.** The reproduction test now passes; the rest of the suite
   still passes.
5. **Look for similar defects.** Bugs come in families. Search the codebase
   for the same pattern.

### 10. Techniques for locating the cause

- **Reproduce with the smallest input.** Shrink the failing case until you
  cannot shrink further. Most bugs become obvious at that size.
- **Binary search / bisect.** Over the code path (comment out halves, add
  probes), over the data (halve the input), over history (`git bisect` between
  known-good and known-bad commits). This is the single most powerful
  debugging tool; use it whenever you have a working and a broken state.
- **Rubber ducking.** Explain the problem, line by line, out loud or in
  writing to someone (or something) who knows nothing. The act of explaining
  surfaces the false assumption.
- **Tracing.** When a debugger is impractical (concurrency, production,
  remote), add structured log lines with timestamps and the values that
  matter. Log at entry and exit of the suspect region. Remove or downgrade
  afterwards.
- **Use the debugger deliberately.** Set a breakpoint at the last point you
  are sure is correct and step forward; do not step from `main`.
- **Check what changed.** New bug in old code means a changed input, data,
  dependency, environment, or config. `git log`, deploy history, dependency
  lockfile diff.
- **Examine the values, not the code.** Print the actual runtime data; you
  have already read the code and it looked right.
- **Look for the common ones:** off-by-one, wrong operator precedence,
  integer division, mutable default arguments, aliasing (two names for one
  object), uninitialised or reused variables, unit/timezone mismatch,
  encoding, floating-point comparison, race on shared state, exception
  swallowed by a bare `except`.
- **Take a break.** Fresh eyes find in minutes what tired eyes miss in hours.

### 11. Debugging concurrency and distributed systems

- Assume the interleaving you did not think of is the one that happens.
- Reproduce with stress: run the test 1000 times, add random sleeps, reduce
  the thread pool to one, or increase it to many.
- Log with a correlation ID across services; align clocks or use logical
  timestamps.
- Check for: unguarded shared state, lock ordering (deadlock), retries without
  idempotency (duplicate side effects), timeouts shorter than the slowest
  legitimate call, at-least-once delivery treated as exactly-once.

### 12. Don't-do list

- Don't fix by guessing and re-running ("shotgun debugging"). Every change
  without a hypothesis destroys evidence.
- Don't change more than one thing per experiment.
- Don't leave debug prints, disabled tests, or `sleep(1)` fixes in the commit.
- Don't skip, disable, or loosen a failing test to get green. A failing test
  is information; a flaky test is a bug (usually shared state, time, or order
  dependence) and gets fixed, not retried.
- Don't declare victory when the symptom disappears. Confirm the cause.

## Checklist

**Writing tests**
1. Is each test fast, independent, repeatable, self-validating?
2. Does the test name state the behaviour?
3. Boundaries, empty, one, many, max, bad data: covered?
4. Is there a law I could property-test instead of five examples?
5. Am I mocking a boundary, or my own implementation?
6. Is the clock / randomness injected?

**Debugging**
1. Can I reproduce it on demand? Is that reproduction a test?
2. What is the smallest failing input?
3. What is the last state I am sure is correct? Bisect from there.
4. What assumption have I not verified with actual runtime data?
5. What changed between working and broken?
6. Does my fix address the cause, and are there siblings of this bug?
