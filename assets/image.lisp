(in-package :cl-bodge.assets)


(defclass image ()
  ((width :initarg :width :reader width-of)
   (height :initarg :height :reader height-of)
   (format :initarg :pixel-format :reader pixel-format-of)
   (data :initarg :data :reader data-of)))


(defun prepare-png-data (width height pixel-format data)
  (loop with channels = (ecase pixel-format
                          (:grey 1)
                          (:rgb 3)
                          (:rgba 4))
        with result = (make-foreign-array (* width height channels)
                                          :element-type '(unsigned-byte 8))
        with array = (simple-array-of result)
     for i from 0 below height do
       (loop for j from 0 below width do
            (if (= channels 1)
                (setf (aref array (+ j (* i width)))
                       (aref data i j))
                (loop for k from 0 below channels do
                     (setf (aref array (+ k (* j channels) (* (- height i 1) width channels)))
                           (aref data i j k)))))
     finally (return result)))


(defun load-png-image (path)
  (let* ((data (opticl:read-png-file path))
         (format (etypecase data
                   (opticl:8-bit-gray-image :grey)
                   (opticl:8-bit-rgb-image :rgb)
                   (opticl:8-bit-rgba-image :rgba))))
    (opticl:with-image-bounds (h w) data
      (make-instance 'image
                     :data (prepare-png-data w h format data)
                     :width w
                     :height h
                     :pixel-format format))))


(defmethod foreign-array-of ((this image))
  (data-of this))


(defstruct (image-chunk
             (:constructor make-image-chunk (name width height pixel-format data)))
  (name nil :read-only t)
  (width nil :read-only t)
  (height nil :read-only t)
  (pixel-format nil :read-only t)
  (data nil :read-only t))


(defmethod read-chunk ((type (eql :image)) parameters stream)
  (destructuring-bind (&key size &allow-other-keys) parameters
    (let* ((image-data (make-array size :element-type '(unsigned-byte 8)))
           (bytes-read (read-sequence image-data stream)))
      (unless (= size bytes-read)
        (error "Incorrect :size provided for image chunk data: ~a supplied, but ~a read"
               size bytes-read))
      (parse-chunk type parameters image-data))))


(defmethod parse-chunk ((type (eql :image)) parameters data)
  (destructuring-bind (&key name width height type pixel-format &allow-other-keys) parameters
    (unless (eq type :raw)
      (error "Image type ~a unsupported" type))
    (unless (pixel-format-p pixel-format)
      (error "Unsupported pixel format: ~a" pixel-format))
    (make-image-chunk name width height pixel-format data)))
