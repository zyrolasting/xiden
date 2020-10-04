#lang scribble/manual

@require["../shared.rkt"]

@title{@|project-name|: Maintainer's Reference}

This document covers development and maintenance information pertinent to
@|project-name|. This document will not (always) repeat what code already says,
but will instead offer context surrounding the current implementation.

If you were looking for the public API reference, see @other-doc['(lib
"xiden/docs/public-reference/xiden-public-reference.scrbl")]. If you want a
high-level overview of what @project-name is, see @other-doc['(lib
"xiden/docs/guide/xiden-guide.scrbl")].

@table-of-contents[]

@include-section{basics.scrbl}
@include-section{string.scrbl}