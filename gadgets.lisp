;;; -*- Mode: Lisp; Package: CLIM-INTERNALS -*-

;;;  (c) copyright 2000 by 
;;; Arthur Lemmens (lemmens@simplex.nl),
;;; Iban Hatchondo (hatchond@emi.u-bordeaux.fr)
;;; and Julien Boninfante (boninfan@emi.u-bordeaux.fr)

;;; This library is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Library General Public
;;; License as published by the Free Software Foundation; either
;;; version 2 of the License, or (at your option) any later version.
;;;
;;; This library is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; Library General Public License for more details.
;;;
;;; You should have received a copy of the GNU Library General Public
;;; License along with this library; if not, write to the 
;;; Free Software Foundation, Inc., 59 Temple Place - Suite 330, 
;;; Boston, MA  02111-1307  USA.

(in-package :CLIM-INTERNALS)


;;;
;;; Gadget
;;;

(defclass gadget (immediate-sheet-input-mixin pane immediate-repaint-mixin)
  ((id :initarg :id
       :initform (gensym "GADGET")
       :accessor gadget-id)
   (client :initarg :client
           :initform *application-frame*
           :accessor gadget-client)
   (armed-callback :initarg :armed-callback
                   :initform nil
                   :reader gadget-armed-callback)
   (disarmed-callback :initarg :disarmed-callback
                      :initform nil
                      :reader gadget-disarmed-callback)
   (active-p;; [Arthur] I'm not so sure about the value for :initform.
    ;; Maybe T is better? Or maybe we should call
    ;; ACTIVATE-GADGET after creating a gadget?
    :initform t
    :reader gadget-active-p)
   (armed :initform nil)))

(defun gadgetp (object)
  (typep object 'gadget))

;;
;; gadget's colors
;;

(defclass gadget-color-mixin ()
  ((normal :type color
	   :initform +gray80+
	   :initarg :normal
	   :accessor gadget-normal-color)
   (highlighted :type color
		:initform +gray85+
		:initarg :highlighted
		:accessor gadget-highlighted-color)
   (pushed-and-highlighted :type color
			   :initform +gray75+
			   :initarg :pushed-and-highlighted
			   :accessor gadget-pushed-and-highlighted-color)
   (current-color :type color
		  :accessor gadget-current-color))
  (:documentation "This class define the gadgets colors."))

(defmethod initialize-instance :after ((gadget gadget-color-mixin) &rest args)
  (declare (ignore args))
  (setf (slot-value gadget 'current-color) (gadget-normal-color gadget)))

(defmethod display-gadget-background ((gadget gadget-color-mixin) x1 y1 x2 y2)
  (draw-rectangle* gadget x1 y1 x2 y2 :ink (gadget-current-color gadget) :filled t))

(defmethod (setf gadget-current-color) :after (color (gadget gadget-color-mixin))
  (declare (ignore color))
  (dispatch-repaint gadget (sheet-region gadget)))
  

;;;
;;; gadgets look
;;;

(defun draw-edges-lines* (pane x1 y1 x2 y2)
  (draw-line* pane x1 y1 x2 y1 :ink +white+)
  (draw-line* pane x1 y1 x1 y2 :ink +white+)
  (draw-line* pane x1 y2 x2 y2 :ink +black+)
  (draw-line* pane x2 y1 x2 y2 :ink +black+))


;;
;; gadget sub-classes
;;

(defclass basic-gadget (gadget gadget-color-mixin sheet-parent-mixin sheet-leaf-mixin mirrored-sheet)
  ;; Half-baked attempt to be compatible with Lispworks.
  ())

(defclass standard-gadget (basic-gadget)
  ())

(defgeneric armed-callback (gadget client gadget-id))
(defgeneric disarmed-callback (gadget client gadget-id))

;; "The default methods (on standard-gadget) call the function stored
;; in gadget-armed-callback or gadget-disarmed-callback with one argument,
;; the gadget."

(defmethod armed-callback ((gadget standard-gadget) client gadget-id)
  (declare (ignore client gadget-id))
  (let ((callback (gadget-armed-callback gadget)))
    (when callback
      (funcall callback gadget))))

(defmethod disarmed-callback ((gadget standard-gadget) client gadget-id)
  (declare (ignore client gadget-id))
  (let ((callback (gadget-disarmed-callback gadget)))
    (when callback
      (funcall callback gadget))))


;; Client warning

; Warning the gadget's client is useful (and made) when a changement has come
(defgeneric warn-client (gadget client))

; Default methods does nothing
; Now, the default client of a gadget is its application-frame (here *application-frame*)
(defmethod warn-client (gadget (frame application-frame))
  (declare (ignorable gadget frame))
  (values))

(defmethod warn-client (gadget (sheet sheet))
  (declare (ignorable gadget sheet))
  (values))

; The moment to warn the client
; [Julien] I'm not sure about this moment, but it works well...
(defmethod handle-event :after ((gadget standard-gadget) (event pointer-button-press-event))
  (when (gadget-client gadget)
    (warn-client gadget (gadget-client gadget))))


;;;
;;; Activation
;;;

(defgeneric activate-gadget (gadget))
(defgeneric deactivate-gadget (gadget))
(defgeneric note-gadget-activated (client gadget))
(defgeneric note-gadget-deactivated (client gadget))

(defmethod activate-gadget ((gadget gadget))
  (with-slots (active-p) gadget
    (unless active-p
      (setf active-p t)
      (note-gadget-activated (gadget-client gadget) gadget))))

(defmethod deactivate-gadget ((gadget gadget))
  (with-slots (active-p) gadget
    (when active-p
      (setf active-p nil)
      (note-gadget-deactivated (gadget-client gadget) gadget))))

(defmethod note-gadget-activated (client (gadget gadget))
  (declare (ignore client))
  ;; Default: do nothing  
  )

(defmethod note-gadget-deactivated (client (gadget gadget))
  (declare (ignore client))
  ;; Default: do nothing
  )

;;;
;;; Value-gadget
;;;

(defclass value-gadget (standard-gadget)
  ((value :initarg :value
          :reader gadget-value)
   (value-changed-callback :initarg :value-changed-callback
                           :initform nil
                           :reader gadget-value-changed-callback)))

(defgeneric (setf gadget-value) (value gadget &key invoke-callback))

(defmethod (setf gadget-value) 
  (value (gadget value-gadget) &key invoke-callback)
  (setf (slot-value gadget 'value) value)
  (when invoke-callback
    (value-changed-callback gadget 
                            (gadget-client gadget) 
                            (gadget-id gadget)
                            value)))

(defgeneric value-changed-callback (value-gadget client gadget-id value))

(defmethod value-changed-callback ((gadget value-gadget) client gadget-id value)
  (declare (ignore client gadget-id))
  (let ((callback (gadget-value-changed-callback gadget)))
    (when callback
      (funcall callback gadget value))))

  
;;;
;;; Action-gadget
;;;

(defclass action-gadget (standard-gadget)
  ((activate-callback :initarg :activate-callback
                      :initform nil
                      :reader gadget-activate-callback)))

(defgeneric activate-callback (action-gadget client gadget-id))

(defmethod activate-callback ((gadget action-gadget) client gadget-id)
  (declare (ignore client gadget-id))
  (let ((callback (gadget-activate-callback gadget)))
    (when callback
      (funcall callback gadget))))

;;;
;;; Oriented-gadget, labelled-gadget, range-gadget
;;;

(defclass oriented-gadget ()
  ((orientation :initarg :orientation
                :reader gadget-orientation)))

(defclass oriented-gadget-mixin (oriented-gadget)
  ;; Try to be compatible with Lispworks' CLIM.
  ())

(defclass labelled-gadget ()
  ((label :initarg :label
	  :initform "No label"
          :accessor gadget-label)
   (align-x :initarg :align-x
            :accessor gadget-label-align-x)
   (align-y :initarg :align-y
            :accessor gadget-label-align-y)
   (label-text-style :initform nil
		     :initarg :label-text-style
                     :accessor gadget-label-text-style)))

(defmethod compose-space ((pane labelled-gadget))
  (with-sheet-medium (medium pane)
    (multiple-value-bind (width height)
	(text-size medium (gadget-label pane)
		   :text-style (gadget-label-text-style pane))
      ;; FIXME remove explicit values
      ;; instead use spacer pane in derived classes
      (let ((tw (* 1.3 width))
	    (th (* 2.5 height)))
	(make-space-requirement :width tw :height th
				:max-width 400 :max-height 400
				:min-width tw :min-height th)))))

(defclass labelled-gadget-mixin (labelled-gadget)
  ;; Try to be compatible with Lispworks' CLIM.
  ())

;; LATER: Implement the following: "Changing the label of a gadget
;; may result in invoking the layout protocol on the gadget and its
;; ancestor sheets." (And similarly for changing the alignment or
;; the label text style of a gadget.)

(defclass range-gadget ()
  ((min-value :initarg :min-value
              :accessor gadget-min-value)
   (max-value :initarg :max-value
              :accessor gadget-max-value)))

(defclass range-gadget-mixin (range-gadget)
  ;; Try to be compatible with Lispworks' CLIM.
  ())

;; GADGET-RANGE and GADGET-RANGE* are from Lispworks' CLIM 2.0 User Guide. 
;; They're not defined in the spec.

(defgeneric gadget-range (range-gadget)
  (:documentation
   "Returns the difference of the maximum and minimum value of RANGE-GADGET."))

(defmethod gadget-range ((gadget range-gadget))
  (- (gadget-max-value gadget)
     (gadget-min-value gadget)))

(defgeneric gadget-range* (range-gadget)
  (:documentation 
   "Returns the minimum and maximum value of RANGE-GADGET as two values."))

(defmethod gadget-range* ((gadget range-gadget))
  (values (gadget-min-value gadget)
          (gadget-max-value gadget)))


;;
;; PUSH-BUTTON gadget
;;

(defclass push-button (labelled-gadget-mixin action-gadget) ())
  
(defclass push-button-pane  (push-button)
  ((show-as-default-p :type (member '(t nil))
		      :initform nil
		      :initarg :show-as-default-p
		      :accessor push-button-show-as-default-p)))

(defmethod handle-event ((pane push-button-pane) (event pointer-enter-event))
  (with-slots (armed) pane
    (unless armed
      (setf armed t
	    (gadget-current-color pane) (gadget-highlighted-color pane))
      (armed-callback pane (gadget-client pane) (gadget-id pane)))))

(defmethod handle-event ((pane push-button-pane) (event pointer-exit-event))
  (with-slots (armed) pane
    (when armed
      (setf (push-button-show-as-default-p pane) nil
	    armed nil
	    (gadget-current-color pane) (gadget-normal-color pane))
      (disarmed-callback pane (gadget-client pane) (gadget-id pane)))))

(defmethod handle-event ((pane push-button-pane) (event pointer-button-press-event))
  (with-slots (armed) pane
    (unless armed
      (armed-callback pane (gadget-client pane) (gadget-id pane)))
    (setf armed ':button-press
	  (push-button-show-as-default-p pane) t
	  (gadget-current-color pane) (gadget-pushed-and-highlighted-color pane))))    

(defmethod handle-event ((pane push-button-pane) (event pointer-button-release-event))
  (with-slots (armed) pane
    (when (eql armed ':button-press)
      (activate-callback pane (gadget-client pane) (gadget-id pane))
      (setf armed t
	    (push-button-show-as-default-p pane) nil
	    (gadget-current-color pane) (gadget-highlighted-color pane))
      (disarmed-callback pane (gadget-client pane) (gadget-id pane)))))

(defmethod handle-event ((pane push-button-pane) (event window-repaint-event))
  (dispatch-repaint pane (sheet-region pane)))

(defmethod repaint-sheet ((pane push-button-pane) region)
  (declare (ignore region))
  (multiple-value-bind (x1 y1 x2 y2) (bounding-rectangle* (sheet-region pane))
    (let ((w (- x2 x1))
	  (h (- y2 y1)))
      (display-gadget-background pane 1 1 (1- w) (1- h))
      (if (push-button-show-as-default-p pane)
	  (draw-edges-lines* pane (1- w) (1- h) 1 1)
	  (draw-edges-lines* pane 1 1 (1- w) (1- h)))
      (draw-text* pane (gadget-label pane) (round w 2) (round h 2)
		  :align-x :center :align-y :center))))

;;
;; TOGGLE-BUTTON gadget
;;

(defclass toggle-button (labelled-gadget-mixin value-gadget) ()
  (:documentation "The value is either t either nil"))

(defclass toggle-button-pane (toggle-button)
  ((indicator-type :type (member '(:one-of :some-of))
		   :initarg :indicator-type
		   :reader toggle-button-indicator-type)))
; We don't have implemented the difference of appearence whether the 
; indicator-type is :one-of or :some-of

(defmethod handle-event ((pane toggle-button-pane) (event pointer-enter-event))
  (with-slots (armed) pane
    (unless armed
      (setf armed t)
      (unless (gadget-value pane)
	(setf (gadget-current-color pane) (gadget-highlighted-color pane))
	(dispatch-repaint pane (sheet-region pane)))
      (armed-callback pane (gadget-client pane) (gadget-id pane)))))

(defmethod handle-event ((pane toggle-button-pane) (event pointer-exit-event))
  (with-slots (armed) pane
    (when armed
      (setf armed nil)
      (if (gadget-value pane)
	  (setf (gadget-current-color pane) (gadget-pushed-and-highlighted-color pane))
	  (setf (gadget-current-color pane) (gadget-normal-color pane)))
      (disarmed-callback pane (gadget-client pane) (gadget-id pane)))))

(defmethod handle-event ((pane toggle-button-pane) (event pointer-button-press-event))
  (with-slots (armed) pane
    (unless armed
      (armed-callback pane (gadget-client pane) (gadget-id pane)))
    (setf armed ':button-press
	  (gadget-current-color pane) (gadget-pushed-and-highlighted-color pane))))
      
(defmethod handle-event ((pane toggle-button-pane) (event pointer-button-release-event))
  (with-slots (armed) pane
    (when (eql armed ':button-press)
      (setf armed t
	    (gadget-value pane :invoke-callback t) (not (gadget-value pane)))
      (unless (gadget-value pane)
	(setf (gadget-current-color pane) (gadget-highlighted-color pane)))
      (disarmed-callback pane (gadget-client pane) (gadget-id pane)))))

(defmethod handle-event ((pane toggle-button-pane) (event window-repaint-event))
  (dispatch-repaint pane (sheet-region pane)))

(defmethod repaint-sheet ((pane toggle-button-pane) region)
  (declare (ignore region))
  (let ((text (gadget-label pane))
	(region (sheet-region pane))
	(armed (slot-value pane 'armed)))
    (multiple-value-bind (x1 y1 x2 y2) (bounding-rectangle* region)
      (setf x2 (- x2 x1 1)
	    x1 1
	    y2 (- y2 y1 1)
	    y1 1)
      (display-gadget-background pane x1 y1 x2 y2)
      (if (or (gadget-value pane) (eql armed ':button-press))
	  (draw-edges-lines* pane x2 y2 x1 y1)
	  (draw-edges-lines* pane x1 y1 x2 y2))
      (draw-text* pane text
		     (round (- x2 x1) 2)
		     (round (- y2 y1) 2)
		     :align-x :center
		     :align-y :center))))


;;
;; MENU-BUTTON gadget
;;

(defclass menu-button (labelled-gadget-mixin value-gadget)
  ()
  (:documentation "The value is a button"))

(defclass menu-button-pane (menu-button) ())

(defmethod repaint-sheet ((pane menu-button-pane) region)
  (declare (ignore region))
  (let ((text (gadget-label pane))
	(region (sheet-region pane)))
    (multiple-value-bind (x1 y1 x2 y2) (bounding-rectangle* region)
      (let ((w (- x2 x1))
	    (h (- y2 y1)))
	(cond ((slot-value pane 'armed)
	       (draw-rectangle* pane 0 0 w h
				:ink (gadget-highlighted-color pane)
				:filled t)
	       (draw-edges-lines* pane (- w 2) (- h 2) 1 1))
	      (t
	       (draw-rectangle* pane 0 0 w h
				:ink (gadget-normal-color pane)
				:filled t)))
	(draw-text* pane text (round w 2) (round h 2)
		    :align-x :center
		    :align-y :center)))))

;;
;; SCROLL-BAR gadget
;;

(defgeneric drag-callback (pane client gadget-id value))
(defgeneric scroll-to-top-callback (scroll-bar client gadget-id))
(defgeneric scroll-to-bottom-callback (scroll-bar client gadget-id))
(defgeneric scroll-up-line-callback (scroll-bar client gadget-id))
(defgeneric scroll-up-page-callback (scroll-bar client gadget-id))
(defgeneric scroll-down-line-callback (scroll-bar client gadget-id))
(defgeneric scroll-down-page-callback (scroll-bar client gadget-id))

(defclass scroll-bar (value-gadget oriented-gadget-mixin range-gadget-mixin)
  ((drag-callback :initarg :drag-callback
		  :initform nil
		  :reader scroll-bar-drag-callback)
   (scroll-to-bottom-callback :initarg :scroll-to-bottom-callback
			      :initform nil
			      :reader scroll-bar-scroll-to-bottom-callback)
   (scroll-to-top-callback :initarg :scroll-to-top-callback
			   :initform nil
			   :reader scroll-bar-scroll-to-top-callback)
   (drag-down-line-callback :initarg :drag-down-line-callback
			    :initform nil
			    :reader scroll-bar-drag-down-line-callback)
   (drag-up-line-callback :initarg :drag-up-line-callback
			  :initform nil
			  :reader scroll-bar-drag-up-line-callback)
   (drag-down-page-callback :initarg :drag-down-page-callback
			    :initform nil
			    :reader scroll-bar-drag-down-page-callback)
   (drag-up-page-callback :initarg :drag-up-page-callback
			  :initform nil
			  :reader scroll-bar-drag-up-page-callback)))

(defmethod drag-callback ((pane scroll-bar) client gadget-id value)
  (declare (ignore client gadget-id))
  (funcall (scroll-bar-drag-callback pane) pane value))

(defmethod drag-callback :after ((pane scroll-bar) client gadget-id value)
  (declare (ignore client gadget-id))
  (setf (gadget-value pane :invoke-callback t) value))

(defmacro invoke-callbacks (pane callback)
  (let ((call (gensym)))
    `(let ((,call (symbol-function ,callback)))
       (when ,call
	 (funcall ,call ,pane)))))

(defmethod scroll-to-top-callback ((pane scroll-bar) client gadget-id)
  (declare (ignore client gadget-id))
  (invoke-callbacks pane 'scroll-bar-scroll-to-top-callback))

(defmethod scroll-to-bottom-callback ((pane scroll-bar) client gadget-id)
  (declare (ignore client gadget-id))
  (invoke-callbacks pane 'scroll-bar-scroll-to-bottom-callback))

(defmethod scroll-up-line-callback ((pane scroll-bar) client gadget-id)
  (declare (ignore client gadget-id))
  (invoke-callbacks pane 'scroll-bar-drag-up-line-callback))

(defmethod scroll-up-page-callback ((pane scroll-bar) client gadget-id)
  (declare (ignore client gadget-id))
  (invoke-callbacks pane 'scroll-bar-drag-up-page-callback))

(defmethod scroll-down-line-callback ((pane scroll-bar) client gadget-id)
  (declare (ignore client gadget-id))
  (invoke-callbacks pane 'scroll-bar-drag-down-line-callback))

(defmethod scroll-down-page-callback ((pane scroll-bar) client gadget-id)
  (declare (ignore client gadget-id))
  (invoke-callbacks pane 'scroll-bar-drag-down-page-callback))

;; SCROLL-BAR-PANE

(defclass scroll-bar-pane (basic-pane scroll-bar)
  ((orientation :initform :vertical
		:initarg :orientation
		:reader scrollbar-orientation)
   ;;; the offset and length are percentages of the scrollbar's length
   (offset :initform 0
	   :type (real 0 1)
	   :accessor scrollbar-offset)
   (length :initform 1
	   :type (real 0 1)
	   :accessor scrollbar-length)))

(defmethod compose-space ((sb scroll-bar-pane))
  (if (eq (scrollbar-orientation sb) :vertical)
      (make-space-requirement :min-width 1
			      :width *scrollbar-thickness*
			      :min-height (min 10 *scrollbar-thickness*)
			      :height (* 2 *scrollbar-thickness*))
    (make-space-requirement :min-height 1
			    :height *scrollbar-thickness*
			    :min-width (min 10 *scrollbar-thickness*)
			    :width (* 2 *scrollbar-thickness*))))

(defmethod allocate-space ((sb scroll-bar-pane) width height)
  (set-width-and-height sb width height))

(defmethod repaint-sheet ((sb scroll-bar-pane) region)
  (declare (ignore region))
  (window-refresh sb))

(defmethod window-refresh ((sb scroll-bar-pane))
  (with-bounding-rectangle* (minx miny maxx maxy) (sheet-region sb)
    (draw-rectangle* sb minx miny maxx maxy :filled t :ink (medium-background sb))
    (let ((width (- maxx minx))
	  (height (- maxy miny)))
      (if (eq (scrollbar-orientation sb) :vertical)
	  (draw-rectangle* sb
			   minx (+ miny (* height (scrollbar-offset sb)))
			   maxx (+ miny (* height (scrollbar-offset sb))
				   (* height (scrollbar-length sb)))
			   :filled t )
	(draw-rectangle* sb
			 (+ minx (* width (scrollbar-offset sb))) miny
			 (+ minx (* width (scrollbar-offset sb))
			    (* width (scrollbar-length sb))) maxy
			    :filled t :ink (medium-foreground sb))))))

(defmethod handle-event ((sb scroll-bar-pane) (event window-repaint-event))
  (repaint-sheet sb nil))

;;
;; SLIDER gadget
;;

(defclass slider-gadget (labelled-gadget-mixin
			 value-gadget
			 oriented-gadget-mixin
			 range-gadget-mixin
			 gadget-color-mixin)
  ()
  (:documentation "The value is a real number"))
  
(defclass slider-pane (slider-gadget)
  ((drag-callback :initform nil
		  :initarg :drag-callback
		  :reader slider-drag-callback)
   (show-value-p :type boolean
		 :initform nil
		 :initarg :show-value-p
		 :accessor gadget-show-value-p)))

(defmethod drag-callback ((pane slider-pane) client gadget-id value)
  (declare (ignore client gadget-id))
  (when (slider-drag-callback pane)
    (funcall (slider-drag-callback pane) pane value)))

(defmethod handle-event ((pane slider-pane) (event pointer-enter-event))
  (with-slots (armed) pane
    (unless armed
      (setf armed t
	    (gadget-current-color pane) (gadget-highlighted-color pane))
      (armed-callback pane (gadget-client pane) (gadget-id pane)))))

(defmethod handle-event ((pane slider-pane) (event pointer-exit-event))
  (with-slots (armed) pane
    (when armed
      (setf armed nil
	    (gadget-current-color pane) (gadget-normal-color pane))
      (when (gadget-show-value-p pane)
	(setf (gadget-show-value-p pane) nil)))
    (disarmed-callback pane (gadget-client pane) (gadget-id pane))))


(defmethod handle-event ((pane slider-pane) (event pointer-button-press-event))
  (with-slots (armed) pane
     (when armed
       (setf armed ':button-press)
       (when (gadget-show-value-p pane)
	 (setf (gadget-show-value-p pane) nil)))))
       

(defmethod handle-event ((pane slider-pane) (event pointer-motion-event))
  (with-slots (armed) pane
    (when (eq armed ':button-press)
      (let ((value (convert-position-to-value pane (pointer-event-y event))))
	(setf (gadget-value pane :invoke-callback nil) value)
	(drag-callback pane (gadget-client pane) (gadget-id pane) value)
	(dispatch-repaint pane (sheet-region pane))))))

(defmethod handle-event ((pane slider-pane) (event pointer-button-release-event))
  (with-slots (armed) pane
    (when armed
      (setf armed t
	    (gadget-show-value-p pane) t
	    (gadget-value pane :invoke-callback t) (convert-position-to-value pane (pointer-event-y event)))
      (dispatch-repaint pane (sheet-region pane)))))

(defmethod handle-event ((pane slider-pane) (event window-repaint-event))
  (dispatch-repaint pane (sheet-region pane)))

(defmethod convert-position-to-value ((pane slider-pane) y)
  (multiple-value-bind (x1 y1 x2 y2) (bounding-rectangle* (sheet-region pane))
    (declare (ignore x1 x2))
    (round (+ (gadget-min-value pane) (/ (* (gadget-range pane) (- y2 y)) (- y2 y1))))))

(defmethod repaint-sheet ((pane slider-pane) region)
  (declare (ignore region))
  (let ((region (sheet-region pane))
	(position (convert-value-to-position pane)))
    (multiple-value-bind (x1 y1 x2 y2) (bounding-rectangle* region)
      (let ((middle-x (round (- x2 x1) 2)))
	(display-gadget-background pane 0 0 (- x2 x1) (- y2 y1))
	(draw-line* pane middle-x y1 middle-x y2 :ink +black+)
	(draw-rectangle* pane (- middle-x 15) (- position 5)
		       (+ middle-x 15) (+ position 5)
		       :ink +grey75+ :filled t)
	(draw-edges-lines* pane (- middle-x 15) (- position 5) (+ middle-x 15) (+ position 5))
	(when (gadget-show-value-p pane)
	  (draw-text* pane (princ-to-string (gadget-value pane))
		      (+ middle-x 20) position))))))

(defmethod convert-value-to-position ((pane slider-pane))
  (multiple-value-bind (x1 y1 x2 y2) (bounding-rectangle* (sheet-region pane))
    (declare (ignore x1 x2))
    (- y2 (/ (* (- (gadget-value pane) (gadget-min-value pane)) (- y2 y1)) (gadget-range pane)))))


;;
;; RADIO-BOX gadget
;;

(defclass radio-box (value-gadget oriented-gadget-mixin) ()
  (:documentation "The value is a button"))
  
(defclass radio-box-pane (radio-box)
  ((current-selection :type 'toggle-button
		      :initarg :current-selection
		      :accessor radio-box-current-selection)))

(defmethod (setf radio-box-current-selection) :before (button (pane radio-box-pane))
  (declare (ignore button))
  (let ((old-button (radio-box-current-selection pane)))
    (setf (gadget-value old-button :invoke-callback t) nil)
    (dispatch-repaint old-button (sheet-region old-button))))

(defmethod warn-client ((gadget toggle-button-pane) (client radio-box-pane))
  (setf (radio-box-current-selection client) gadget))

(defun find-current (&rest l)
    (let (current)
      (loop for element in l
	    do (when (equal (first element) 'radio-box-current-selection)
		 (return (setf current element))))
      (or current (first l))))

(defmacro with-radio-box ((&rest options) &body body)
  (let* ((current (apply #'find-current body))
	 (other-body (remove current body)))
    (when (eql (first current) 'radio-box-current-selection)
      (setf current (second current))) ; first case of the or in find-current
    `(let* ((current-button ,current)
	    (radio-box (make-pane-1 (slot-value *application-frame* 'manager)
				    *application-frame*
				    'radio-box-pane
				    ,@options
				    :current-selection current-button)))
       (mapcar #'(lambda (gadget) (setf (gadget-client gadget) radio-box))
	       (list ,@other-body))
       (mapcar #'(lambda (gadget) (setf (gadget-value gadget :invoke-callback t) nil))
	       (list ,@other-body))
       (setf (gadget-client current-button) radio-box
	     (gadget-value current-button :invoke-callback t) t)
       radio-box)))


;;
;; TEXT-FIELD gadget
;;

(defclass text-field (value-gadget action-gadget) ()
  (:documentation "The value is a string"))

(defclass text-field-pane (text-field) ())

(defmethod handle-event ((pane text-field-pane) (event window-repaint-event))
  (dispatch-repaint pane (sheet-region pane)))

(defmethod repaint-sheet ((pane text-field-pane) region)
  (declare (ignore region))
  (multiple-value-bind (x1 y1 x2 y2) (bounding-rectangle* (sheet-region pane))
    (draw-text* pane (gadget-value pane)
		(round (- x2 x1))
		(round (- y2 y1) 2)
		:align-x :right
		:align-y :center)))

(defmethod (setf gadget-value) :after (value (pane text-field-pane) &key invoke-callback)
  (declare (ignore value invoke-callback))
  (window-clear pane)
  (dispatch-repaint pane (sheet-region pane)))

(defmethod compose-space ((pane text-field-pane))
  (with-sheet-medium (medium pane)
    (multiple-value-bind (width height)
	(text-size medium (gadget-value pane))
      (make-space-requirement :width width :height height
			      :max-width width :max-height height
			      :min-width width :min-height height))))

;;
;; TEXT-EDITOR gadget
;;

(defclass text-editor (text-field) ()
  (:documentation "The value is a string"))

(defclass text-editor-pane (text-editor)
  ((width :type integer
	  :initarg :width
	  :reader text-editor-width)
   (height :type integer
	   :initarg :height
	   :reader text-editor-height)))

(defmethod compose-space ((pane text-editor-pane))
  (make-space-requirement :width 300 :max-width 300 :min-width 300
			  :height 300 :max-height 300 :min-height 300))


;;
;; GADGET-OUTPUT-RECORD
;;

(defclass gadget-output-record (output-record) ())

(defmacro with-output-as-gadget (stream &body body)
  (let ((gadget (gensym))
	(gadget-output-record (gensym)))
    `(let* ((,gadget (progn ,@body))
	    (,gadget-output-record (make-instance 'gadget-output-record 
				    :children (list ,gadget))))
       (stream-add-output-record ,stream ,gadget-output-record)
       ,gadget)))




