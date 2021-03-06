(in-package :octopus)

(defclass database-connection
    (hu.dwim.perec:postgresql/perec)
  ())

(defparameter hu.dwim.perec:*database*
  (make-instance 'database-connection
    :connection-specification
    `(:host ,*database-host*
      :database ,*database-name*
      :user-name ,*database-user*
      :password  ,*database-password*)))
