#lang racket/base

; Logged procedures for static operations on Racket modules

(require "contract.rkt")

(provide
 (contract-out [racket-module-input-variant/c flat-contract?]
               [racket-module-variant/c flat-contract?]
               [racket-module-code? (-> symbol? racket-module-variant/c syntax?)]
               [get-racket-module-body
                (-> (or/c #f symbol?) syntax? (or/c #f syntax?))]
               [make-racket-module-datum
                (->* (symbol? list?)
                     (#:id symbol?)
                     syntax?)]
               [read-racket-module
                (->* (symbol? symbol? racket-module-input-variant/c)
                     (logged/c syntax?))]))


(require (only-in racket/exn exn->string)
         (only-in racket/format ~s)
         (only-in racket/function curry)
         (only-in racket/match match)
         (only-in syntax/modread
                  check-module-form
                  with-module-reading-parameterization)
         "codec.rkt"
         "integrity.rkt"
         "logged.rkt"
         "message.rkt"
         "path.rkt"
         "signature.rkt"
         "string.rkt")


(define+provide-message $racket-module-read-error $message (variant reason context))

;------------------------------------------------------------------------
; Definitions

(define (racket-module-code? expected-lang v)
  (syntax-case v (module)
    [(module name lang . body)
     (equal? (syntax-e #'lang) expected-lang)
     #t]
    [_ #f]))

(define racket-module-input-variant/c
  (or/c path? list? string? bytes? input-port?))

(define racket-module-variant/c
  (or/c syntax? list?))



;------------------------------------------------------------------------
; Module I/O

(define (read-racket-module expected-reader-lang expected-module-lang variant)
  (cond [(input-port? variant)
         (read-racket-module/port expected-reader-lang expected-module-lang variant)]
        [(path? variant)
         (call-with-input-file variant (λ (i) (read-racket-module expected-reader-lang expected-module-lang i)))]
        [(list? variant)
         (read-racket-module expected-reader-lang expected-module-lang (~s variant))]
        [(string? variant)
         (read-racket-module expected-reader-lang expected-module-lang (open-input-string variant))]
        [(bytes? variant)
         (read-racket-module expected-reader-lang expected-module-lang (open-input-bytes variant))]))


(define-logged (read-racket-module/port expected-reader-lang expected-module-lang in)
  (define source-v (get-source-v in))
  (with-handlers ([procedure? (λ (p) ($fail (p source-v)))]
                  [exn? (λ (e) ($fail ($racket-module-read-error source-v 'exception (exn->string e))))])
    (port-count-lines! in)

    (define checked
      (check-module-form (read-module expected-reader-lang in)
                         'this-symbol-is-ignored
                         source-v))
    
    (syntax-case checked ()
      [(module id ml xs ...)
       (let ([module-lang (syntax-e #'ml)])
         (if (equal? module-lang expected-module-lang)
             ($use checked)
             ($fail ($racket-module-read-error source-v 'unexpected-module-lang module-lang))))]
      [_ ($fail ($racket-module-read-error source-v 'bad-module-form #f))])))


; Returns a value suitable for use as a `src' argument in
; `read-syntax', or a `source-v' argument in `check-module-form'.
(define (get-source-v in)
  (define objname (object-name in))
  (if (and (path-string? objname)
           (file-exists? objname))
      objname
      #f))


(define (read-module expected-reader-lang in)
  (with-module-reading-parameterization
    (λ ()
      (parameterize ([current-reader-guard (curry reader-guard expected-reader-lang)])
        (read-syntax (get-source-v in)
                     in)))))


(define (reader-guard lang reader)
  (if (equal? reader `(submod ,lang reader))
      reader
      (raise (λ (source-v) ($racket-module-read-error source-v 'blocked-reader reader)))))


;------------------------------------------------------------------------
; Construction/destructuring

(define (make-racket-module-datum #:id [id 'anon] lang body)
  `(module ,id ,lang . ,body))


(define (get-racket-module-body expected-lang variant)
  (define stx
    (syntax-case variant (module)
      [(module _ lang . xs)
       (or (not expected-lang)
           (equal? (syntax-e #'lang) expected-lang))
       (syntax-case #'xs (#%module-begin #%plain-module-begin)
         [((#%module-begin . body)) #'body]
         [((#%plain-module-begin . body)) #'body]
         [_ #'xs])]
      [_ #f]))
  (and stx
       (if (syntax? variant)
           stx
           (syntax->datum stx))))



(module+ test
  (require racket/file
           racket/function
           racket/port
           rackunit
           (submod "logged.rkt" test))

  (define (expect-bad-module-form val messages)
    (check-equal? val FAILURE)
    (check-match (car messages)
                 ($racket-module-read-error _ 'bad-module-form _)))
  
  (test-case "Detect Racket module data"
    (check-true (racket-module-code? 'something (make-racket-module-datum 'something '(a b c))))
    (check-true (racket-module-code? 'something (make-racket-module-datum 'something null)))
    (check-false (racket-module-code? 'something '(module anon other)))
    (check-false (racket-module-code? 'something `(module something)))
    (check-false (racket-module-code? 'something '(module anon other 1 2 3))))

  (test-case "Extract body from package definition module forms"
    (check-equal?  (get-racket-module-body
                   `(module anon something a b c))
                  '(a b c))
    (check-equal? (get-racket-module-body
                   `(module anon something (#%module-begin a b c)))
                  '(a b c))
    (check-equal? (get-racket-module-body
                   (make-racket-module-datum 'something '(a b c)))
                  '(a b c)))
  
  (test-logged-procedure "Detect error when reading improper module form"
                         (read-racket-module '_ '_ "(module)")
                         expect-bad-module-form)

  (test-logged-procedure "Detect if EOF came too soon"
                         (read-racket-module '_ '_ "")
                         expect-bad-module-form)
  
  (test-logged-procedure "Read with reader extension"
                         (read-racket-module 'racket/base
                                             'racket/base
                                             "#lang racket/base (define val 1)")
                         (λ (v msg)
                           (check-pred syntax? v)
                           (check-match (syntax->datum v)
                                        `(module ,_ racket/base (,_ (define val 1))))
                           (check-pred null? msg)))

  (test-logged-procedure "Accept only prescribed reader extensions"
                         (read-racket-module 'other 'racket/base "#lang racket/base (define val 1)")
                         (λ (v msg)
                           (check-eq? v FAILURE)
                           (check-match (car msg)
                                        ($racket-module-read-error #f
                                                                   'blocked-reader
                                                                   '(submod racket/base reader)))))

  (test-logged-procedure "Accept only prescribed expander language"
                         (read-racket-module 'racket/base 
                                             'other
                                             "#lang racket/base (define val 1)")
                         (λ (v msg)
                           (check-eq? v FAILURE)
                           (check-match (car msg)
                                        ($racket-module-read-error _ 'unexpected-module-lang _)))))