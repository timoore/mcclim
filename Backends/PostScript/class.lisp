;;; -*- Mode: Lisp; Package: CLIM-POSTSCRIPT -*-

;;;  (c) copyright 2001 by
;;;           Arnaud Rouanet (rouanet@emi.u-bordeaux.fr)
;;;           Lionel Salabartan (salabart@emi.u-bordeaux.fr)
;;;  (c) copyright 2002 by
;;;           Alexey Dejneka (adejneka@comail.ru)
;;;           Gilbert Baumann (unk6@rz.uni-karlsruhe.de)

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

;;; TODO:

;;; Also missing IMO:
;;;
;;; - WITH-OUTPUT-TO-POSTSCRIPT-STREAM should offer a :PAPER-SIZE option.
;;; - NEW-PAGE should also offer to specify the page name.
;;; - device fonts are missing
;;; - font metrics are missing
;;;
;;;--GB

(in-package :CLIM-POSTSCRIPT)

;;;; Medium

(defclass postscript-medium (basic-medium)
  ((file-stream :initarg :file-stream :reader postscript-medium-file-stream)
   (document-fonts :initform '())
   (graphics-state-stack :initform '())))

(defun make-postscript-medium (file-stream stream)
  (make-instance 'postscript-medium
                 :sheet stream
                 :file-stream file-stream))

(defmacro postscript-medium-graphics-state (medium)
  `(first (slot-value ,medium 'graphics-state-stack)))


;;;; Stream
(defvar *default-postscript-title* "")

(defvar *default-postscript-for*
  #+unix (or (get-environment-variable "USER")
             "Unknown")
  #-unix "")

(defclass postscript-stream (basic-sheet
                             sheet-leaf-mixin
                             sheet-mute-input-mixin
                             permanent-medium-sheet-output-mixin
                             sheet-mute-repainting-mixin
                             mirrored-sheet-mixin ; ?
                             standard-extended-output-stream
                             standard-output-recording-stream)
  ((file-stream :initarg :file-stream :reader postscript-stream-file-stream)
   (title :initarg :title)
   (for :initarg :for)
   (orientation :initarg :orientation)
   (paper :initarg :paper)
   (native-region :initarg :native-region
                  :reader sheet-native-region)
   (transformation :initarg :transformation
                   :reader sheet-native-transformation)
   (current-page :initform 0)))

(defun make-postscript-stream (file-stream device-type
                               multi-page scale-to-fit
                               orientation header-comments)
  (declare (ignore multi-page scale-to-fit))
  (unless device-type (setq device-type :a4))
  (let ((title (or (getf header-comments :title)
                   *default-postscript-title*))
        (for (or (getf header-comments :for)
                 *default-postscript-for*))
        (region (paper-region device-type orientation))
        (transform (make-postscript-transformation device-type orientation)))
    (make-instance 'postscript-stream
                   :file-stream file-stream
                   :title title :for for
                   :orientation orientation
                   :paper device-type
                   :native-region region
                   :transformation transform)))