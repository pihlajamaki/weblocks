;;; Code shared accross the entire weblocks framework

(defmacro without-package-variance-warnings (&body body)
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     (handler-bind (#+sbcl(sb-int:package-at-variance #'muffle-warning))
       ,@body)))

(without-package-variance-warnings
  (defpackage #:weblocks
    (:use :cl :c2mop :metabang.utilities :hunchentoot :cl-who :json :fare-matcher :cont :parenscript
          :anaphora :f-underscore)
    (:shadowing-import-from :c2mop #:defclass #:defgeneric #:defmethod
                            #:standard-generic-function #:ensure-generic-function
                            #:standard-class #:typep #:subtypep)
    (:shadowing-import-from :f-underscore #:f #:_)
    (:shadowing-import-from :fare-matcher #:match)
    (:shadow #:redirect #:errors)
    (:documentation
      "Weblocks is a Common Lisp framework that eases the pain of web
      application development. It achieves its goals by standardizing on
      various libraries, providing flexible and extensible generic views,
      and exposing a unique widget-based approach to maintaining UI
      state."))

  ;; the following are export-only; see `wexport'

  (defpackage #:weblocks-cont
    (:documentation "Operators for continuation-based web development
    with Weblocks."))

  (defpackage #:weblocks-util
    (:documentation "General Lisp utilities traditionally exported
    with Weblocks.")))

(in-package :weblocks)

; re-export external symbols from cl-cont
(do-external-symbols (s (find-package :cont))
  (export (list s)))

(export '(*weblocks-output-stream* with-html with-html-to-string
          reset-sessions str with-javascript with-javascript-to-string root-widget))

(defun wexport (symbols-designator &optional (package-specs t))
  "Export SYMBOLS-DESIGNATOR from PACKAGE-SPECS.  Over `export',
PACKAGE-SPECS can be a list of packages, and the name designators
therein are interpreted by prepending \"WEBLOCKS-\".  In the latter
case, the symbols will be imported first if need be."
  (dolist (pkg (ensure-list package-specs))
    (multiple-value-bind (pkg import-first?)
	(typecase pkg
	  (boolean '#:weblocks)
	  (symbol (values (concatenate 'string (symbol-name '#:weblocks-)
				       (symbol-name pkg))
			  t))
	  (string (values (concatenate 'string (symbol-name '#:weblocks-) pkg)
			  t))
	  (otherwise pkg))
      (when import-first?
	(import symbols-designator pkg))
      (export symbols-designator pkg))))

(defparameter *weblocks-output-stream* nil
  "Output stream for Weblocks framework created for each request
and available to code executed within a request as a special
variable. All html should be rendered to this stream.")

(defparameter *dirty-widgets* nil
  "Contains a list of dirty widgets at the current point in rendering
  cycle. This is a special variable modified by the actions that
  change state of widgets.")

(defvar *autostarting-webapps* nil
  "A list of webapps to start when start-weblocks is called")

(defvar *active-webapps* nil
  "A list of running applications.  Applications are only available
   after they have been started.")

(defun cl-escape-string (maybe-string)
  "Force quoting of special characters by cl-who for with-html."
  ;(format t "cl-escape-string: ~s~%" (describe maybe-string))
  (cond
    ((stringp maybe-string)
     (cl-who:escape-string-minimal-plus-quotes maybe-string))
    (t maybe-string)))

(defmethod convert-tag-to-string-list (tag (attr-list list) body body-fn)
  "The method convert-tag-to-string-list is a hook into cl-who's
  output system; here we use it to automatically escape special
  characters."
  ;(format *standard-output* "non-cl-who tag: ~s, attr-list ~s.~%" tag attr-list)
  (call-next-method
    tag
    (loop for inner-attr-list in attr-list
        collect
        (progn
          (cons
            (car inner-attr-list)
            (cons 'cl-escape-string (list (cdr inner-attr-list))))))
    body
    body-fn))

(defmacro with-html (&body body)
  "A wrapper around cl-who with-html-output macro."
  `(with-html-output (*weblocks-output-stream* nil)
     ,@body))

(defmacro with-html-to-string (&body body)
  "A wrapper around cl-who with-html-output-to-string macro."
  `(with-html-output-to-string (*weblocks-output-stream* nil)
     ,@body))

(defun escape-script-tags (source &key (delimiter ps:*js-string-delimiter*))
  "Escape script blocks inside scripts."
  (ppcre:regex-replace-all
    (ppcre:quote-meta-chars "</script>")
    (ppcre:regex-replace-all (ppcre:quote-meta-chars "]]>")
                             source
                             (format nil "]]~A + ~:*~A>" delimiter))
    (format nil "</scr~A + ~:*~Aipt>" delimiter)))

(defun %js (source &rest args)
  "Helper function for WITH-JAVASCRIPT macros."
  `(:script :type "text/javascript"
            (fmt "~%// <![CDATA[~%")
            (str (escape-script-tags (format nil ,source ,@args)))
            (fmt "~%// ]]>~%")))

(defmacro with-javascript (source &rest args)
  "Places 'source' between script and CDATA elements. Used to avoid
having to worry about special characters in JavaScript code."
  `(with-html ,(apply #'%js source args)))

(defmacro with-javascript-to-string (source &rest args)
  "Places 'source' between script and CDATA elements. Used to avoid
having to worry about special characters in JavaScript code."
  `(with-html-to-string ,(apply #'%js source args)))

(defmacro root-widget ()
  "Expands to code that can be used as a place to access to the root
composite."
  `(webapp-session-value 'root-widget))

;;; This turns off a regex optimization that eats A LOT of memory
(setq cl-ppcre:*use-bmh-matchers* nil)