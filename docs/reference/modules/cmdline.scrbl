#lang scribble/manual

@require["../../shared.rkt"
         @for-label[racket/base
                    racket/contract
                    xiden/cmdline
                    xiden/message
                    xiden/printer]]

@title{Command Line Utilities}

@defmodule[xiden/cmdline]

@racketmodname[xiden/cmdline] provides all bindings from
@racketmodname[racket/cmdline], as well as the bindings documented in
this section. Unlike @racketmodname[xiden/cli],
@racketmodname[xiden/cmdline] does not actually define a command line
interface. It only helps @racketmodname[xiden/cli] do so.

@section{CLI Value Types}

@defthing[exit-code/c flat-contract? #:value (integer-in 0 255)]{
An exit code for use in an @tech/reference{exit handler}.

@project-name does not currently lean on the exit code to convey much
meaning, so expect to see @racket[1] (@tt{E_FAIL}) to represent an
error state. Lean on the @tech{program log} for specifics.
}

@defthing[arguments/c chaperone-contract? #:value (or/c (listof string?) (listof vector?))]{
Represents arguments provided in a command line. An argument list may
be a vector or list of strings for flexibility reasons.
}

@defthing[program-log/c chaperone-contract? #:value (or/c $message? (listof $message?))]{
A @deftech{program log} is a single @tech{message} or list of
@tech{messages} that report exact program behavior.
}

@section{CLI Flow Control}

@defproc[(entry-point [args arguments/c]
                      [formatter message-formatter/c]
                      [handler (-> arguments/c
                                   (-> exit-code/c program-log/c any)
                                   (values exit-code/c program-log/c))])
         exit-code/c]{
Applies @racket[(handler args continue)], where @racket[continue] is a
@tech/reference{continuation} that expects an exit code and then a
@tech{program log} as arguments. Alternatively, @racket[handler] can
just return an exit code and @tech{program log} without applying
@racket[continue].

Once @racket[handler] returns control, @racket[entry-point]
emits all @tech{messages} in the @tech{program log}. It will then
return the exit code.

Notice that a consequence of this behavior is that showing the
@tech{program log} is the last action of the runtime.  This makes
@racket[entry-point] unsuitable for sharing @tech{messages} about
progress in long-running jobs.
}


@defform[(with-rc flags body ...)]{
Like @racket[begin], except the body is evaluated using a new
@tech{runtime configuration} in terms of @racket[flags].
@racket[flags] should be @racket[null], or flag data computed by
@racket[parse-command-line]. The flag data is specific to
@project-name, and you do not need to define it yourself.
}


@section{CLI Messages}

@defstruct*[($cli $message) () #:prefab]{
A @tech{message} that pertains to a command line interface.
}

@defstruct*[($cli:undefined-command $cli) ([command string?])  #:prefab]{
A user passed @racket[command] as a subcommand, but it is not defined.
}

@defstruct*[($cli:show-help $cli) ([body-string string?] [string-suffix-key (or/c #f symbol?)])  #:prefab]{
A @tech{message} that formats as context-sensitive
help. @racket[body-string] is help content generated by
@racket[parse-command-line]. @racket[string-suffix-key] is an internal
value used to select a localized string to append to said help.
}
