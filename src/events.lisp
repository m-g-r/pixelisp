;; -*- Lisp -*-

(defpackage :events
  (:use :cl :alexandria)
  (:export #:subscribe #:publish
           #:make-event #:type #:data #:id))

(in-package :events)

(defclass event ()
  ((type :initarg :type :reader type)
   (data :initarg :data :reader data)
   (id :initarg :id :reader id)))

(defmethod print-object ((event event) stream)
  (print-unreadable-object (event stream :type t)
    (format stream "TYPE: ~A DATA: ~S~@[ ID: ~A~]"
            (type event) (data event) (id event))))

(defvar *subscribers* nil)

(defun subscribe (handler)
  (push handler *subscribers*))

(defun publish (type data &key id)
  (let ((event (make-instance 'event
                              :type type
                              :data data
                              :id id)))
    (dolist (handler *subscribers*)
      (handler-case
          (funcall handler event)
        (error (e)
          (cl-log:log-message :info "Cannot deliver event to handler ~A, error ~A (unsubscribing)"
                              handler e)
          (removef *subscribers* handler))))))
