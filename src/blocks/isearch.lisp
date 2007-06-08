
(in-package :weblocks)

(export '(render-isearch))

(defun render-isearch (input-name isearch-action &key value
		       (form-id (gensym))
		       (input-id (gensym))
		       (search-id (gensym))
		       (method :get) &allow-other-keys)
  "Renders an input bar with 'input-name' that calls back
'isearch-action' in delayed manner. This is useful for realtime
searching capabilities. Currently the delay is set to 0.4, similar to
the suggest block.

When JavaScript is turned off a button is drawn next to the input
box. The user may invoke 'isearch-action' by clicking the button.

value - an initial value.
method - form request method, defaults to GET."
  (let* ((a-input-name (attributize-name input-name)))
    (with-html
      (:form :id form-id :class "isearch" :action "" :method (attributize-name method)
	     (:fieldset
	      (:input :type "text" :id input-id :name a-input-name :class "search-bar" :value value)
	      (:input :id search-id :name *submit-control-name* :type "submit" :class "submit"
									       :value "Search")
	      (:input :name "action" :type "hidden" :value isearch-action)))
      (with-javascript "~
new Form.Element.DelayedObserver('~A', 0.4, function(elem, value) {~
initiateFormAction('~A', $('~A'), '~A');
});~
$('~A').remove();"
	input-id
	isearch-action form-id (session-name-string-pair)
	search-id))))
