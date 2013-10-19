(in-package :octopus)

(defun start-server ())
(defun stop-server ())

(def class* octopus-resource (ws-resource)
  ())

(defmethod resource-client-connected ((res octopus-resource) client)
  (log-as info "client connected on octopus server from ~s : ~s" (client-host client) (client-port client))
  t)

(defmethod resource-client-disconnected ((resource octopus-resource) client)
  (log-as :info "client disconnected from resource ~A" resource))

(defmethod resource-received-text ((res octopus-resource) client message)
  (log-as info "got frame ~s... from client ~s" (subseq message 0 10) client)
  (write-to-client-text client message))

(defmethod resource-received-binary((res octopus-resource) client message)
  (log-as info "got binary frame len: ~s" (length message) client)
  (write-to-client-binary client message))

(defun register-octopus-resource ()
  (register-global-resource *resource-path*
                          (make-instance 'octopus-resource)
                          (apply 'origin-prefix *resource-origin-prefixes*)))

(defun start-octopus-server ()
  (initialize)
  (register-octopus-resource)
  (start-websocket-server)
  (start-resource-listener))

(defun initialize ()
  ;put here initialization of all components
  (initialize-log))

(defun start-websocket-server ()
  (setf *server-thread* (bordeaux-threads:make-thread (lambda ()
				  (run-server *port*))
				:name *server-thread-name*)))

(defun start-resource-listener ()
  (setf *resource-thread* (bordeaux-threads:make-thread (lambda ()
                                (run-resource-listener
                                 (find-global-resource *resource-path*)))
				:name *resource-listener-name*)))

(defun kill-octopus-server ()
  (bordeaux-threads:destroy-thread *server-thread*)
  (bordeaux-threads:destroy-thread *resource-thread*)
  (setf *server-thread* nil *resource-thread* nil))

(defun restart-octopus-server ()
  (kill-octopus-server)
  (start-octopus-server))