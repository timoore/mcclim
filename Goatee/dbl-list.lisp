(in-package :goatee)

;;; Mostly implements dbl-list-head
(defclass dbl-super ()
  ((next :accessor next :initarg :next :initform nil)))

(defgeneric prev (dbl-list))

(defmethod prev ((dbl-list dbl-super))
  nil)

(defclass dbl-list (dbl-super)
  ((prev :accessor prev :initarg :prev :initform nil)))

(defgeneric dbl-insert-after (dbl-list new-element))

(defmethod dbl-insert-after ((new-element dbl-list) (dbl-list dbl-super))
  (setf (prev new-element) dbl-list)
  (setf (next new-element) (next dbl-list))
  (when (next dbl-list)
    (setf (prev (next dbl-list)) new-element))
  (setf (next dbl-list) new-element)
  new-element)

(defgeneric dbl-insert-before (dbl-list new-element))

(defmethod dbl-insert-before ((new-element dbl-list) (dbl-list dbl-list))
  (setf (next new-element) dbl-list)
  (setf (prev new-element) (prev dbl-list))
  (when (prev dbl-list)
    (setf (next (prev dbl-list)) new-element))
  (setf (prev dbl-list) new-element)
  new-element)

(defgeneric dbl-remove (element))

(defmethod dbl-remove ((element dbl-list))
  (when (prev element)
    (setf (next (prev element)) (next element)))
  (when (next element)
    (setf (prev (next element)) (prev element)))
  nil)

(defclass dbl-list-head (dbl-super)
  ())

(defmethod dbl-head ((dbl-list dbl-list-head))
  (next dbl-list))

(defmethod (setf dbl-head) (val (dbl-list dbl-list-head))
  (setf (next dbl-list) val))

(defclass dbl-list-cell (dbl-list)
  ((contents :accessor contents :initarg :contents :initform nil)))


(defun make-dbl-list ()
  (make-instance 'dbl-list-head))

(defun insert-obj-before (obj dbl-list)
  (let ((cell (make-instance 'dbl-list-cell :contents obj)))
    (dbl-insert-after cell dbl-list)))

(defun insert-obj-after (obj dbl-list)
  (let ((cell (make-instance 'dbl-list-cell :contents obj)))
    (dbl-insert-after cell dbl-list)))

(defun dbl-list-elements (dbl-list)
  (loop for dbl = (dbl-head dbl-list) then (next dbl)
	while dbl
	collect (contents dbl)))