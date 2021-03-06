(in-package :cl-bodge.scene)


(declaim (special *scene*))


;;;
;;;
;;;

(defgeneric pass-data-of (node)
  (:method (node) nil))


(defgeneric (setf pass-data-of) (value node)
  (:method (value node) nil))


(defclass scene-node (node)
  ((pass-data :initform nil :accessor pass-data-of)))


(defgeneric node-enabled-p (node)
  (:method (node) t))


(defgeneric discard-node (node)
  (:method (node)))


(defun discard-tree (root)
  (dotree (node root :post)
    (discard-node node)))


(defgeneric scene-pass (node pass input)
  (:method (node pass input)
    (dochildren (child node)
      (when (node-enabled-p child)
        (setf (pass-data-of child)
              (scene-pass child pass (pass-data-of child)))))
    input))

;;;
;;;
;;;
(defclass scene-pass () ())


(defgeneric run-scene-pass (pass node)
  (:method (pass root)
    (when (node-enabled-p root)
      (scene-pass root pass (pass-data-of root)))))


(defmethod dispatch ((this scene-pass) (task function) invariant &key)
  (funcall task)
  t)


(defclass system-scene-pass (dispatcher scene-pass)
  ((system :initarg :system :reader system-of)))


(defmethod dispatch ((this system-scene-pass) (task function) invariant &rest keys &key)
  (apply #'dispatch (system-of this) task invariant keys))


;;;
;;;
;;;
(defclass pass-chain ()
  ((passes :initarg :passes :reader passes-of)))

(definline make-pass-chain (&rest passes)
  (make-instance 'pass-chain :passes passes))


(defun process-pass-chain-flow (chain root-node)
  (flet ((make-processor (pass)
           (-> (pass :important-p nil) ()
             (run-scene-pass pass root-node))))
    (mapcar #'make-processor (passes-of chain))))


;;;
;;;
;;;
(defclass scene-root-node (scene-node) ())


;;;
;;;
;;;
(defclass scene (disposable)
  ((pass-chain :initarg :pass-chain :initform (error "Pass chain must be supplied")
               :reader pass-chain-of)
   (root :initform (make-instance 'scene-root-node) :reader root-of)))


(defun make-scene (pass-chain &rest children)
  (let* ((scene (make-instance 'scene :pass-chain pass-chain))
         (root (root-of scene)))
    (dolist (child children)
      (adopt root child))
    scene))


(define-destructor scene (root)
  (discard-tree root))


(definline node (scene name)
  (find-node (root-of scene) name))


(defmacro doscene ((child scene) &body body)
  (once-only (scene)
    `(let ((*scene* ,scene))
       (dotree (,child (root-of ,scene))
         ,@body))))


(defun scene-processing-flow (scene)
  (>> (process-pass-chain-flow (pass-chain-of scene) (root-of scene))))


;;;
;;;
;;;
(defun %children-adoption-flow ()
  (labels ((%adopt (nodes)
             (let ((parent (caar nodes)))
               (dolist (child (cdr nodes))
                 (adopt parent (caar child))
                 (%adopt child)))))
    (instantly (nodes)
      (%adopt nodes)
      (caar nodes))))


(defun %parse-tree (node-def)
  (destructuring-bind (ctor-def &rest children) (ensure-list node-def)
    (destructuring-bind (class &rest plist) (ensure-list ctor-def)
      `(list (assembly-flow ',class ,@plist)
             ,@(loop for child-def in children collecting
                    (%parse-tree child-def))))))


(defmacro scenegraph (root)
  "Returns flow for constructing a scenegraph"
  `(>> (~> ,(%parse-tree root))
       (%children-adoption-flow)))

;;;
;;;
;;;
(defclass enableable-node ()
  ((enabled-p :initform t :initarg :enabled-p)))


(defmethod node-enabled-p ((this enableable-node))
  (with-slots (enabled-p) this
    enabled-p))


(defgeneric enable-node (node)
  (:method ((node enableable-node))
    (with-slots (enabled-p) node
      (setf enabled-p t))))


(defgeneric disable-node (node)
  (:method ((node enableable-node))
    (with-slots (enabled-p) node
      (setf enabled-p nil))))
