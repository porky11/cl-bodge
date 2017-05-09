(in-package :cl-bodge.network)


(defgeneric encode-message (message stream)
  (:method (message stream)
    (conspack:encode message :stream stream)))


(defgeneric decode-message (stream)
  (:method (stream)
    (conspack:decode-stream stream)))


(defgeneric make-message (class &key &allow-other-keys))

(defstruct (message
             (:constructor %make-message))
  (id nil :read-only t))


(defmacro defmessage (message-and-opts &body slots)
  (destructuring-bind (message-name &optional (parent 'message))
      (ensure-list message-and-opts)
    (let ((constructor-name (symbolicate '%make- message-name)))
      (flet ((process-slot-def (slot-def)
               (let ((def (ensure-list slot-def)))
                 (nconc def (list nil :read-only t)))))
        `(progn
           (defstruct (,message-name
                        (:include ,parent)
                        (:constructor ,constructor-name))
             ,@(mapcar #'process-slot-def slots))
           (defmethod make-message ((class (eql ',message-name))
                                    &rest initargs &key &allow-other-keys)
             (apply #',constructor-name initargs))
           (defmethod conspack:decode-object ((class (eql ',message-name)) alist &key)
             (apply #'make-message class (alist-plist alist))))))))


(defmethod conspack:encode-object ((this message) &key)
  (loop for slot in (closer-mop:class-slots (class-of this))
     for slot-name = (closer-mop:slot-definition-name slot)
     collecting (cons (make-keyword slot-name) (slot-value this slot-name))))


(defmessage (reply-message message)
  for)


(defmessage (error-message message)
  text)


(defgeneric process-message (message)
  (:method (message)
    (list :command :error
          :type :unknown-command
          :text "Unknown command")))


(defmethod process-message :around (message)
  (handler-case
      (when-let ((reply (call-next-method)))
        (nconc (list :reply-for (getf message :message-id)) reply))
    (serious-condition (e)
      (log:error "Unhandled error during command processing:~%~A: ~A" (type-of e) e)
      '(:command :error
        :type :unhandled-error
        :text "Error during command execution"))))
