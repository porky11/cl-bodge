(in-package :cl-bodge.utils)


(defmacro definline (name lambda-list &body body)
  `(progn
     (declaim (inline ,name))
     (defun ,name ,lambda-list ,@body)))


(definline f (value)
  (float value 0f0))


(defmacro in-development-mode (&body body)
  (declare (ignorable body))
  #-bodge-production-mode
  `(progn ,@body))


(defmacro log-errors (&body body)
  (with-gensyms (name)
    `(block ,name
       (handler-bind ((warning (lambda (w)
                                 (log:warn w)
                                 (return-from ,name)))
                      (t (lambda (e)
			   (dissect:with-capped-stack ()
			     (let ((error-text (with-output-to-string (stream)
						 (format stream "Unhandled error:~%")
						 (dissect:present e stream))))
			       (log:error "~a" error-text)
			       (in-development-mode
				 (break "~A: ~A" (type-of e) e))
			       (return-from ,name))))))
         (dissect:with-truncated-stack () ,@body)))))


(defmacro with-hash-entries ((&rest keys) hash-table &body body)
  (once-only (hash-table)
    (multiple-value-bind (lets mlets)
        (loop for key in keys
           for (val-name key-name key-value) = (if (listp key)
                                                            (append key (list (gensym)))
                                                            (list key key (gensym)))
           collecting `(,val-name (gethash ,key-value ,hash-table)) into mlets
           collecting `(,key-value ,key-name) into lets
           finally (return (values lets mlets)))
      `(let ,lets
         (symbol-macrolet ,mlets
           ,@body)))))


(defmacro make-hash-table-with-entries ((&rest initargs) (&rest keys) &body body)
  (with-gensyms (table)
    `(let ((,table (make-hash-table ,@initargs)))
       (with-hash-entries (,@keys) ,table
	 ,@body)
       ,table)))


(defun stream->byte-array (stream &key (initial-size 4096))
  (check-type initial-size positive-integer)
  (do ((buffer (make-array initial-size :element-type (stream-element-type stream)))
       (offset 0)
       (offset-wanted 0))
      ((/= offset-wanted offset)
       (if (= offset (length buffer))
           buffer
           (subseq buffer 0 offset)))
    (unless (zerop offset)
      (let ((new-buffer (make-array (* 2 (length buffer))
                                    :element-type (stream-element-type stream))))
        (replace new-buffer buffer)
        (setf buffer new-buffer)))
    (setf offset-wanted (length buffer)
          offset (read-sequence buffer stream :start offset))))


(declaim (inline file->byte-array))
(defun file->byte-array (pathname &optional (element-type '(unsigned-byte 8)))
  (with-input-from-file (stream pathname :element-type element-type)
    (stream->byte-array stream)))


(defmacro defenum (name &body values)
  (with-gensyms (value)
    (let ((enum-values-constant (symbolicate '+ name '-values+))
          (predicate (symbolicate name '-p)))
      `(progn
         (deftype ,name ()
           '(member ,@values))
         (define-constant ,enum-values-constant ',values :test #'equal)
         (declaim (ftype (function (,name) boolean) ,predicate)
                  (inline ,predicate))
         (defun ,predicate (,value)
           (not (null (member ,value ,enum-values-constant :test #'eql))))))))


(defun epoch-seconds (&optional (timestamp (now)))
  (+ (timestamp-to-unix timestamp) (/ (nsec-of timestamp) 1000000000)))


(defun real-time-seconds ()
  (/ (get-internal-real-time) internal-time-units-per-second))


(defmacro ensure-not-null (value)
  (once-only ((v value))
    `(if (null ,v)
         (error "Value of ~a must not be null" ',value)
       ,v)))


(defmacro bound-symbol-value (symbol &optional default-value)
  `(if (boundp ',symbol) ,symbol ,default-value))


(defmacro if-bound (symbol-or-list then-form &optional else-form)
  (let ((symbols (ensure-list symbol-or-list)))
    `(if (and ,@(loop for symbol in symbols collect
                     `(boundp ',symbol)))
         ,then-form
         ,else-form)))


(defmacro when-bound (symbol-or-list &body body)
  `(if-bound ,symbol-or-list
             (progn ,@body)))


(definline class-name-of (obj)
  (class-name (class-of obj)))


(defmacro dolines ((line-var text &optional result-form) &body body)
  (once-only (text)
    (with-gensyms (line-start line-end slen)
      `(loop with ,line-start = 0 and ,slen = (length ,text)
          for ,line-end = (or (position #\Newline ,text :start ,line-start) ,slen)
          for ,line-var = (make-array (- ,line-end ,line-start) :element-type 'character
                                      :displaced-to ,text :displaced-index-offset ,line-start)
          do (progn ,@body (setf ,line-start (1+ ,line-end)))
          until (= ,line-end ,slen)
          finally (return ,result-form)))))


;;;
;;;
;;;
(defclass parent ()
  ((children :initform '() :reader children-of)))


(defgeneric adopt (parent child)
  (:method ((this parent) child)
    (with-slots (children) this
      (nconcf children (list child)))))


(defgeneric abandon (parent child)
  (:method ((this parent) child)
    (with-slots (children) this
      (deletef children child))))


(defgeneric abandon-all (parent)
  (:method ((this parent))
    (with-slots (children) this
      (prog1 children
        (setf children nil)))))


(defmacro dochildren ((var parent) &body body)
  `(dolist (,var (children-of ,parent))
     ,@body))


(defun %do-tree-preorder (root action)
  (funcall action root)
  (dochildren (ch root)
    (%do-tree-preorder ch action)))


(defun %do-tree-postorder (root action)
  (dochildren (ch root)
    (%do-tree-postorder ch action))
  (funcall action root))


(defmacro dotree ((var root &optional (order :pre)) &body body)
  (let ((fn (ecase order
              (:pre '%do-tree-preorder)
              (:post '%do-tree-preorder))))
    `(,fn ,root (lambda (,var) ,@body))))


(defun search-sorted (value sorted-array &key (test #'eql) (predicate #'<) (key #'identity))
  (labels ((%aref (idx)
             (aref sorted-array idx))
           (%compare (idx)
             (funcall predicate value (funcall key (%aref idx))))
           (%test (idx)
             (funcall test value (funcall key (%aref idx))))
           (%search (start end)
             (if (= start end)
                 (values nil end)
               (let ((idx (floor (/ (+ start end) 2))))
                 (if (%test idx)
                     (values (%aref idx) idx)
                     (if (%compare idx)
                         (%search start idx)
                         (%search (1+ idx) end)))))))
    (%search 0 (length sorted-array))))


(defun list->array (list &rest dimensions)
  (let ((element (if (null dimensions)
                     (car list)
                     (loop repeat (length dimensions)
                        for el = list then (car el)
                        finally (return (car el)))))
        (dimensions (or dimensions (length list))))
    (typecase element
      (integer
       (make-array dimensions :element-type 'integer
                   :initial-contents list))
      (single-float
       (make-array dimensions :element-type 'single-float
                   :initial-contents list)))))


(defun foreign-function-pointer (function-name)
  (when-let* ((fn (autowrap:find-function function-name)))
    (let ((name (autowrap:foreign-symbol-c-symbol fn)))
      (cffi-sys:%foreign-symbol-pointer name :default))))


(defun stringify (value &optional (format-string "~A"))
  (if (stringp value)
      value
      (format nil format-string value)))


(definline if-null (value default)
  (if (null value)
      default
      value))


(defun apply-argument-list (lambda-list)
  (multiple-value-bind (required optional rest keywords)
      (parse-ordinary-lambda-list lambda-list)
    (let ((args (append required (mapcar #'first optional))))
      (if rest
          (append args (list rest))
          (append args (reduce #'nconc (mapcar #'car keywords)) (list nil))))))


(defmacro with-float-traps-masked (&body body)
  (let ((masking #+sbcl '(sb-int:with-float-traps-masked (:overflow
                                                          :underflow
                                                          :inexact
                                                          :invalid
                                                          :divide-by-zero))
                 #-sbcl '(progn)))
    `(,@masking
      ,@body)))


(defun make-mutable-string (&optional (length 0))
  (make-array length :element-type 'character :fill-pointer t))


(defun string->mutable (string)
  (make-array (length string)
              :element-type 'character
              :fill-pointer t
              :initial-contents string))


(defun string->immutable (string)
  (if (subtypep (type-of string) '(simple-array character *))
      string
      (make-array (length string)
                  :element-type 'character
                  :initial-contents string)))


(defun mutate-string (string control-string &rest arguments)
  (setf (fill-pointer string) 0)
  (with-output-to-string (out string)
    (apply #'format out control-string arguments)))
