(in-package :cl-bodge.scene)


(declaim (special *shading-pipeline*
                  *shading-parameters*))


;;;
;;;
;;;
(defclass shading-parameters ()
  ((bindings :initform (make-hash-table :test #'equal))))


(defun bind-parameter (name shading-program)
  (with-slots (bindings) *shading-parameters*
    (with-hash-entries ((programs name)) bindings
      (if (null programs)
          (setf programs (list shading-program))
          (push shading-program programs)))))


(defun unbind-parameter (name)
  (with-slots (bindings) *shading-parameters*
    (with-hash-entries ((programs name)) bindings
      (when (null programs)
        (error "No bindings found for parameter '~a'" name))
      (pop programs)
      (when (null programs)
        (remhash name bindings)))))


(defmacro with-bound-parameters ((parameters program) &body body)
  (once-only (parameters program)
    `(progn
       (dolist (name ,parameters)
         (bind-parameter name ,program))
       (unwind-protect
            (progn
              ,@body)
         (dolist (name ,parameters)
           (unbind-parameter name))))))


(defun (setf shading-parameter) (value name)
  (with-slots (bindings) *shading-parameters*
    (let* ((bracket-pos (position #\[ name :from-end t))
           (registration-name (if (null bracket-pos)
                                  name
                                  (format nil "~a[0]~a"
                                          (subseq name 0 bracket-pos)
                                          (subseq name (1+ (position #\] name
                                                                     :start bracket-pos)))))))
      (with-hash-entries ((programs registration-name)) bindings
        (when (null programs)
          (error "Parameter with name '~a' is unbound" name))
        (setf (program-uniform-variable (first programs) name) value)))))


#++
(defun shading-parameter (name)
  (with-slots (bindings) *shading-parameters*
    (with-hash-entries ((programs name)) bindings
      (when (null programs)
        (error "Parameter with name '~a' is unbound" name))
      (program-uniform-variable (first programs) name))))


;;;
;;;
;;;
(defclass shading-pipeline-node (scene-node)
  ((pipeline :initarg :pipeline)))


(defmethod node-enabled-p ((this shading-pipeline-node))
  (with-slots (pipeline) this
    (not (null pipeline))))


(defmethod initialization-flow ((this shading-pipeline-node) &key)
  (>> (call-next-method)
      (-> ((graphics)) ()
        (with-slots (pipeline) this
          (setf pipeline (make-shading-pipeline))))))


(defmethod discard-node :before ((this shading-pipeline-node))
  (with-slots (pipeline) this
    (let ((p pipeline))
      (setf pipeline nil)
      (dispose p))))


(defmethod scene-pass ((this shading-pipeline-node) (pass rendering-pass) input)
  (with-slots (pipeline) this
    (let ((*shading-pipeline* pipeline)
          (*shading-parameters* (make-instance 'shading-parameters)))
      (with-bound-shading-pipeline (*shading-pipeline*)
        (call-next-method)))))


;;;
;;;
;;;
(defclass shading-program-node (scene-node)
  ((program :initform nil)
   (sources :initarg :sources)
   (parameters :initform '())))


(defmethod node-enabled-p ((this shading-program-node))
  (with-slots (program) this
    (not (null program))))


(defmethod initialization-flow ((this shading-program-node) &key)
  (>> (call-next-method)
      (-> ((graphics)) ()
        (with-slots (program sources parameters) this
          (setf program (build-shading-program sources)
                parameters (mapcar #'uniform-name (uniforms-of program)))))))


(defmethod discard-node :before ((this shading-program-node))
  (with-slots (program) this
    (let ((p program))
      (setf program nil)
      (dispose p))))


(defmethod scene-pass ((this shading-program-node) (pass rendering-pass) input)
  (with-slots (program parameters) this
    (use-shading-program-stages *shading-pipeline* program :all-shader)
    (with-bound-parameters (parameters program)
      (call-next-method))))

;;;
;;;
;;;
(defclass shading-parameters-node (scene-node)
  ((params :initarg :parameters)))


(defmethod scene-pass ((this shading-parameters-node) (pass rendering-pass) input)
  (with-slots (params) this
    (loop for (name . value) in params do
         (setf (shading-parameter name) (if (functionp value) (funcall value) value)))
    (call-next-method)))
