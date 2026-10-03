---
name: design-and-architecture
description: Design software at module, service, and system level. Use when structuring a new project or feature, choosing between design patterns, deciding module boundaries and interfaces, reducing coupling, planning for change, evaluating an architecture, or reviewing a design document. Distilled from Design Patterns (Gamma, Helm, Johnson, Vlissides), Code Complete (McConnell), The Pragmatic Programmer (Hunt & Thomas), SICP (Abelson & Sussman), Clean Code (Martin) and Designing Data-Intensive Applications (Kleppmann).
---

# Design and System Architecture

Design is the activity of deciding what depends on what. Good design makes
the likely changes cheap and the unlikely ones possible. There is no correct
design, only trade-offs made deliberately; write them down.

## 1. What design is (Code Complete ch. 5)

- **Design is a wicked problem:** you understand it only by solving it. Expect
  to iterate; the first design is a sketch. Prototype the risky parts.
- **Design is heuristic, not deterministic.** Keep a toolbox of heuristics
  (below) and apply the ones that fit.
- **Levels of design:** system, subsystems/packages, classes, routines. Do
  the top levels enough to find the seams, then design each piece in detail
  when you build it. Big up-front design of everything is waste; no design is
  chaos. Do enough to know the shape and the risks.
- **Desirable characteristics:** minimal complexity, ease of maintenance,
  loose coupling, extensibility, reusability, high fan-in (many callers of a
  utility), low fan-out (a class uses few others), portability, leanness,
  stratification (consistent level of abstraction per layer), standard
  techniques (nothing exotic).

## 2. Design heuristics (Code Complete ch. 5, Pragmatic Programmer)

- **Find real-world objects,** but do not stop there: also identify
  abstractions that exist only in the software (a pipeline, a scheduler).
- **Form consistent abstractions.** Every interface presents one coherent
  concept at one level.
- **Encapsulate.** Abstraction says "you may look at an object at a high
  level"; encapsulation says "you may not look at any other level".
- **Information hiding** is the most valuable heuristic. For each module ask
  "what secret does this hide?" Design decisions that are likely to change
  (data formats, algorithms, third-party APIs, business rules) are secrets.
  Hide them behind an interface so a change stays local.
- **Identify areas likely to change** and isolate them. Sources of change:
  business rules, hardware and platform dependencies, I/O formats, non-standard
  language features, difficult design and construction areas, status
  variables, data-size constraints. Put a barrier around each.
- **Keep coupling loose.** Rate coupling by size (how many things cross the
  interface), visibility (explicit parameters beat globals), flexibility (can
  it be called from elsewhere). Data-parameter coupling is fine;
  global-data and control coupling (passing a flag that tells the callee what
  to do) are not.
- **Orthogonality (Pragmatic Programmer):** components independent, each
  with one purpose. Test by asking how many modules a requirement change
  touches. Orthogonal systems are easier to test, reuse, and understand.
- **Reversibility:** there are no final decisions. Isolate anything that would
  be expensive to reverse (database vendor, framework, message format) behind
  an abstraction so you can change your mind. Do not over-abstract what is
  cheap to reverse.
- **Design for test.** If a design is hard to test in isolation, the coupling
  is wrong.
- **Prefer the simplest design that works** (KISS, YAGNI). Complexity you
  add today is paid for on every future change.
- **Choose bottom-up or top-down** per problem, and usually both:
  top-down finds the decomposition, bottom-up finds the reusable building
  blocks.

## 3. Principles for object-oriented design (GoF ch. 1, Clean Code)

Two GoF principles underlie every pattern:

1. **Program to an interface, not an implementation.** Clients depend on
   abstract types; concrete classes are chosen in one place (a factory,
   DI container, or `main`).
2. **Favour object composition over class inheritance.** Inheritance is
   white-box reuse: subclasses see and depend on parent internals, and the
   hierarchy is fixed at compile time. Composition is black-box, changeable at
   runtime, and keeps each class focused. Inherit only for true "is-a" with
   substitutability (Liskov). Delegation is the general mechanism.

Plus: **encapsulate what varies.** Find the aspect that changes, put it
behind an interface, and let the rest of the system stay stable.

SOLID as a checklist (Clean Code): Single responsibility; Open/closed (extend
by adding, not editing); Liskov substitution (subtypes honour the parent's
contract); Interface segregation (small role interfaces, clients see only
what they use); Dependency inversion (high-level policy does not depend on
low-level detail; both depend on abstractions).

## 4. The GoF pattern catalogue, by the problem it solves

Use a pattern only when you have the problem it solves. Naming the pattern in
code (`Strategy`, `Observer`) is good documentation *when* the team knows the
vocabulary. Many patterns collapse into a function or closure in languages
with first-class functions; the intent still applies.

### Creational (who creates objects, and how)

| Pattern | Problem | Modern note |
|---|---|---|
| **Factory Method** | subclasses decide which concrete class to instantiate | often just a function returning the interface |
| **Abstract Factory** | create families of related objects without naming concrete classes (UI toolkit per platform) | a record of constructor functions |
| **Builder** | construct a complex object step by step; same steps, different representations | fluent builders, keyword args, config dataclasses |
| **Prototype** | create by copying an existing instance | `copy`, `dataclasses.replace`, `.copy()` |
| **Singleton** | exactly one instance, globally accessible | usually a mistake: hidden global state, hard to test. Pass the dependency in instead |

### Structural (how objects are composed)

| Pattern | Problem | Modern note |
|---|---|---|
| **Adapter** | make an existing interface match the one clients expect | the standard way to wrap third-party libraries at the boundary |
| **Bridge** | decouple an abstraction from its implementation so both vary independently (shapes × renderers) | avoid combinatorial subclass explosion |
| **Composite** | tree structures where leaves and containers are treated uniformly (file systems, UI trees, expression ASTs) | recursive ADT + fold |
| **Decorator** | add responsibilities to an object dynamically by wrapping (logging, caching, retry around a client) | function decorators, middleware |
| **Facade** | one simple interface over a complex subsystem | the entry point of a module |
| **Flyweight** | share fine-grained objects to save memory (glyphs, interned strings) | intern, cache, immutable values |
| **Proxy** | placeholder controlling access: lazy loading, remote object, access control, caching | client stubs, ORMs' lazy relations |

### Behavioural (how objects communicate and divide responsibility)

| Pattern | Problem | Modern note |
|---|---|---|
| **Strategy** | interchangeable algorithms behind one interface (sorting policy, pricing rule) | pass a function |
| **Template Method** | fixed skeleton of an algorithm with overridable steps | higher-order function with hooks |
| **Observer** | one-to-many change notification without coupling subject to observers | event emitters, pub/sub, reactive streams |
| **Command** | reify a request as an object: queue it, log it, undo it | first-class functions / event objects; the seed of event sourcing |
| **State** | object behaviour changes with internal state; avoid giant switch on state | ADT + pattern match, state machine libraries |
| **Chain of Responsibility** | pass a request along handlers until one handles it | middleware pipelines |
| **Iterator** | traverse a collection without exposing its representation | built into every modern language; generators |
| **Mediator** | centralise complex communication among objects | a coordinator/service class; keep it from becoming a god object |
| **Memento** | capture and restore object state without breaking encapsulation | immutable snapshots |
| **Visitor** | add operations over a fixed object structure without changing the classes | pattern matching on ADTs; use when types are stable and operations grow |
| **Interpreter** | represent a grammar and evaluate sentences | ASTs + eval; see metalinguistic abstraction below |

**Pattern anti-usage:** applying a pattern before the problem exists
("pattern-itis"), a Singleton for convenience, Abstract Factory for one
implementation, Visitor when adding a method would do.

## 5. Abstraction as language design (SICP)

- **Stratified design:** build a system as layers of vocabulary. Each layer
  gives primitives, means of combination, and means of abstraction for the
  layer above. The picture-language example: primitive painters, combiners
  (`beside`, `below`), and abstractions (`square-limit`). Ask of your
  domain layer: what are its primitives and combinators?
- **Abstraction barriers:** define the interface (constructors, selectors,
  operations) and let representation change beneath it.
- **Data-directed programming:** dispatch on the type of data through a table
  (`(get 'area 'circle)`) instead of a chain of conditionals. Adding a type
  adds a row; adding an operation adds a column. **Message passing** is the
  dual: the object carries its operations. Choose based on whether new types or
  new operations are more likely (the "expression problem").
- **Metalinguistic abstraction:** when the domain is complex enough, the best
  design is a small language (an interpreter or DSL) plus programs written in
  it. Configuration files, rule engines, query builders, and workflow
  definitions are all little languages. The Pragmatic Programmer's "domain
  languages" is the same idea.
- **Streams and delayed evaluation** decouple the description of a
  computation from its execution order, which is the root of lazy pipelines,
  reactive systems, and most modern data engines.
- **The cost of state:** once objects have identity and mutable state, you
  need the environment model and time becomes an issue (concurrency). Keep
  stateful components few, explicit, and at the edges.

## 6. Boundaries and dependency direction (Clean Code, Pragmatic Programmer)

- **Dependencies point inward:** domain logic at the centre with no
  dependencies; use cases around it; adapters (DB, HTTP, UI, queues) outside;
  frameworks and drivers at the edge. Details depend on policy, never the
  reverse. (Also known as hexagonal / ports-and-adapters / clean
  architecture.)
- **Wrap third-party code** in your own interface (Adapter) so churn and
  exceptions stay at the boundary and you can fake it in tests. Write
  **learning tests** against a new library to pin down the behaviour you rely
  on.
- **Separate construction from use.** Wiring (which concrete class, which
  config) happens in `main` or a composition root; the rest of the system
  receives its collaborators (dependency injection, which is just passing
  arguments).
- **Cross-cutting concerns** (logging, transactions, auth, metrics) go in
  decorators or middleware, not scattered through domain code.
- **Law of Demeter:** a method talks only to its own fields, its parameters,
  objects it creates, and direct components. `a.b().c().d()` couples you to
  three implementations. **Tell, don't ask:** push behaviour to the object
  that has the data.

## 7. Process: how to get a design out (Pragmatic Programmer)

- **Tracer bullets:** build a thin end-to-end slice through every layer
  first (UI → service → DB, or ingest → transform → sink), with real
  components stubbed minimally. It shows whether the architecture works,
  gives users something to react to, and provides the skeleton to flesh out.
  Unlike a prototype, tracer code is kept.
- **Prototypes** answer a specific question (will this library scale? does
  this UI make sense?) and are thrown away. Be explicit about which you are
  doing.
- **Estimate**, and iterate the estimate with the schedule. Design decisions
  that cannot be estimated are not understood yet.
- **Domain language:** talk to users in their vocabulary and make the code
  use the same words (ubiquitous language). A glossary is a design artefact.
- **Don't program by coincidence.** Understand why a design works; if you
  cannot explain it, you cannot maintain it.
- **Write the design down:** an ADR (architecture decision record) per
  significant decision: context, options, decision, consequences. Diagrams
  of components and their dependencies, plus the key sequence for the main
  use case. Keep it short and current.

## 8. System-level architecture (DDIA, Pragmatic Programmer)

- **Define load and requirements first:** throughput, latency percentile,
  data volume, consistency needs, availability target, team size and skills.
  Architecture that ignores these is fashion.
- **Monolith first.** A well-structured modular monolith with clear internal
  boundaries is easier to build, test, deploy, and refactor than services.
  Split into services when a boundary needs independent scaling, deployment
  cadence, or team ownership, and the module boundary is already clean.
  Distributed systems trade in-process calls for unreliable networks, partial
  failure, and data consistency problems (see the data-engineering skill).
- **Service boundaries follow data ownership.** Each service owns its data;
  others reach it through an API or an event stream, never its tables.
- **Synchronous vs asynchronous:** request/response for queries and
  operations that need an immediate answer; events/logs for propagating facts
  and building derived views. Async decouples availability and load but adds
  eventual consistency and requires idempotent consumers.
- **State is the hard part.** Keep services stateless where you can; put
  state in purpose-built stores; treat derived data (caches, indexes, views)
  as rebuildable from a source of truth.
- **Design for failure:** timeouts, retries with backoff and jitter, circuit
  breakers, bulkheads, graceful degradation, idempotency keys, health checks.
  Assume any dependency will be slow or down.
- **Evolvability:** versioned APIs and schemas, backward and forward
  compatible messages, feature flags, expand-then-contract migrations.
- **Observability is part of the design:** structured logs with correlation
  IDs, metrics (RED: rate, errors, duration; USE: utilisation, saturation,
  errors), traces across services. If you cannot see it, you cannot operate it.
- **Security by design:** validate at boundaries, least privilege, secrets
  out of code, encrypt in transit and at rest, audit trails.

## 9. Design review questions

For a module, service, or system design, ask:

1. What does each component hide? What would change if that secret changed?
2. What are the likely changes in the next year, and how many components
   does each touch?
3. Which direction do dependencies point? Does domain code import a
   framework, a DB driver, or an HTTP library?
4. Can each component be tested in isolation with fakes at its boundaries?
5. Is there a pattern here, or a pattern imposed without a problem?
6. Is inheritance used where composition or a function would be simpler?
7. Where is mutable state, and who owns it?
8. What are the primitives and combinators of the domain layer? Would a
   small DSL make the rest simpler?
9. What fails, and what does the user see when it does?
10. What are the load numbers this must handle, and where is the
    bottleneck at 10x?
11. Is the decision reversible? If not, is it isolated?
12. Is the design written down with its trade-offs?
