;; -*- Lisp -*-

(defpackage :remote
  (:use :cl :alexandria))

(in-package :remote)

(defparameter *remote-port* 2020)

(defun parse-message (string)
  (multiple-value-bind (match registers)
      (ppcre:scan-to-strings "^[0-9a-f]+ 00 ([^ ]*) .*" string)
    (when match
      (intern (ppcre:regex-replace-all "_" (svref registers 0) "-") :keyword))))

(defun read-messages ()
  (let ((socket (ccl:make-socket :remote-host "localhost" :remote-port *remote-port*)))
    (unwind-protect
         (loop
           (when-let (key (parse-message (read-line socket)))
             (format t "~A~%" key)))
      (close socket))))