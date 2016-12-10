;; -*- Lisp -*-

(defpackage :utils
  (:use :cl :alexandria)
  (:shadow #:sleep)
  (:export #:run-program
           #:try-receive
           #:sleep
           #:agent-body))

(in-package :utils)

(defun run-program (program &rest args)
  (with-output-to-string (output)
    (multiple-value-bind (status exit-code)
        (ccl:external-process-status (ccl:run-program program args
                                                      :wait t
                                                      :output output))
      (declare (ignore status))
      (unless (zerop exit-code)
        (error 'simple-error
               :format-control "shell command \"~A~@[ ~A~]\" failed with exit code ~D~@[~%~A~]"
               :format-arguments (list program args exit-code (get-output-stream-string output)))))))

(defun try-receive ()
  (handler-case
      (erlangen:receive :timeout 0)
    (erlangen:timeout (e)
      (declare (ignore e))
      nil)))

(defun sleep (seconds)
  (let ((until (+ (get-universal-time) seconds)))
    (erlangen:select
     ((> (get-universal-time) until) (_) t))))

(defmacro agent-body (&body body)
  `(lambda ()
     (handler-bind
         ((erlangen.agent:exit (lambda (e)
                                 (cl-log:log-message :info "agent ~A exiting: ~A" (erlangen:agent) e))))
       ,@body)))
