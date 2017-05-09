(in-package :cl-bodge.network)


(define-constant +max-data-chunk-size+ (* 64 1024))

(define-constant +client-magic+
    (make-array 4
                :element-type '(unsigned-byte 8)
                :initial-contents #(#xB0 #xD6 #xED #x05))
  :test #'equalp)

(define-constant +server-magic+
    (make-array 4
                :element-type '(unsigned-byte 8)
                :initial-contents #(#xFE #xED #xD0 #x0D))
  :test #'equalp)

(define-constant +protocol-version+ 1)

;;
(defclass circular-buffer ()
  ((buffer :initform nil)
   (start :initform 0)
   (end :initform 0)
   (empty-p :initform t)))


(defmethod initialize-instance :after ((this circular-buffer) &key (size (error ":size missing")))
  (with-slots (buffer) this
    (setf buffer (make-array size :element-type '(unsigned-byte 8)))))


(definline make-circular-buffer (size)
  (check-type size fixnum)
  (make-instance 'circular-buffer :size size))


(defun buffer-filled-size (buffer)
  (with-slots (start end buffer empty-p) buffer
    (cond
      (empty-p 0)
      ((> end start) (- end start))
      (t (+ (- (length buffer) start) end)))))


(definline buffer-size (buffer)
  (with-slots (buffer) buffer
    (length buffer)))


(defun fill-buffer (circular-buffer stream)
  (with-slots (buffer start end empty-p) circular-buffer
    (labels ((%update-end (bytes-read)
               (incf end bytes-read)
               (when (and (> bytes-read 0) empty-p)
                 (setf empty-p nil)))
             (%fill-buffer (circular-buffer stream read-before)
               (let* ((len (length buffer)))
                 (cond
                   ((and (null empty-p) (= start end)) (values read-before 0))
                   ((< end start)
                    (let ((bytes-read (- (read-sequence buffer stream
                                                        :start end
                                                        :end start)
                                         end)))
                      (%update-end bytes-read)
                      (values (+ read-before bytes-read)
                              (- start end))))
                   (t
                    (let ((bytes-read (- (read-sequence buffer stream :start end) end)))
                      (%update-end bytes-read)
                      (if (= end len)
                          (progn
                            (setf end 0)
                            (%fill-buffer circular-buffer stream bytes-read))
                          (values bytes-read
                                  (- end start)))))))))
      (%fill-buffer circular-buffer stream 0))))


(defun read-buffer (circular-buffer seq &key ((:start seq-start) 0) ((:end seq-end)))
  (with-slots (buffer start end empty-p) circular-buffer
    (labels ((%read-buffer (circular-buffer seq seq-start seq-end)
               (let* ((len (length buffer))
                      (seq-end (if seq-end (max seq-end seq-start) (length seq)))
                      (tail-size (if (> end start) (- end start) (- len start)))
                      (read-len (min (buffer-filled-size circular-buffer) (- seq-end seq-start))))
                 (cond
                   ((= read-len 0) 0)
                   ((<= read-len tail-size)
                    (let ((next-start (+ start read-len)))
                      (replace seq buffer
                               :start1 seq-start
                               :end1 seq-end
                               :start2 start
                               :end2 next-start)
                      (if (= next-start (length buffer))
                          (setf start 0)
                          (setf start next-start))
                      (when (= start end)
                        (setf start 0
                              end 0
                              empty-p t)))
                    read-len)
                   (t
                    (let ((seq-mid (+ seq-start tail-size)))
                      (+ (%read-buffer circular-buffer seq seq-start seq-mid)
                         (%read-buffer circular-buffer seq seq-mid seq-end))))))))
      (%read-buffer circular-buffer seq seq-start seq-end))))


;;
(defclass chunk-sink ()
  ((stream-buffer :initform (make-circular-buffer (* 2 +max-data-chunk-size+)))
   (chunk-buffer :initform (make-array +max-data-chunk-size+
                                       :element-type '(unsigned-byte 8)))
   (on-chunk-read :initform (error ":on-chunk-read missing") :initarg :on-chunk-read)
   (chunk :initform (error ":chunk missing") :initarg :chunk)))


(defun process-chunks (sink stream)
  (with-slots (stream-buffer chunk-buffer chunk on-chunk-read) sink
    (fill-buffer stream-buffer stream)
    (when (> (buffer-filled-size stream-buffer) (size-of chunk))
      (read-buffer stream-buffer chunk-buffer :end (size-of chunk))
      (flex:with-input-from-sequence (stream chunk-buffer :end (size-of chunk))
        (funcall on-chunk-read chunk (decode-value chunk stream)))
      (setf chunk (next-chunk chunk)))))


;;
(defclass binary-output-stream (trivial-gray-streams:fundamental-output-stream)
  ())
