---
name: functional-programming
description: Apply functional programming principles in any language (Scala, Python, TypeScript, Rust, Haskell). Use when designing pure functions, modelling data with algebraic data types, handling errors with Option/Either, managing state or side effects functionally, working with monoids/functors/monads, laziness and streams, or refactoring imperative code toward a pure core. Distilled from Functional Programming in Scala (Chiusano & Bjarnason) and SICP (Abelson & Sussman).
---

# Functional Programming

FP is programming with pure functions and composing them. Everything else
(types, monads, laziness) exists to make that practical. The payoff is local
reasoning: you can understand a piece of code by looking only at it.

## 1. Purity and referential transparency (FP in Scala ch. 1)

- **A function is pure** if its output depends only on its inputs and it does
  nothing observable besides return a value. No mutation of shared state, no
  I/O, no exceptions, no reading the clock or a random generator.
- **Referential transparency (RT):** an expression can be replaced by its value
  anywhere without changing the program. `x = f(2); x + x` must equal
  `f(2) + f(2)`. RT is what makes the **substitution model** (SICP) valid: you
  evaluate a program by substituting values for names, like algebra.
- **Test for purity:** could you memoize it? Could you call it twice and drop
  one result? Could you run it in a different order? If any answer is no, it is
  not pure.
- **Side effects are not forbidden; they are pushed to the edge.** The
  architecture that falls out is a **pure core and an imperative shell**: pure
  functions compute a *description* of what to do, a thin outer layer executes
  it. Example: `charge(cc, amount)` should not call the payment API; it should
  return a `Charge` value. A separate function batches and sends the charges.
- **Why bother:** pure functions are trivially testable (no mocks), parallelise
  freely (no shared state), compose (output of one is input of another), and are
  easier to read because nothing hidden happens.

## 2. Higher-order functions and abstraction (SICP ch. 1, FP in Scala ch. 2)

- Functions are values. Pass them, return them, store them.
- **Extract the pattern, parametrise the variation.** `sum_of_squares`,
  `sum_of_cubes`, `sum_of_ints` become `sum(f, a, b)`. Then `sum` itself is a
  fold. Then a fold over any structure is a Foldable. Each step removes
  duplication of *control structure*, not just of text.
- **Follow the types.** In a polymorphic function like
  `compose[A,B,C](f: B => C, g: A => B): A => C` there is exactly one sensible
  implementation. Let the signature drive the body.
- **Currying and partial application** turn multi-argument functions into
  builders of functions. Use them to fix configuration early and pass a
  simpler function downstream.
- **Loops become recursion or folds.** Tail recursion for iteration; `foldLeft`
  / `foldRight` / `reduce` for accumulation; `map` / `filter` / `flatMap` for
  transformation. Write the recursive version to understand, then use the
  library combinator.

## 3. Data: immutability and algebraic data types (FP in Scala ch. 3)

- **Data is immutable.** "Modifying" returns a new value; structural sharing
  makes this cheap (a cons list's tail is shared, not copied).
- **Algebraic data types (ADTs)** model a domain as sums (`A or B`) of products
  (`A and B`). `Shape = Circle(r) | Rect(w, h)`. In Scala: sealed trait + case
  classes; in Python: `Union` of frozen dataclasses or `Enum`; in TypeScript:
  discriminated unions; in Rust: `enum`.
- **Pattern matching** destructures ADTs and the compiler checks
  exhaustiveness. This is the FP replacement for the visitor pattern and for
  `if isinstance` chains. Add a case and the compiler tells you every place to
  update.
- **Make illegal states unrepresentable.** Instead of `status: str, error: str
  | None`, use `Success(value) | Failure(error)`. If a field is only meaningful
  in one state, it belongs in that variant.
- **Data abstraction (SICP ch. 2):** define constructors and selectors first, hide
  the representation behind them, and program against the interface. Pairs can
  build lists, trees, tables, and anything else (closure property).

## 4. Errors without exceptions (FP in Scala ch. 4)

- **Exceptions break RT** and are not visible in types. Replace them with
  values: `Option[A]` (present or absent), `Either[E, A]` (success or a typed
  error), `Try` / `Result`.
- **Combinators over pattern matching:** `map`, `flatMap`, `getOrElse`,
  `orElse`, `filter`, `sequence`, `traverse`. Chain computations that may fail
  and handle the failure once, at the end. In Python this is a `Result` type or
  careful use of `Optional` with early return; the principle is the same.
- **`lift`** turns an ordinary function `A => B` into `Option[A] => Option[B]`,
  so existing code does not need rewriting.
- **`sequence` / `traverse`:** turn a `List[Option[A]]` into `Option[List[A]]`.
  Any time you map a failing function over a collection you want `traverse`.
- **Accumulate errors** when validating (a `Validated` type with a semigroup on
  the error side) versus **short-circuit** on the first failure (`Either`).
  Pick deliberately.
- Reserve exceptions for truly unrecoverable programmer errors (bugs).

## 5. Strictness, laziness, and streams (FP in Scala ch. 5, SICP 3.5)

- **Strict** evaluation computes arguments before the call; **lazy** (non-strict)
  defers until needed. `&&`, `||`, `if` are lazy in every language.
- **Lazy lists / streams:** a head plus a *thunk* for the tail. They separate
  *describing* a computation from *running* it, so `stream.map(f).filter(p)
  .take(10)` does no more work than needed and can be infinite.
- **Memoize thunks** (`lazy val`, `functools.cache`) so a deferred value is
  computed at most once.
- **Streams as a modelling tool (SICP):** model time-varying state as a stream of
  values rather than a mutable variable. A bank balance is a stream of
  balances derived from a stream of transactions; no assignment needed. This is
  the conceptual root of reactive streams and event sourcing.
- **Unfold** is the dual of fold: build a structure from a seed
  (`unfold(seed)(s => Option((a, s')))`). Fibonacci, iterators, and pagination
  are unfolds.

## 6. Purely functional state (FP in Scala ch. 6)

- A random-number generator that mutates internal state is not pure. The pure
  version returns the value *and the next state*: `RNG => (A, RNG)`.
- Generalise to `State[S, A] = S => (A, S)`. `map`, `flatMap`, `sequence` on
  `State` let you thread state through a computation without ever naming it
  explicitly. A `for`-comprehension over `State` reads like imperative code but
  is pure.
- **Pattern:** whenever you find yourself passing a context/accumulator/counter
  through many calls, that is a `State` (or `Reader` for read-only context,
  `Writer` for a log).
- **SICP's warning (3.1):** the moment you introduce assignment, the substitution
  model dies and you need the environment model; identity vs. equality becomes a
  question; order of evaluation matters. Assignment is the price of modularity
  in some designs. Pay it knowingly and locally.

## 7. Designing functional libraries (FP in Scala ch. 7-9)

The book's method for designing any API:

1. Start with a concrete use case and write the *ideal* client code.
2. Discover the primitives: what is the smallest set of operations from which
   everything else derives? (`unit`, `map2`, `fork` for parallelism;
   `string`, `or`, `many`, `flatMap` for parsers.)
3. Express derived operations in terms of primitives.
4. Write down the **laws** the operations must satisfy
   (`map(unit(x))(f) == unit(f(x))`, `fork(x) == x`). Laws constrain
   implementations and drive property-based tests.
5. Only then choose the representation.

Concrete outcomes: a parallelism library (`Par`) that separates describing a
parallel computation from running it on a thread pool; a parser combinator
library where a parser is a value and grammars are built by composition;
a property-based testing library (`Gen`, `Prop`) where tests are generated
from laws.

## 8. Common structures (FP in Scala ch. 10-12)

Recognise these when they appear; they are the vocabulary of composition.

| Structure | Interface | Laws | Use it when |
|---|---|---|---|
| **Monoid** | `combine(a, b)`, `empty` | associative; `empty` is identity | you need to fold, merge, or parallel-reduce: sums, string concat, map merge, max, `Option` combine, functions `A => M` |
| **Functor** | `map(fa)(f)` | identity; composition | you have a container/context and want to transform what is inside without touching the context |
| **Applicative** | `unit`, `map2` (or `ap`) | left/right identity; associativity; naturality | independent effects combined: validation that accumulates errors, parallel execution, zipping |
| **Monad** | `unit`, `flatMap` | left/right identity; associativity | dependent sequencing: the next step needs the previous result. `Option`, `Either`, `List`, `State`, `IO`, `Future`, parsers |
| **Traversable** | `traverse(fa)(f: A => G[B]): G[F[B]]` | naturality; identity; sequential composition | turn a structure of effects inside out: `List[Option[A]] => Option[List[A]]` |
| **Foldable** | `foldMap`, `foldLeft`, `foldRight` | consistency with `toList` | reduce any structure with a monoid |

- **Monoids are for parallelism.** Associativity means you can split the work
  anywhere and combine. Map-reduce is `foldMap` with a monoid.
- **Monads are for sequencing.** The `for`/`do`/`async-await` syntax in every
  language is `flatMap` chaining. `flatMap` lets a later step depend on an
  earlier result; `map2`/applicative cannot, which is why applicative can run
  in parallel and monad cannot.
- **Do not name them in code review unless the team knows them.** Say "this is
  associative so we can parallelise" rather than "this is a monoid".

## 9. Effects and I/O (FP in Scala ch. 13-15)

- **An `IO[A]` value is a description of a side-effecting program** that yields
  an `A` when run. Nothing happens until an interpreter at the very edge of the
  program (`main`) runs it. Building the description is pure.
- This makes effects **first-class values**: you can store, compose, retry,
  time out, and test them without executing them.
- **Free monads / tagless final** separate the *program* (a data structure or
  an abstract algebra) from its *interpreter* (production, test, logging). Swap
  interpreters to test without mocks.
- **Local mutation is fine** if it cannot escape (the `ST` monad idea).
  An in-place quicksort that takes an immutable array, copies it, mutates the
  copy, and returns an immutable result is externally pure.
- **Streaming I/O:** process files, sockets, and event streams as pull-based
  `Process[I, O]` transducers. Resources are acquired and released
  deterministically, memory stays constant, and stages compose with `|>`.

## 10. Practical translation to non-FP languages

- **Python:** frozen dataclasses, `typing.Union`/`Literal` for ADTs,
  `match` statement, `functools.reduce/partial/cache`, generators as lazy
  streams, `itertools`, a small `Result` type. Avoid mutating arguments; return
  new values. Keep I/O in `main` and thin adapters.
- **TypeScript:** discriminated unions, `readonly`, `as const`, fp-ts / effect.
- **Rust:** `enum`, `Option`/`Result` with `?`, iterators are lazy, ownership
  enforces "no shared mutation".
- **Any language:** pure core + imperative shell; make functions total (handle
  every input, no exceptions for expected cases); pass dependencies in as
  arguments; prefer expressions to statements.

## Checklist

1. Is this function pure? If not, can the effect be moved to the edge and the
   function return a description or value instead?
2. Is the domain modelled as ADTs with illegal states unrepresentable?
3. Are errors in the type signature (`Option`/`Either`/`Result`) rather than
   thrown?
4. Is state threaded explicitly (`State`, accumulator) rather than mutated?
5. Is there a fold, map, or traverse hiding in that loop?
6. Is the operation associative? Then it can be parallelised and
   incrementally computed.
7. Have you written down the laws your API should obey, and tested them?
8. Is evaluation lazy where the work may be unnecessary or infinite?
