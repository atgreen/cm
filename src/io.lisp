;;; **********************************************************************
;;; Copyright (C) 2009 Heinrich Taube, <taube (at) uiuc (dot) edu>
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the Lisp Lesser Gnu Public License.
;;; See http://www.cliki.net/LLGPL for the text of this agreement.
;;; **********************************************************************

;;; generated by scheme->cltl from io.scm on 19-Mar-2009 14:43:22

(in-package :cm)

(progn
 (defclass event-stream (container)
           ((time :accessor object-time)
            (open :initform nil :accessor io-open)
            (stream :initform nil :initarg :stream :accessor event-stream-stream)
            (args :initform '() :accessor event-stream-args)
            (direction :initform nil :accessor io-direction)))
 (defparameter <event-stream> (find-class 'event-stream))
 (finalize-class <event-stream>)
 (values))

(progn
 (defclass rt-stream (event-stream)
           ((receive-mode :accessor rt-stream-receive-mode :initarg :receive-mode)
            (receive-rate :accessor rt-stream-receive-rate :initform 0.001 :initarg :receive-rate)
            (receive-data :accessor rt-stream-receive-data :initform '())
            (receive-type :accessor rt-stream-receive-type :initarg :receive-type :initform nil)
            (receive-hook :accessor rt-stream-receive-hook :initarg :receive-hook :initform nil)
            (receive-stop :accessor rt-stream-receive-stop :initform nil)
            (latency :accessor rt-stream-latency :initarg :latency :initform 0)))
 (defparameter <rt-stream> (find-class 'rt-stream))
 (finalize-class <rt-stream>)
 (values))

(progn
 (defclass event-file (event-stream)
           ((version :initform 0 :accessor event-file-version :initarg :version)
            (versioning :initform nil :initarg :versioning :accessor event-file-versioning)
            (elt-type :initform :char :accessor file-elt-type :initarg :elt-type)))
 (defparameter <event-file> (find-class 'event-file))
 (finalize-class <event-file>)
 (values))

(defun io-classes () (class-subclasses <event-stream>))

(defun io-filename (io) (object-name io))

(defun write-event-streams (class)
  (cond ((null class) (list))
        ((consp class)
         (let ((strs (write-event-streams (car class))))
           (if (null strs) (write-event-streams (cdr class)) strs)))
        (t
         (let ((strs (class-event-streams class)))
           (if (null strs)
               (write-event-streams
                (class-direct-superclasses class))
               strs)))))

(defun io-stream-classes ()
  (do ((l (io-classes) (cdr l))
       (r '()))
      ((null l) (reverse r))
    (let ((h (io-class-file-types (car l))))
      (if h (push (car l) r)))))

(defun filename->event-class (path)
  (let ((name (filename-name path)) (type (filename-type path)))
    (if type
        (flet ((matchone (key name type)
                 (let ((nam (filename-name key))
                       (ext (filename-type key)))
                   (when (or (eq nam :wild) (string= nam "*"))
                     (setf nam nil))
                   (if nam
                       (if (string= nam name)
                           (if (string= ext type) t nil) nil)
                       (if (string= ext type) t nil)))))
          (do ((l (io-stream-classes) (cdr l))
               (c nil))
              ((or (null l) c)
               (or c (error "No file or port class for ~s." path)))
            (do ((x (io-class-file-types (car l)) (cdr x)))
                ((or (null x) c) c)
              (if (matchone (car x) name type) (setf c (car l))))))
        (error "Missing .ext in file or port specification: ~s"
               path))))

(defmacro io (str &body args) `(init-io ,str ,@args))

(defmethod init-io (io &rest inits) inits io)

(defmethod init-io ((string string) &rest inits)
           (let ((io (find-object string)))
             (if io (apply #'init-io io inits)
                 (let ((class (filename->event-class string)))
                   (if class
                       (multiple-value-bind
                           (init args)
                           (expand-inits class inits t t)
                         (let ((n
                                (apply #'make-instance class ':name
                                       string init)))
                           (if (not (null args))
                               (setf (event-stream-args n) args))
                           n))
                       (error "~s is not a valid port or file name."
                              string))))))

(defmethod init-io ((io event-stream) &rest inits)
  "init-io sets the slots referred to by inits to the given
values. Non-existent slots are stored in the event-stream-args slot
of the io stream. Returns the io stream."
  (unless (null inits)
             (multiple-value-bind
                 (init args)
                 (expand-inits (class-of io) inits nil t)
               (dopairs (s v init) (setf (slot-value io s) v))
               (if (not (null args))
                   (setf (event-stream-args io) args))))
           io)

(defun bump-version (stream)
  (if (event-file-versioning stream)
      (let ((vers (+ (event-file-version stream) 1)))
        (setf (event-file-version stream) vers)
        vers)
      nil))

(defun file-output-filename (file)
  (let ((v
         (if (event-file-versioning file) (event-file-version file)
             nil))
        (n (object-name file)))
    (if (integerp v)
        (concatenate 'string (or (filename-directory n) "")
                     (filename-name n) "-" (prin1-to-string v) "."
                     (filename-type n))
        n)))

(defmethod open-io ((obj string) dir &rest args)
           (let ((io (apply #'init-io obj args)))
             (apply #'open-io io dir args)))

(defmethod open-io ((obj event-file) dir &rest args) args
           (let ((file nil) (name nil))
             (if (eq dir :output)
                 (cond
                  ((event-stream-stream obj)
                   (setf file (event-stream-stream obj)))
                  (t (bump-version obj)
                   (setf name (file-output-filename obj))
                   (if (probe-file name) (delete-file name))
                   (setf file
                           (open-file name dir
                            (file-elt-type obj)))))
                 (if (eq dir :input)
                     (if (event-stream-stream obj)
                         (setf file (event-stream-stream obj))
                         (setf file
                                 (open-file (object-name obj) dir
                                  (file-elt-type obj))))
                     (error "Direction not :input or :output: ~s"
                            dir)))
             (setf (io-direction obj) dir)
             (setf (io-open obj) file)
             obj))

(defmethod open-io ((obj seq) dir &rest args) dir args
           (remove-subobjects obj) obj)

(defmethod close-io (io &rest mode) mode io)

(defmethod close-io ((io event-file) &rest mode) mode
           (when (io-open io)
             (unless (event-stream-stream io)
               (close-file (io-open io) (io-direction io)))
             (setf (io-open io) nil))
           io)

(defmethod initialize-io (obj) obj)

(defmethod deinitialize-io (obj) obj)

(defun io-open? (io) (io-open io))

(defmacro with-open-io (args &body body)
  (let ((io (pop args))
        (path (pop args))
        (dir (pop args))
        (err? (gensym))
        (val (gensym)))
    `(let ((,io nil) (,err? ':error))
       (unwind-protect
           (progn
            (let ((,val nil))
              (setf ,io (open-io ,path ,dir ,@args))
              ,@(if (eq dir ':output) `(funcall (initialize-io ,io))
                    (list))
              (setf ,val (progn ,@body))
              (setf ,err? nil)
              (if ,err? nil ,val)))
         (when ,io
           ,@(if (eq dir ':output) `(funcall (deinitialize-io ,io))
                 (list))
           (close-io ,io ,err?))))))

(defparameter *in* nil)

(defparameter *out* nil)

(defparameter *rts-out* nil)

(defparameter *rts-in* nil)

(defparameter *last-output-file* nil)

(defun current-input-stream () *in*)

(defun current-output-stream () *out*)

(defun set-current-input-stream! (stream)
  (unless (or (null stream) (typep stream <object>))
    (error "set-current-input-stream: ~s not a stream." stream))
  (setf *in* stream)
  stream)

(defun set-current-output-stream! (stream)
  (unless (or (null stream) (typep stream <object>))
    (error "set-current-output-stream: ~s not a stream." stream))
  (setf *out* stream)
  stream)

(defparameter *special-event-streams*
  `((,#'stringp) (,#'null) (,#'typep ,<object>))
  "extendable list of special targets of the events function.")

(defun special-evt-stream? (first-arg)
  (loop
     for (fn . args) in *special-event-streams*
     for res = (apply fn first-arg args)
     until res finally (return res)))

(defun events (object &rest args)
  (let* ((to (if (and (consp args) (special-evt-stream? (first args)))
                 (pop args)
                 (current-output-stream)))
         (ahead (if
                 (and (consp args)
                      (or (consp (car args)) (numberp (car args))))
                 (pop args) 0))
         (err? ':error))
    (when (oddp (length args))
      (error "events: uneven initialization list: ~s." args))
    (flet ((getobj (x)
             (if (not (null x))
                 (if (or (stringp x) (and x (symbolp x)))
                     (find-object x) x)
                 (error "events: not a sproutable object: ~s." x))))
      (unwind-protect
          (progn
           (if (not to) (setf *out* nil)
               (progn
                (setf *out*
                        (open-io (apply #'init-io to args) ':output))
                (initialize-io *out*)))
           (schedule-events *out*
            (if (consp object) (mapcar #'getobj object)
                (getobj object))
            ahead)
           (setf err? nil))
        (when *out* (deinitialize-io *out*) (close-io *out* err?))))
    (if (or err? (not *out*)) nil
        (if (typep *out* <event-file>)
            (let ((path (file-output-filename *out*))
                  (args (event-stream-args *out*))
                  (hook (io-class-output-hook (class-of *out*))))
              (when hook (apply hook path args))
              path)
            *out*))))

(defmethod write-event (obj io time) obj io time
  (format t "stub~%"))

(defmethod write-event (obj (io seq) time)
  (let ((obj (copy-object obj)))
    (setf (object-time obj) time)
    (insert-object obj io)))

(defmethod import-events ((file string) &rest args)
  (if (probe-file file)
      (let ((old (find-object file nil))
            (io (init-io file))
            (res nil))
        (setf res (apply #'import-events io args))
        (unless old
          (%remove-from-dictionary (object-name io)))
        res)
      nil))

(defun play (file &rest args)
  (let* ((meta (filename->event-class file))
         (hook (io-class-output-hook meta)))
    (if hook
        (if (probe-file file)
            (let* ((obj (find-object file nil))
                   (old (if obj (event-stream-args obj) (list))))
              (apply hook file :play t (append args old))
              file)
            nil)
        nil)))

(defparameter *receive-type* nil)

(cond-expand (cmu (setf *receive-type* ':periodic))
 (sbcl (setf *receive-type* ':periodic))
 (gauche (setf *receive-type* ':srfi-18))
 (openmcl (setf *receive-type* ':pthreads)) (else nil))

(defparameter *receive-methods* (list))

(defmethod stream-receive-init ((stream rt-stream) hook args) stream
           hook args (values))

(defmethod stream-receive-start ((stream rt-stream) args)
           (let* ((type (rt-stream-receive-type stream))
                  (meth (assoc type *receive-methods*)))
             (if (not meth) nil
                 (let ((start (cadr meth)))
                   (funcall start stream args)))))

(defmethod stream-receive-stop ((stream rt-stream))
           (let* ((type (rt-stream-receive-type stream))
                  (meth (assoc type *receive-methods*)))
             (if (not meth) nil
                 (let ((stop (caddr meth)))
                   (funcall stop stream)))))

(defmethod stream-receive-deinit ((stream rt-stream)) stream (values))

(defmethod stream-receive? ((stream rt-stream))
           (let ((data (rt-stream-receive-data stream)))
             (if (and (not (null data)) (first data)) t nil)))

(defmethod set-receive-mode! ((str rt-stream) mode)
           (setf (rt-stream-receive-mode str) mode))
#|

;; moved to cm-incudine:

(defun set-receiver! (hook stream &rest args)
  (let ((data (rt-stream-receive-data stream)))
    (if (and (not (null data)) (first data))
        (error "set-receiver!: ~s already receiving." stream)
        (let ((type (getf args ':receive-type)))
          (if type (setf (rt-stream-receive-type stream) type)
              (if (and (not (rt-stream-receive-type stream))
                       (not (equal (type-of stream) 'jackmidi:input-stream)))
                  (setf (rt-stream-receive-type stream)
                          *receive-type*)))
          (stream-receive-init stream hook args)
          (cond
           ((stream-receive-start stream args)
            (format t "~%; ~a receiving!" stream))
           (t (stream-receive-deinit stream)
            (error
             "set-receiver!: ~s does not support :receive-type ~s."
             stream (rt-stream-receive-type stream))))
          (values)))))
|#

(defun remove-receiver! (stream)
  (stream-receive-stop stream)
  (stream-receive-deinit stream)
  (let ((data (rt-stream-receive-data stream)))
    (when (and (not (null data)) (elt data 0))
      (setf (elt data 0) nil)))
  (values))

(defun receiver? (stream) (stream-receive? stream))
