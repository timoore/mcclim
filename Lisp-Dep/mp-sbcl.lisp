;;; -*- Mode: Lisp; Syntax: Common-Lisp; Package: CLIM-INTERNALS; -*-
;;; ---------------------------------------------------------------------------
;;;     Title: CLIM-2, Chapter 32.2 Multi-processing
;;;            for SBCL
;;;   Created: 2003-02-22
;;;    Author: Daniel Barlow <dan@metacircles.com>
;;;   Based on mp-acl, created 2001-05-22 by Gilbert Baumann
;;;   License: LGPL (See file COPYING for details).
;;; ---------------------------------------------------------------------------
;;;  (c) copyright 2001 by Gilbert Baumann
;;;  (c) copyright 2002 by John Wiseman (jjwiseman@yahoo.com)
;;;  (c) copyright 2003 by Daniel Barlow <dan@metacircles.com>

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

(defconstant *multiprocessing-p* t)

(eval-when (:load-toplevel :compile-toplevel :execute)
  (pushnew :clim-mp *features*))

(defstruct (process
	     (:constructor %make-process)
	     (:predicate processp))
  name
  state
  whostate
  function
  id)

(defvar *current-process*
  (%make-process :name "initial process" :function nil))

(defun make-process (function &key name)
  (let ((p (%make-process :name name
			  :function function)))
    (restart-process p)))

(defun restart-process (p)
  (labels ((boing ()
	     (let ((*current-process* p))
	       (funcall (process-function p) ))))
    (when (process-id p) (sb-thread:destroy-thread p))
    (when (setf (process-id p) (sb-thread:make-thread #'boing))
      p)))

(defun destroy-process (process)
  (sb-thread:destroy-thread (process-id process)))

(defun current-process ()
  *current-process*)

(defun all-processes ()
  *all-processes*)

;;; people should be shot for using these, honestly.  Use a queue!
(defun process-wait (reason predicate)
  (let ((old-state (process-whostate *current-process*)))
    (unwind-protect
	 (progn
	   (setf old-state (process-whostate *current-process*)
		 (process-whostate *current-process*) reason)
	   (loop 
	    (let ((it (funcall predicate)))
	      (when it (return it)))
	    (sleep .01)))
      (setf (process-whostate *current-process*) old-state))))

(defun process-wait-with-timeout (reason timeout predicate)
  (let ((old-state (process-whostate *current-process*))
	(end-time (+ (get-universal-time) timeout)))
    (unwind-protect
	 (progn
	   (setf old-state (process-whostate *current-process*)
		 (process-whostate *current-process*) reason)
	   (loop 
	    (let ((it (funcall predicate)))
	      (when (or (> (get-universal-time) end-time) it)
		(return it)))
	    (sleep .01)))
      (setf (process-whostate *current-process*) old-state))))

(defun process-interrupt (process function)
  (error "Sorry Dave, I'm afraid I can't do that"))

(defun disable-process (process)
  (sb-thread::suspend-thread (process-id process)))

(defun enable-process (process)
  (sb-thread::resume-thread (process-id process)))

(defun process-yield ()
  (sleep .1))

;;; FIXME but, of course, we can't.  Fix whoever wants to use it,
;;; instead
(defmacro without-scheduling (&body body)
  `(progn ,@body))

(defmacro atomic-incf (place)
  `(sb-thread::with-spinlock (xlib::*conditional-store-queue*)
    (incf ,place)))

(defmacro atomic-decf (place) 
  `(sb-thread::with-spinlock (xlib::*conditional-store-queue*)
    (decf ,place)))

;;; 32.3 Locks

(defun make-lock (&optional name)
  (sb-thread:make-mutex :name name))

(defmacro with-lock-held ((place &optional state) &body body)
  (let ((old-state (gensym "OLD-STATE")))
    `(let (,old-state)
      (unwind-protect
           (progn
             (sb-thread:get-mutex ,place)
	     (when ,state
	       (setf ,old-state (process-state *current-process*))
	       (setf (process-state *current-process*) ,state))
             ,@body)
        (setf (process-state *current-process*) ,old-state)
        (sb-thread::release-mutex ,place)))))


(defun make-recursive-lock (&optional name)
  (sb-thread:make-mutex :name name))

(defmacro with-recursive-lock-held ((place &optional state) &body body)
  (let ((old-state (gensym "OLD-STATE")))
  `(sb-thread:with-recursive-lock (,place)
    (let (,old-state)
      (unwind-protect
	   (progn
	     (when ,state
	       (setf ,old-state (process-state *current-process*))
	       (setf (process-state *current-process*) ,state))
	     ,@body)
	(setf (process-state *current-process*) ,old-state))))))