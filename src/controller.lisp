;; -*- Lisp -*-

(defpackage :controller
  (:use :cl :alexandria)
  (:export #:start
           #:power
           #:script
           #:all-scripts))

(in-package :controller)

(defvar *script-directory* #P"scripts/")

(storage:defconfig 'script "gallery-and-clock")

(defun all-scripts ()
  (sort (mapcar #'pathname-name (directory (make-pathname :name :wild :type "lisp" :defaults *script-directory*)))
        #'string-lessp))

(defun find-script (name)
  (probe-file (make-pathname :name name :type "lisp"
                             :defaults *script-directory*)))

(defun restart ()
  (ccl:process-interrupt (messaging:agent-named :controller)
                         (lambda () (throw 'restart nil))))

(defvar *power* t)

(defun (setf power) (power)
  (cond
    ((eql power :toggle)
     (setf *power* (not *power*))
     (restart))
    ((not (eql power *power*))
     (setf *power* power)
     (restart)))
  *power*)

(defun power ()
  *power*)

(defun (setf script) (name)
  (unless (equal name (storage:config 'script))
    (setf (storage:config 'script) name)
    (restart))
  name)

(defun script ()
  (storage:config 'script))

(defun run-script ()
  (let ((*package* (find-package :cl-user))
        (script (find-script (storage:config 'script))))
    (cl-log:log-message :info "Running script ~S" script)
    (handler-case
        (progn
          (load script :verbose nil :print nil)
          (cl-log:log-message :info "Script ~S finished" script))
      (error (e)
        (cl-log:log-message :error "Error while running script ~S: ~A" script e)))))

(defun start ()
  (messaging:make-agent :controller
                        (lambda ()
                          (loop
                            (catch 'restart
                              (cond
                                (*power*
                                 (cl-log:log-message :info "Power on")
                                 (loop
                                   (run-script)))
                                (t
                                 (app:stop)
                                 (messaging:send :display :blank)
                                 (cl-log:log-message :info "Power off")
                                 (loop (sleep 1)))))))))

(hunchentoot:define-easy-handler (pause :uri "/power") (switch)
  (when (eql (hunchentoot:request-method*) :post)
    (setf (power)
          (ecase (intern (string-upcase switch) :keyword)
            (:on t)
            (:off nil)
            (:toggle :toggle))))
  (if (power)
      "on"
      "off"))

(hunchentoot:define-easy-handler (script-handler :uri "/script") (name)
  (if (eql (hunchentoot:request-method*) :post)
    (cond
      ((find-script name)
       (setf (script) name)
       name)
      (t
       (setf (hunchentoot:return-code*) hunchentoot:+http-not-found+)
       (format nil "script ~S not found" name)))
    (controller:script)))
