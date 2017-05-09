(set-option :produce-models true)

; Datatypes

; Val is the datatype for an ECMAScript value. We do not currently have
; support for objects.

(declare-datatypes () (
    (Val
        (undefined)
        (null)
        (Boolean (bool Bool))
        (Str (str String))
        (Num (num Int))
        (Obj (id Int))
    )
))

(declare-datatypes () (
    (MaybeVal
        (Nothing)
        (Just (just Val)))))

; ECMAScript internal functions
;
; These will have the same name as the functions in the specification with
; "js." prepended. The generally return values of an SMT-LIB sort, and may
; need to be wrapped with Val.

(define-sort Properties () (Array String MaybeVal))
(declare-fun GetProperties (Int) Properties)

(define-fun js.ToString ((x Val)) String
    (ite (is-Str x) (str x)
    (ite (is-undefined x) "undefined"
    (ite (is-null x) "null"
    (ite (is-Boolean x) (ite (bool x) "true" "false")
    (ite (is-Num x) (int.to.str (num x))
    "FOOBARBAZ"))))))

(define-fun js.ToNumber ((x Val)) Int
    (ite (is-Num x) (num x)
    (ite (is-undefined x) 0
    (ite (is-null x) 0
    (ite (is-Boolean x) (ite (bool x) 1 0)
    (ite (is-Str x) (str.to.int (str x))
    42))))))

(define-fun js.ToInteger ((x Val)) Int (js.ToNumber x))

(define-fun SameType ((x Val) (y Val)) Bool (or
    (and (is-undefined x) (is-undefined y))
    (and (is-null x) (is-null y))
    (and (is-Boolean x) (is-Boolean y))
    (and (is-Str x) (is-Str y))
    (and (is-Num x) (is-Num y))))

(define-fun typeof ((x Val)) String
    (ite (is-Num x) "number"
    (ite (is-undefined x) "undefined"
    (ite (is-null x) "null"
    (ite (is-Boolean x) "boolean"
    (ite (is-Str x) "string"
    "object"))))))

(define-fun EmptyObject () Properties ((as const Properties) Nothing))

(define-fun js.ToObject ((o Val)) Properties
    (ite (is-Obj o) (GetProperties (id o))
    (ite (is-Str o) (store EmptyObject "length" (Just (Num (str.len (str o)))))
    EmptyObject)))

(define-fun GetField ((o Properties) (k Val)) Val
    (let ((v (select o (js.ToString k))))
        (ite (is-Just v) (just v) undefined)))
(define-fun PutField ((o Properties) (k Val) (v Val)) Properties (store o (js.ToString k) (Just v)))
(define-fun DeleteField ((o Properties) (k Val)) Properties (store o (js.ToString k) Nothing))

(define-fun MutableToProps ((base Val) (modified Properties)) Properties
    (ite (is-Obj base) modified (js.ToObject base)))

; ECMAScript expressions

; Binary operators

(define-fun js.in ((x Val) (y Properties)) Bool (is-Just (select y (js.ToString x))))

; Relational operators
(define-fun js.=== ((x Val) (y Val)) Bool (= x y))

(define-fun js.!== ((x Val) (y Val)) Bool (not (js.=== x y)))

(define-fun js.== ((x Val) (y Val)) Bool
    (ite (SameType x y) (js.=== x y)
    (ite (and (is-null x) (is-undefined y)) true
    (ite (and (is-null y) (is-undefined x)) true
    (ite (and (is-Num x) (is-Str y)) (= (num x) (js.ToNumber y))
    (ite (and (is-Num y) (is-Str x)) (= (num y) (js.ToNumber x))
    (ite (is-Boolean x) (let ((nx (js.ToNumber x)))
        (ite (is-Num y) (= nx (num y))
        (ite (is-Str y) (= nx (js.ToNumber y))
        false)))
    (ite (is-Boolean y) (let ((ny (js.ToNumber y)))
        (ite (is-Num x) (= (num x) ny)
        (ite (is-Str x) (= ny (js.ToNumber x))
        false)))
    false))))))))

(define-fun js.!= ((x Val) (y Val)) Bool (not (js.== x y)))

; NOTE: "ab" < "ac" returns false by this definition, even though "c" < "a".
; This is because we can't implement the character-level < operation, since Z3
; doesn't (yet) let us access individual characters within strings/sequences.
(define-fun js.< ((x Val) (y Val)) Bool
    (ite (and (is-Str x) (is-Str y))
        (let ((sx (str x)) (sy (str y)))
            (and (not (str.prefixof sy sx)) (str.prefixof sx sy)))
        (< (js.ToNumber x) (js.ToNumber y))))

(define-fun js.> ((x Val) (y Val)) Bool (js.< y x))
(define-fun js.<= ((x Val) (y Val)) Bool (not (js.< y x)))
(define-fun js.>= ((x Val) (y Val)) Bool (not (js.< x y)))

; Arithmetic operators
(define-fun js.+ ((x Val) (y Val)) Val
    (ite (or (is-Str x) (is-Str y))
        (Str (str.++ (js.ToString x) (js.ToString y)))
        (Num (+ (js.ToNumber x) (js.ToNumber y)))))

(define-fun js.- ((x Val) (y Val)) Val
    (Num (- (js.ToNumber x) (js.ToNumber y))))

(define-fun js.* ((x Val) (y Val)) Val
    (Num (* (js.ToNumber x) (js.ToNumber y))))

(define-fun js./ ((x Val) (y Val)) Val
    (Num (/ (js.ToNumber x) (js.ToNumber y))))

(define-fun js.% ((x Val) (y Val)) Val
    (Num (mod (js.ToNumber x) (js.ToNumber y))))

; Unary operators

(define-fun js.! ((x Bool)) Bool (not x))
(define-fun js.void ((x Val)) Val undefined)
(define-fun js.typeof ((x Val)) Val (Str (typeof x)))
(define-fun js.u+ ((x Val)) Val (Num (js.ToNumber x)))
(define-fun js.u- ((x Val)) Val (Num (- (js.ToNumber x))))
