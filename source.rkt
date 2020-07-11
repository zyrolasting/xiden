#lang racket/base

; Define a package source as a string that could refer to a local file
; or a remote resource.  A package source should ultimately lead to a
; local directory path containing the source code of a package.

(require racket/contract)

(define source-variant/c (or/c url? dependency? path?))

(provide
 (contract-out
  [zcpkg-directory->zcpkg-info (-> path? zcpkg-info?)]

  [variant->zcpkg-directory (-> source-variant/c path?)]

  [source->variant
   (-> string? source-variant/c)]))

(require racket/path
         "config.rkt"
         "dependency.rkt"
         "string.rkt"
         "url.rkt"
         "zcpkg-info.rkt")

(define (source->maybe-path v [relative-path-root (current-directory)])
  (cond [(path? v)
         (define p
           (cond [(directory-exists? v)
                  (source->maybe-path (build-path v "info.rkt")
                                      relative-path-root)]
                 [(file-exists? v)
                  (build-path v)]
                 [else #f]))
         (and p
              (simplify-path (if (complete-path? p) p
                                 (build-path relative-path-root p))))]

        [(url? v)
         (and (or (not (url-scheme v))
                  (equal? (url-scheme v) "file"))
              (source->maybe-path (url->maybe-path v relative-path-root)
                                  relative-path-root))]

        [(url-string? v)
         (source->maybe-path (string->url v)
                             relative-path-root)]

        [else #f]))

(define (source->maybe-dependency v)
  (with-handlers ([exn? (λ _ #f)])
    (define dep (coerce-dependency v))
    (and (well-formed-dependency? dep)
         dep)))

(define (source->variant v)
  (or (source->maybe-path v)
      (source->maybe-dependency v)
      (string->url v)))

(define (zcpkg-directory->zcpkg-info dirpath)
  (define info.rkt (build-path dirpath "info.rkt"))
  (if (file-exists? info.rkt)
      (read-zcpkg-info info.rkt)
      (error 'install-package
             "No info.rkt in ~a~n"
             dirpath)))

(define (variant->zcpkg-directory variant)
  (cond [(path? variant)
         (if (file-exists? variant)
             (path-only variant)
             variant)]
        [(dependency? variant)
         (error "Getting a source directory by a dependency struct is not yet implemented")]
        [(url? variant)
         (error "Getting a source directory by an URL is not yet implemented")]
        [else #f]))

(module+ test
  (require rackunit
           racket/runtime-path)

  (define-runtime-path ./ ".")

  (parameterize ([current-directory ./])
    (test-equal? "If it looks like a file path, then make it a file path"
                 (source->maybe-path "./source.rkt")
                 (simplify-path "./source.rkt"))

    (test-equal? "If it looks like a directory path, then make it a info.rkt file path"
                 (source->maybe-path ".")
                 (simplify-path "./info.rkt"))

    (test-equal? "Mimic rules for file:// url pointing to a file."
                 (source->maybe-path "file:///./source.rkt")
                 (source->maybe-path "./source.rkt"))

    (test-equal? "Mimic rules for file:// url pointing to a directory."
                 (source->maybe-path "file:///.")
                 (source->maybe-path "."))

    (test-false "Don't make paths out of things that don't exist."
                (source->maybe-path "weeee.erk")))

  (test-true "All valid dependency strings are valid sources"
             (andmap (λ (s) (dependency? (source->maybe-dependency s)))
                     (list "provider/package"
                           "provider/package;draft"
                           "provider/package;draft;newest"
                           "provider/package;draft;oldest;newest"
                           "provider/package;draft;i;oldest;e;newest")))

  (test-false "Invalid dependency strings are not valid sources"
              (dependency? (source->maybe-dependency "fsdfhbsdfj"))))