#lang scribble/manual

@require["../shared.rkt" @for-label[racket/base xiden/rc]]

@title[#:tag "config"]{Configuration}

@define[change-val @secref["Changing_a_Setting_Value"
         #:doc '(lib "xiden/docs/reference/xiden-reference.scrbl")]]

You can configure @|binary| using environment variables, the command
line interface, and/or a runtime configuration file. Every setting has
only one name, and a contract for accepted Racket values.

The @change-val section covers how to change the value of a setting.


@section{Why Allow Verbose Commands?}

A consequence of the rules in @change-val is that you cannot combine short
flags into strings like @litchar{-vUi}. @italic{Every} flag requires an
argument, so the flags may appear as @litchar{-v '#t' -U '#f' -i '#t'}.

Verbose commands are more painful to type, so why do it this way?
Because there are a few benefits to this approach:

@itemlist[

@item{
Passing values to flags keeps the entire command explicit and self-describing.
Let's say @racket[XIDEN_VERBOSE] is @racket[#t] due to an environment
variable or rcfile. Assuming that you do not change the environment variable,
you would not be able to change that back to @racket[#f]
in a command line without expressing @racket[#f].
}

@item{
What you type is what gets used at runtime, so long as it meets a
contract. This makes commands easier to predict for Racket
programmers, because they can visualize exact values at play.
}

@item{
Every setting has a canonical name, meaning that no matter where
you define a value, you can use the same name. Short flags
are merely bound to the same setting as the flags with
canonical names.

@racketblock[
(define XIDEN_VERBOSE #t)
]

@verbatim|{
$ XIDEN_VERBOSE="#t" xiden ...
}|

@verbatim|{
# Equivalent
$ xiden --XIDEN_VERBOSE "#t" ...
$ xiden -v "#t" ...
}|
}

]


@section{Setting the Workspace}

@racket[XIDEN_WORKSPACE] defines the directory to use as the @tech{workspace}.

@racket[XIDEN_WORKSPACE] can only be set using the environment
variable of the same name. This is because all other settings check a
@tech{workspace}-specific configuration file, and that file cannot be
known until @racket[XIDEN_WORKSPACE] is set.

@racket[XIDEN_WORKSPACE] must be a @racket[complete-path?]. If the
path points to an existing entry on the filesystem, then that entry
must be a directory. If the path points to no existing entry, then
@binary will create a directory at that path.


@section{The @tt{config} command}

Use the @litchar{xiden config} command to manage @|binary|'s configuration.

I'll use the @tt{XIDEN_VERBOSE} setting for the below examples:

@itemlist[
@item{@litchar{xiden config dump}: Prints a readable hash of the active configuration.}
@item{@litchar{xiden config set XIDEN_VERBOSE "#t"}: Changes a setting in a @tech{workspace}'s @tt{etc/xiden.rkt} file.}
@item{@litchar{xiden config get XIDEN_VERBOSE}: Gets the value of a setting}
]
