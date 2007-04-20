
(in-package :weblocks)

(export '(make-action render-link handle-client-request))

(defparameter *action-string* "action"
  "A string used to pass actions from a client to the server. See
  'get-request-action'.")

(defun make-action (action-fn &optional (action-code (gensym)))
  "Coverts a function into an action that can be rendered into
HTML. A unique string is generated for the function, and a
function is added to the session hashtable under this string. The
string is then returned. When later requests come in,
'get-request-action' machinery determines if the action string
that came with the request is stored in the hashtable, and if so,
invokes the stored function.

'action-fn' - A function of zero arguments that will be called if
the user initiates appropriate control (link, form, etc.)

'action-code' - The code to use for an action (if not specified
make-action generates a unique value for each action)"
  (setf (session-value action-code) action-fn)
  action-code)

(defun render-link (action-code name)
  "Renders an action into an href link. When the user clicks on
the link, the action will be called on the server.

'action-code' - The action created with 'make-action'.
'name' - A string that will be presented to the user in the
link."
  (let ((url (concatenate 'string "?" *action-string* "=" (princ-to-string action-code))))
    (with-html
      (:a :href url (str name)))))

(defun get-request-action ()
  "Gets an action from the request. If the request contains
*action-string* parameter, the action is looked up in the
session. And appropriate function is returned. If no action is in
the parameter, returns nil. If the action isn't in the
session (somehow invalid), raises an assertion."
  (let ((action-name (request-parameter *action-string*))
	request-action)
    (when action-name
      (setf request-action (session-value action-name))
      (assert request-action (request-action)
	      (concatenate 'string "Cannot find action: " action-name))
      request-action)))

(defgeneric handle-client-request ()
  (:documentation
   "This method handles each request as it comes in from the
   server. It is a hunchentoot handler and has access to all
   hunchentoot dynamic variables. The default implementation
   executes a user action (if any), and renders the main
   composite. It also invokes user supplied 'init-user-session'
   on the first request that has no session setup.  Override this
   method (along with :before and :after specifiers to customize
   behavior)."))

(defmethod handle-client-request ()
  "Handles requests coming in from the client. If this is the
first request from a client (a session isn't set up yet),
'init-user-session' is called. Verifies if a user invoked an
action and calls it. Then proceeds to render the controls."
  (when (null (session-value 'root-composite))
    (let ((root-composite (make-instance 'composite)))
      (funcall (symbol-function (find-symbol "INIT-USER-SESSION" (symbol-package *webapp-name*)))
	       root-composite)
      (setf (session-value 'root-composite) root-composite)))

  (let ((action-fn (get-request-action))
	(*weblocks-output-stream* (make-string-output-stream)))
    (declare (special *weblocks-output-stream*))
    (safe-funcall action-fn)
    (with-page (curry #'render (session-value 'root-composite)))
    (get-output-stream-string *weblocks-output-stream*)))

