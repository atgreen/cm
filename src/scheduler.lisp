;;; **********************************************************************
;;; Copyright (C) 2009 Heinrich Taube, <taube (at) uiuc (dot) edu>
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the Lisp Lesser Gnu Public License.
;;; See http://www.cliki.net/LLGPL for the text of this agreement.
;;; **********************************************************************

;;; generated by scheme->cltl from scheduler.scm on 19-Mar-2009 14:43:22

(in-package :cm)

(defparameter *qentry-unknown* 0)

(defparameter *qentry-process* 1)

(defparameter *qentry-seq* 2)

(defparameter *qentry-object* 3)

(defparameter *qentry-message* 4)

(defparameter *qentry-pointer* 5)

(defmacro %qe-time (qe) `(car ,qe))

(defmacro %qe-time-set! (qe time) `(rplaca ,qe ,time))

(defmacro %qe-start (qe) `(cadr ,qe))

(defmacro %qe-start-set! (qe start) `(rplaca (cdr ,qe) ,start))

(defmacro %qe-object (qe) `(caddr ,qe))

(defmacro %qe-object-set! (qe obj) `(rplaca (cddr ,qe) ,obj))

(defmacro %qe-datum (qe) `(cadddr ,qe))

(defmacro %qe-datum-set! (qe obj) `(rplaca (cdddr ,qe) ,obj))

(defmacro %qe-next (qe) `(cddddr ,qe))

(defmacro %qe-next-set! (qe nxt) `(rplacd (cdddr ,qe) ,nxt))

(defmacro %q-head (q) `(cycl-tail ,q))

(defmacro %q-head-set! (q e) `(cycl-tail-set! ,q ,e))

(defmacro %q-last (q) `(cycl-last ,q))

(defmacro %q-last-set! (q e) `(cycl-last-set! ,q ,e))

(defmacro %q-peek (q) `(%q-head ,q))

(defmacro %q-empty? (q) `(null (%q-head ,q)))

(defmacro %q-pop (queue)
  (let ((q (gensym)) (e (gensym)))
    `(let* ((,q ,queue) (,e (%q-head ,q)))
       (if (null ,e) '()
           (progn
            (%q-head-set! ,q (%qe-next ,e))
            (%qe-next-set! ,e '())
            (if (null (%q-head ,q)) (%q-last-set! ,q '()))
            ,e)))))

(defmacro %qe-alloc (queue time start object type)
  (let ((q (gensym)) (e (gensym)))
    `(let* ((,q ,queue) (,e (cycl-data ,q)))
       (if (null ,e) (list ,time ,start ,object ,type)
           (progn
            (cycl-data-set! ,q (%qe-next (cycl-data ,q)))
            (%qe-next-set! ,e '())
            (%qe-time-set! ,e ,time)
            (%qe-start-set! ,e ,start)
            (%qe-object-set! ,e ,object)
            (%qe-datum-set! ,e ,type)
            ,e)))))

(defmacro %qe-dealloc (queue entry)
  (let ((q (gensym)) (e (gensym)))
    `(let ((,q ,queue) (,e ,entry))
       (%qe-time-set! ,e nil)
       (%qe-start-set! ,e nil)
       (%qe-object-set! ,e nil)
       (%qe-datum-set! ,e nil)
       (%qe-next-set! ,e (cycl-data ,q))
       (cycl-data-set! ,q ,e)
       (values))))

(defparameter %q (make-cycl))

(dotimes (i 50) (%qe-dealloc %q (list nil nil nil nil)))

(defmacro %q-insert (entry queue)
  (let ((q (gensym)) (e (gensym)) (h (gensym)) (l (gensym)))
    `(let ((,q ,queue) (,e ,entry))
       (if (null (%q-head ,q))
           (progn (%q-head-set! ,q ,e) (%q-last-set! ,q ,e))
           (if (< (%qe-time ,e) (%qe-time (%q-head ,q)))
               (progn
                (%qe-next-set! ,e (%q-head ,q))
                (%q-head-set! ,q ,e))
               (if (< (%qe-time ,e) (%qe-time (%q-last ,q)))
                   (do ((,h (%q-head ,q))
                        (,l '()))
                       ((or (null ,h)
                            (> (%qe-time ,h) (%qe-time ,e)))
                        (%qe-next-set! ,e (%qe-next ,l))
                        (%qe-next-set! ,l ,e))
                     (setf ,l ,h)
                     (setf ,h (%qe-next ,h)))
                   (progn
                    (%qe-next-set! (%q-last ,q) ,e)
                    (%q-last-set! ,q ,e))))))))

(defun pq (&rest args)
  (let* ((q (if (null args) %q (car args)))
         (h (%q-head q))
         (z most-negative-fixnum))
    (format t "~s entries:~%" (/ (length (%q-head q)) 3))
    (loop for i from 0 until (null h) do
          (if (> z (car h))
              (error "Out of order: ~s ~s ~s" z (car h) (%q-head q)))
          (setf z (car h))
          (format t "~s. (~s ~s ~s)" i (car h) (cadr h) (caddr h))
          (terpri) (setf h (%qe-next h)))))

(defun %q-flush (q)
  (loop for e = (%q-pop q) until (null e) do (%qe-dealloc q e)))

(defparameter *queue* nil)

(defparameter *events* nil)

(defparameter *pstart* nil)

(defparameter *qtime* nil)

(defparameter *qnext* nil)

(defparameter *qlock* nil)

(defparameter *rts-pstart* nil)

(defparameter *rts-qtime* nil)

(defparameter *rts-qnext* nil)

(defun scheduling-mode ()
  (if (rts-thread?) ':rts (if *events* ':events nil)))

(defun scheduling-mode? (x) (eq (scheduling-mode) x))

(defun schedule-events (stream object &rest args)
  (let* ((ahead (if (consp args) (car args) 0))
         (noerr nil)
         (entry nil)
         (start nil)
         (datum nil)
         (etype nil)
         (thing nil)
         (qtime nil))
    (setf *queue* %q)
    (setf *events* t)
    (setf *qtime* 0)
    (setf *pstart* 0)
    (if (consp object)
        (dolist (o object)
          (schedule-object o
           (if (consp ahead)
               (if (consp (cdr ahead)) (pop ahead) (car ahead))
               ahead)
           ':events))
        (if (consp ahead)
            (schedule-object object (car ahead) ':events)
            (schedule-object object ahead ':events)))
    (unwind-protect
        (progn
         (do ()
             ((null (%q-head *queue*)) (setf noerr t))
           (setf entry (%q-pop *queue*))
           (setf qtime (%qe-time entry))
           (setf start (%qe-start entry))
           (setf thing (%qe-object entry))
           (setf datum (%qe-datum entry))
           (%qe-dealloc *queue* entry)
           (setf etype (logand datum 15))
           (cond
            ((eq etype *qentry-process*)
             (scheduler-do-process thing qtime start stream datum
              ':events))
            ((eq etype *qentry-seq*)
             (scheduler-do-seq thing qtime start stream datum
              ':events))
            (t (write-event thing stream qtime)))))
      (unless noerr
        (%q-flush *queue*)
        (unschedule-object object t ':events))
      (setf *events* nil)
      (setf *pstart* nil)
      (setf *qtime* nil)
      (setf *queue* nil))))

(defun enqueue (type object time start sched)
  (if (eq sched ':events)
      (%q-insert (%qe-alloc *queue* time start object type) *queue*)
      (rts-enqueue type object time start sched)))

(defun early? (tim sched)
  (if (eq sched ':events)
      (if (null (%q-head *queue*)) nil
          (> tim (%qe-time (%q-head *queue*))))
      nil))

(defmethod schedule-object ((obj standard-object) start sched)
  (enqueue *qentry-object* obj (+ start (object-time obj))
           nil sched))

(defmethod schedule-object ((obj function) start sched)
           (enqueue *qentry-process* obj start start sched))

(defmethod schedule-object ((obj integer) start sched)
           (enqueue *qentry-message* obj start start sched))

(defmethod schedule-object ((obj cons) start sched)
           (dolist (o obj) (schedule-object o start sched)))

;;; A seq is an object with name, subobjects and time slots. The
;;; subobjects are a list of objects. schedule-object does 2 things:
;;;
;;; 1. It enqueues the seq by calling enqueue with the object consed
;;; to the subobject list. The enqueue function works by iterating
;;; recursively over the cdr of the list (the subobjects), splicing
;;; out each event (the second element of this list) and calling its
;;; write-event function. Container objects are skipped over in the
;;; iteration.
;;;
;;; 2. It then enqueues all container objects of the subobjects (the
;;; "subcontainers") by calling itself with updated start-time.

(defmethod schedule-object ((obj seq) start sched)
  (let ((mystart (+ start (object-time obj))))
    (multiple-value-bind (time start)
        (if (eq sched :events)
            (values mystart mystart)
            (values 0 (object-time obj)))
      (enqueue *qentry-seq*
               (cons obj (container-subobjects obj))
               time start sched)
      (dolist (sub (subcontainers obj))
        (schedule-object sub mystart sched)))))

(defmethod unschedule-object (obj &rest recurse) obj recurse nil)

;;; The seq (entry) is represented as a list, with the seq-object as
;;; first element and the subobjects as the rest. It works by splicing
;;; out the head of the cdr, scheduling it with write-event and then
;;; calling enqueue with the modified entry. Container objects in the
;;; cdr of the entry list are skipped.
;;;
;;; Note: scheduler-do-seq only outputs one event (if a non-seq event
;;; exists in the cdr of entry) and then calls enqueue with the
;;; reduced list (which in turn calls scheduler-do-seq again).)

(defun scheduler-do-seq (entry time start stream type sched)
  time
  (let ((head (cdr entry)) (event nil) (next nil))
    (do ()
        ((or event (null head)) nil)
      (setf next (pop head))
      (unless (typep next <container>) (setf event next)))
    (rplacd entry head)
    (if event
        (progn
         (setf next (+ start (object-time event)))
         (if (early? next sched)
             (enqueue *qentry-object* event next start sched)
             (write-event event stream next))
         (if (null head) nil
             (enqueue type entry (+ start (object-time (car head)))
              start sched)))
        nil)))

;;; a process is a function which runs and eventually outputs
;;; events. scheduler-do-process calls this function and reschedules
;;; it in case it doesn't return nil. A process is implemented as a
;;; BLOCK statement which returns T and returns nil using :RETURN_FROM
;;; in case a final condition is met.

(defun scheduler-do-process (func qtime pstart stream type sched)
  stream
;;;  (format *debug-io* "~&scheduler-do-process, scheduling-mode: ~a qtime: ~a, pstart: ~a~%" (scheduling-mode) qtime pstart)
  (case sched
    ((:events)
     (setf *pstart* pstart)
     (setf *qtime* qtime)
     (setf *qnext* qtime)
     (if (funcall func) (enqueue type func *qnext* *pstart* sched))
     (setf *pstart* nil)
     (setf *qtime* nil)
     (setf *qnext* nil))
    ((:rts)
     (setf *rts-pstart* pstart)
     (setf *rts-qtime* qtime)
     (setf *rts-qnext* qtime)
     (if (funcall func)
         (enqueue type func *rts-qnext* *rts-pstart* sched))
     (setf *rts-pstart* nil)
     (setf *rts-qtime* nil)
     (setf *rts-qnext* nil))))

(defun output (event &key to at (ahead 0))
  (let ((sched (scheduling-mode)))
;;;    (break "output event: ~a, to: ~a, at: ~a, ahead: ~a, sched: ~a" event to at ahead sched)
    (case sched
      ((:events)
       (unless to (setf to *out*))
       (if (consp event)
           (dolist (e event)
             (let ((n (+ (or *pstart* 0) (or at (object-time e)))))
               (if (early? n sched)
                   (enqueue
                    (if (integerp e) *qentry-message*
                        *qentry-object*)
                    e n nil sched)
                   (write-event e to (+ n ahead)))))
           (let ((n (+ (or *pstart* 0) (or at (object-time event)))))
             (if (early? n sched)
                 (enqueue
                  (if (integerp event) *qentry-message*
                      *qentry-object*)
                  event n nil sched)
                 (write-event event to (+ n ahead))))))
      ((:rts)
       (unless to (setf to *rts-out*))
       (progn
         (write-event event to (+ (or at 0) ahead))))
      (t
       (unless to (setf to *rts-out*))
       (write-event event to (+ (or at 0) ahead))))
    (values)))

(defun now (&optional abs-time)
;;;  (format t "now, scheduling-mode: ~a, abs-time: ~a, *qtime*: ~a, *pstart*: ~a~%" (scheduling-mode) abs-time *qtime* *pstart*)
  (case (scheduling-mode)
    ((:events) (if abs-time *qtime* (- *qtime* *pstart*)))
    ((:rts) (if abs-time *rts-qtime* (- *rts-qtime* *rts-pstart*)))
    (t (rts-now))))

(defun wait (time)
  (case (scheduling-mode)
    ((:events) (setf *qnext* (+ *qnext* (abs time))))
    ((:rts) (setf *rts-qnext* (+ *rts-qnext* (* *rt-scale* (abs time)))))
    (t (error "wait: scheduler not running."))))

(defun sprout (obj &key to at)
  (if (consp obj) (dolist (o obj) (sprout o :at at :to to))
      (let ((sched (scheduling-mode))
            (*rt-scale* *rt-scale*))
        (if (not sched) ;;; called from repl
            (if (not at) (setf at (now)))
            (if at
                (if (eq sched ':events) (setf at (+ at *pstart*))
                    (setf at (+ at *rts-pstart*)))
                (setf at (now))))
        ;;        (format t "~&sprout, obj-type: ~a, now: ~a, at: ~a, *pstart*: ~a" (typep obj <object>) (now) at *pstart*)
        (cond
          ((functionp obj) (enqueue *qentry-process* obj at at sched))
          ((integerp obj) (enqueue *qentry-message* obj at nil sched))
          ((typep obj <object>)
           (schedule-object obj (or *pstart* at) sched))
          (t (enqueue *qentry-unknown* obj at nil sched)))))
  (values))

(defun sec (val fmat)
  (case fmat
    ((:sec) val)
    ((:msec) (/ val 1000.0))
    ((:usec) (/ val 1000000.0))
    (t (error "sec: time format ~s not :sec :msec or :usec." fmat))))

(defun msec (val fmat)
  (case fmat
    ((:sec) (values (floor (* val 1000))))
    ((:msec) val)
    ((:usec) (values (floor val 1000)))
    (t (error "msec: time format ~s not :sec :msec or :usec." fmat))))

(defun usec (val fmat)
  (case fmat
    ((:sec) (values (floor (* val 1000000))))
    ((:msec) (values (floor (* val 1000))))
    ((:usec) val)
    (t (error "usec: time format ~s not :sec :msec or :usec." fmat))))
