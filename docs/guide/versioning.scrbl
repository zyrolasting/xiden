#lang scribble/manual

@require["../shared.rkt" @for-label[racket/base]]

@title{Versioning}

A package version consists of an @tech{edition} and a @tech{revision}.

An @deftech{edition} is the name of a design. It acts as a semantic alternative
to a major version number. A @deftech{revision} is an implementation of an
edition.

A @deftech{revision number} is a non-negative integer. Every revision is
forever assigned the next available number in an edition.

A @deftech{revision name} is a custom alias for a @tech{revision number}. It
can be a user-defined string, but strings containing all digits, and the word
@racket{newest} are reserved.

A package must have a @tech{revision number}. When changed, a package must
increment its @tech{revision number} if the change uses the same
@tech{edition}. If the package starts a new edition, the @tech{revision number}
must reset to @racket[0].

The default name of an edition is @racket{draft}.

By the above rules, every package starts on the zeroth revision of the
@racket{draft} edition.
