#lang racket

;; -------------------------------------------------------
;; Exercise 5.25, p.560
;; Lazy Explicit-Control Evaluator
;;
;; Compare the changes with commit ea9bed64
;;
;; - Run ndpar-5.4-sim.rkt
;; - Evaluate following procedures in DrRacket REPL
;; -------------------------------------------------------

(define eceval-operations
  (list (list 'self-evaluating? self-evaluating?)
        (list 'variable? variable?)
        (list 'quoted? quoted?)
        (list 'assignment? assignment?)
        (list 'definition? definition?)
        (list 'if? if?)
        (list 'lambda? lambda?)
        (list 'begin? begin?)
        (list 'application? application?)
        (list 'lookup-variable-value lookup-variable-value)
        (list 'text-of-quotation text-of-quotation)
        (list 'lambda-parameters lambda-parameters)
        (list 'lambda-body lambda-body)
        (list 'delay-it delay-it)
        (list 'thunk? thunk?)
        (list 'thunk-exp thunk-exp)
        (list 'thunk-env thunk-env)
        (list 'make-procedure make-procedure)
        (list 'operands operands)
        (list 'operator operator)
        (list 'no-operands? no-operands?)
        (list 'first-operand first-operand)
        (list 'rest-operands rest-operands)
        (list 'empty-arglist empty-arglist)
        (list 'adjoin-arg adjoin-arg)
        (list 'last-operand? last-operand?)
        (list 'primitive-procedure? primitive-procedure?)
        (list 'compound-procedure? compound-procedure?)
        (list 'apply-primitive-procedure apply-primitive-procedure)
        (list 'procedure-parameters procedure-parameters)
        (list 'procedure-body procedure-body)
        (list 'procedure-environment procedure-environment)
        (list 'extend-environment extend-environment)
        (list 'begin-actions begin-actions)
        (list 'last-exp? last-exp?)
        (list 'first-exp first-exp)
        (list 'rest-exps rest-exps)
        (list 'if-predicate if-predicate)
        (list 'if-consequent if-consequent)
        (list 'if-alternative if-alternative)
        (list 'true? true?)
        (list 'assignment-variable assignment-variable)
        (list 'assignment-value assignment-value)
        (list 'set-variable-value! set-variable-value!)
        (list 'definition-variable definition-variable)
        (list 'definition-value definition-value)
        (list 'define-variable! define-variable!)
        (list 'prompt-for-input prompt-for-input)
        (list 'read read)
        (list 'announce-output announce-output)
        (list 'user-print user-print)
        (list 'get-global-environment get-global-environment)))

(define eceval
  (make-machine
   eceval-operations
   '(read-eval-print-loop
     (perform (op initialize-stack)) ; defined in simulator
     (perform (op prompt-for-input) (const ";;; LEC-Eval input:"))
     (assign exp (op read))
     (assign env (op get-global-environment))
     (assign continue (label print-result))
     (goto (label actual-value)) ; eval-dispatch [strict]

     print-result
     (perform (op print-stack-statistics)) ; defined in simulator
     (perform (op announce-output) (const ";;; LEC-Eval value:"))
     (perform (op user-print) (reg val))
     (goto (label read-eval-print-loop))

     eval-dispatch
     (if ((op self-evaluating?) (reg exp)) (label ev-self-eval))
     (if ((op variable?) (reg exp)) (label ev-variable))
     (if ((op quoted?) (reg exp)) (label ev-quoted))
     (if ((op assignment?) (reg exp)) (label ev-assignment))
     (if ((op definition?) (reg exp)) (label ev-definition))
     (if ((op if?) (reg exp)) (label ev-if))
     (if ((op lambda?) (reg exp)) (label ev-lambda))
     (if ((op begin?) (reg exp)) (label ev-begin))
     (if ((op application?) (reg exp)) (label ev-application))
     (goto (label unknown-expression-type))

     ev-self-eval
     (assign val (reg exp))
     (goto (reg continue))

     ev-variable
     (assign val (op lookup-variable-value) (reg exp) (reg env))
     (goto (reg continue))

     ev-quoted
     (assign val (op text-of-quotation) (reg exp))
     (goto (reg continue))

     ev-lambda
     (assign unev (op lambda-parameters) (reg exp))
     (assign exp (op lambda-body) (reg exp))
     (assign val (op make-procedure) (reg unev) (reg exp) (reg env))
     (goto (reg continue))

     actual-value
     (save continue)
     (assign continue (label force-it))
     (goto (label eval-dispatch))

     force-it
     (if ((op thunk?) (reg val)) (label force-thunk))
     (restore continue)
     (goto (reg continue))

     force-thunk
     (assign exp (op thunk-exp) (reg val))
     (assign env (op thunk-env) (reg val))
     (goto (label actual-value))

     delay-it
     (assign val (op delay-it) (reg exp) (reg env))
     (goto (reg continue))

     ev-application
     (save continue)
     (save env)
     (assign unev (op operands) (reg exp))
     (save unev)
     (assign exp (op operator) (reg exp))
     (assign continue (label ev-appl-did-operator))
     (goto (label actual-value)) ; eval-dispatch [strict]

     ev-appl-did-operator
     (restore unev)
     (restore env)
     (assign argl (op empty-arglist))
     (assign proc (reg val))
     (save proc)
     ; different treatment of primitive and compound procedures.
     ; no apply-dispatch any longer. switch happens here
     (if ((op primitive-procedure?) (reg proc)) (label act-appl-operand-loop))
     (if ((op compound-procedure?) (reg proc)) (label del-appl-operand-loop))
     (goto (label unknown-procedure-type))

     ;; primitive procedures (same as in strict case)
     act-appl-operand-loop
     (save argl)
     (assign exp (op first-operand) (reg unev))
     (if ((op last-operand?) (reg unev)) (label act-appl-last-arg))
     (save env)
     (save unev)
     (assign continue (label act-appl-accumulate-arg))
     (goto (label actual-value)) ; eval-dispatch [strict]

     act-appl-accumulate-arg
     (restore unev)
     (restore env)
     (restore argl)
     (assign argl (op adjoin-arg) (reg val) (reg argl))
     (assign unev (op rest-operands) (reg unev))
     (goto (label act-appl-operand-loop))

     act-appl-last-arg
     (assign continue (label act-appl-accum-last-arg))
     (goto (label actual-value)) ; eval-dispatch [strict]

     act-appl-accum-last-arg
     (restore argl)
     (assign argl (op adjoin-arg) (reg val) (reg argl))
     (restore proc)
     (goto (label primitive-apply))

     primitive-apply
     (assign val (op apply-primitive-procedure) (reg proc) (reg argl))
     (restore continue)
     (goto (reg continue))

     ;; compound procedures. similar to primitive with replacement:
     ;; actual-value -> delay-it
     del-appl-operand-loop
     (save argl)
     (assign exp (op first-operand) (reg unev))
     (if ((op last-operand?) (reg unev)) (label del-appl-last-arg))
     (save env)
     (save unev)
     (assign continue (label del-appl-accumulate-arg))
     (goto (label delay-it))

     del-appl-accumulate-arg
     (restore unev)
     (restore env)
     (restore argl)
     (assign argl (op adjoin-arg) (reg val) (reg argl))
     (assign unev (op rest-operands) (reg unev))
     (goto (label del-appl-operand-loop))

     del-appl-last-arg
     (assign continue (label del-appl-accum-last-arg))
     (goto (label delay-it))

     del-appl-accum-last-arg
     (restore argl)
     (assign argl (op adjoin-arg) (reg val) (reg argl))
     (restore proc)
     (goto (label compound-apply))

     compound-apply
     (assign unev (op procedure-parameters) (reg proc))
     (assign env (op procedure-environment) (reg proc))
     (assign env (op extend-environment) (reg unev) (reg argl) (reg env))
     (assign unev (op procedure-body) (reg proc))
     (goto (label ev-sequence))

     ev-begin
     (assign unev (op begin-actions) (reg exp))
     (save continue)
     (goto (label ev-sequence))

     ev-sequence
     (assign exp (op first-exp) (reg unev))
     (if ((op last-exp?) (reg unev)) (label ev-sequence-last-exp))
     (save unev)
     (save env)
     (assign continue (label ev-sequence-continue))
     (goto (label eval-dispatch))

     ev-sequence-continue
     (restore env)
     (restore unev)
     (assign unev (op rest-exps) (reg unev))
     (goto (label ev-sequence))

     ev-sequence-last-exp
     (restore continue)
     (goto (label eval-dispatch))

     ev-if
     (save exp)
     (save env)
     (save continue)
     (assign continue (label ev-if-decide))
     (assign exp (op if-predicate) (reg exp))
     (goto (label actual-value)) ; eval-dispatch [strict]

     ev-if-decide
     (restore continue)
     (restore env)
     (restore exp)
     (if ((op true?) (reg val)) (label ev-if-consequent))

     ev-if-alternative
     (assign exp (op if-alternative) (reg exp))
     (goto (label eval-dispatch))

     ev-if-consequent
     (assign exp (op if-consequent) (reg exp))
     (goto (label eval-dispatch))

     ev-assignment
     (assign unev (op assignment-variable) (reg exp))
     (save unev)
     (assign exp (op assignment-value) (reg exp))
     (save env)
     (save continue)
     (assign continue (label ev-assignment-1))
     (goto (label eval-dispatch))

     ev-assignment-1
     (restore continue)
     (restore env)
     (restore unev)
     (perform
      (op set-variable-value!) (reg unev) (reg val) (reg env))
     (assign val (const ok))
     (goto (reg continue))

     ev-definition
     (assign unev (op definition-variable) (reg exp))
     (save unev)
     (assign exp (op definition-value) (reg exp))
     (save env)
     (save continue)
     (assign continue (label ev-definition-1))
     (goto (label eval-dispatch))

     ev-definition-1
     (restore continue)
     (restore env)
     (restore unev)
     (perform
      (op define-variable!) (reg unev) (reg val) (reg env))
     (assign val (const ok))
     (goto (reg continue))

     unknown-expression-type
     (assign val (const unknown-expression-type-error))
     (goto (label signal-error))

     unknown-procedure-type
     (restore continue)
     (assign val (const unknown-procedure-type-error))
     (goto (label signal-error))

     signal-error
     (perform (op user-print) (reg val))
     (goto (label read-eval-print-loop)))))

(start eceval)

;; -------------------------------------------------------
;; Tests and Exercises
;;
;; - Evaluate following procedures in eceval REPL
;; -------------------------------------------------------

(define (try a b) (if (= a 0) 0 b))

(try 0 (/ 1 0))
