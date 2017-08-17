;; -*- Lisp -*-

(defpackage :server
  (:use :cl :alexandria)
  (:export #:start))

(in-package :server)

(defparameter *default-http-port* #-(or darwin x86-64) 80 #+darwin 8899 #+x86-64 8080)

(defun determine-project-root ()
  (let* ((defaults (truename *default-pathname-defaults*))
         (directory (pathname-directory defaults)))
    (if (equal (last directory)
               '("src"))
        (make-pathname :directory (butlast directory)
                       :defaults defaults)
        defaults)))

(defun start (&key (port *default-http-port*))
  (setf *default-pathname-defaults* (determine-project-root))
  (logging:start)
  (messaging:make-agent :main
                        (lambda ()
                          (storage:start)
                          (display:start)
                          (web-frame:start)
                          (when port
                            (webserver:start :port port))
                          (remote-control:start)
                          (alerter:start)
                          (app:make :clock 'clock:run)
                          (app:make :gallery 'gallery:play)
                          (controller:start)
                          (loop
                            (let ((message (messaging:receive)))
                              (cl-log:log-message :info "received message ~S" message))))
                        :parent nil))

(defun main (command-line-arguments)
  (declare (ignore command-line-arguments))
  (setf ccl:*break-hook* (lambda (cond hook)
                           (declare (ignore cond hook))
                           (format t "Exiting...~%")
                           (ccl:quit)))
  (start)
  (ccl:join-process ccl:*current-process*))
