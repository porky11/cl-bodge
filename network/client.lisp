(in-package :cl-bodge.network)


(declaim (special *message*
                  *connector*))

;;
(defclass connector (lockable disposable dispatching)
  ((stream :initform nil :reader stream-of)
   (sink :initform nil)
   (output-buffer :initform (make-array +max-data-chunk-size+
                                        :element-type '(unsigned-byte 8)))
   (message-counter :initform 0)
   (message-table :initform (make-hash-table :test 'eql))))


(defgeneric process-chunk (connector chunk value)
  (:method (connector chunk value)
    (declare (ignore connector chunk value))))


(defmethod process-chunk ((this connector) (chunk magic-chunk) value)
  (unless (equalp value +server-magic+)
    (error "Unsupported protocol")))


(defmethod process-chunk ((this connector) (chunk protocol-version-chunk) value)
  (unless (equal value +protocol-version+)
    (error "Unsupported protocol")))


(defmethod process-chunk ((this connector) (chunk message-chunk) message)
  (with-slots (message-table output-buffer) this
    (let* ((*connector* this))
      (if (typep message 'reply-message)
          (let ((reply-id (reply-message-for message)))
            (with-instance-lock-held (this)
              (if-let ((handler (gethash reply-id message-table)))
                (progn
                  (remhash reply-id message-table)
                  (funcall handler message))
                (log:error "Handler not found for message with id ~A" reply-id))))
          (when-let ((reply (process-message message)))
            (let ((encoded (make-instance 'fast-io:fast-output-stream
            (encode-message reply stream)
            (force-output stream))))))


(defmethod initialize-instance :after ((this connector) &key host port)
  (with-slots (stream message-table sink) this
    (flet ((on-chunk-read (chunk value)
             (process-chunk this chunk value))
           (read-incoming (socket stream)
             (declare (ignore socket))
             (process-chunks sink stream))
           (process-event (ev)
             (log:warn ev)))
      (mt:wait-with-latch (latch)
        (in-new-thread "connector-thread"
          (as:with-event-loop ()
            (unwind-protect
                 (progn
                   (setf stream (as:tcp-connect host port #'read-incoming
                                                :stream t
                                                :event-cb #'process-event)
                         sink (make-instance 'stream-sink
                                             :on-chunk-read #'on-chunk-read
                                             :chunk (make-instance 'magic-chunk)))
                   (write-sequence +client-magic+ stream)
                   (write-byte +protocol-version+ stream))
              (mt:open-latch latch))))))))


(defun check-response (message expected-command)
  (let ((command (getf message :command)))
    (when (eq command :error)
      (error "Server error of type ~A: ~A" (getf message :type) (getf message :text)))
    (unless (eq command expected-command)
      (error "Unexpected command received from server: wanted ~A, but ~A received"
             expected-command command))))


(defun send-command (connector &rest properties &key &allow-other-keys)
  (let ((stream (connection-stream-of connector)))
    (encode-message properties stream)
    (finish-output stream)))


(defmacro with-response ((&rest properties) command-name &body body)
  `(with-message (,@properties) *message*
     (check-response *message* ,command-name)
     ,@body))


(defmethod dispatch ((this connector) (task function) invariant &rest keys
                     &key &allow-other-keys)
  (with-slots (enabled-p message-table message-counter) this
    (with-instance-lock-held (this)
      (flet ((response-callback (message)
               (let ((*message* message))
                 (funcall task))))
        (if enabled-p
            (let ((next-id (incf message-counter)))
              (unless (getf keys :no-reply)
                (setf (gethash next-id message-table) #'response-callback))
              (apply #'send-command this :message-id next-id keys))
            (response-callback (list :command :error
                                     :type :disconnected
                                     :text "Disconnected from server")))))))
