(in-package :octopus)

(defparameter *server* (make-instance 'server))

(defun undefined-command (payload uid) "undef")

(defun login (user-data uid)
  (apply #'response-with
	 (cond
	   ((ensure-user-not-logged-in user-data)
	    (log-as info "user ~A already exists" (username-of user-data))
	    '(:message-type :error :error-type user-already-logged-in))
	   ((not (ensure-user-exists-in-database user-data))
	    (log-as info "no such user ~A" (username-of user-data))
	    '(:message-type :error :error-type no-such-user))
	   (t (let ((new-uid (funcall *new-uid*)))
		(add-user *server* new-uid
			  (make-instance 'user-v
					 :username (username-of user-data)
					 :uid new-uid))
		`(:message-type :ok :payload ,new-uid))))))

(defun ensure-user-not-logged-in (user-data)
  (get-user *server*
		 (username-of user-data)
		 :users-by 'users-by-username-of))

(defun ensure-user-exists-in-database (user-data)
  (get-user-from-database user-data))

(defun get-user-from-database (user-data)
  (with-transaction
    (select-instance (u user)
      (where (and
	      (string= (username-of u)
		       (username-of user-data))
	      (string= (password-hash-of u)
		       (password-hash-of user-data)))))))

(defun list-channels (payload uid) "list")

(defun create-channel (channel-data uid) "create")

(defun logout (payload uid)
  (if (rm-user *server* uid :users-by 'users-by-uid-of)
      (response-with :message-type :ok)
      (response-with :message-type :error
		     :error-type 'no-such-uid)))

(defun response-with (&key message-type (payload nil) (error-type 'unknown))
  (encode-json-to-string
   (if (eq message-type :ok)
       (make-instance 'server-message
		      :message-type message-type
		      :payload payload)
       (make-instance 'server-message
		      :message-type message-type
		      :payload (make-instance 'error-payload
					      :error-code (assoc-cdr error-type
								     *error-codes*)
					      :error-description error-type)))))

;client message mapping
(defparameter *message-type-alist*
  '(("undefined" . undefined-command)
    ("login" . login)
    ("logout" . logout)
    ("list" . list-channels)
    ("create" . create-channel)))

;message to payload type
(defparameter *message-payload-alist*
  '((login . user-v)
    (logout . dummy)
    (undefined-command . dummy)
    (list-channels . dummy)
    (create-channel . channel)))

(defun json-to-client-message (json)
  (let* ((alist (decode-json-from-string json))
         (msg-type-string (assoc-cdr :message-type alist))
         (uid (assoc-cdr :uid alist))
         (msg-class (assoc-cdr msg-type-string *message-type-alist*
                               :test #'equal))
         (payload-class (assoc-cdr msg-class *message-payload-alist*
                                   :test #'equal)))
    (if (or (not msg-type-string) (not msg-class) (not payload-class))
       (make-instance 'client-message :message-type 'undefined)
       (make-instance 'client-message
                      :message-type msg-class
                      :uid uid
                      :payload (apply #'make-instance payload-class
				      (alist-plist (assoc-cdr :payload alist)))))))

(defun dispatch-message (client-msg)
  (let ((msg-function (message-type-of client-msg))
	(payload (payload-of client-msg))
	(uid (uid-of client-msg)))
    (log-as info "dispatching ~A" msg-function)
    (funcall msg-function payload uid)))

