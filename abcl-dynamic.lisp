;;; Routines to facilitate scripting Java dynamically from CL
(in-package #:abcld)

(eval-when (:load-toplevel :execute)
  ;; XXX ensure we are binding to the same symbol as produced by JSS
  (setf *dynamic-classpath* cl-user::*added-to-classpath*))

(defvar *verbose* t)
(defmacro verbose (message &rest parameters)
  `(if *verbose*
      (format t (concatenate 'string "~&" ,message ) ,@parameters)
      (finish-output)))

;;; XXX Why can't one just export such a symbol?
(defmacro new (classname &rest args)
  `(cl-user::new ,classname ,@args))

(defmacro get-java-field (object field &optional try-harder)
  `(cl-user::get-java-field ,object ,field ,try-harder))

;;; XXXX 
#|
	 (jnew (lookup-in-added-classpath
		"com.ontotext.wsmo4j.serializer.xml.WsmlXmlSerializer")))
	(target (abcld-jnew "java.lang.StringBuffer"))

 (abcld-introspect-instance (name-or-ref)
  
|#


(defun introspect (name-or-ref)
  ;; presumably not in default classpath
  (verbose "type-of ~A" name-or-ref)
  (when (typep name-or-ref 'java-object)
    (class-of name-or-ref))
  (when (typep name-or-ref 'string)
    (introspect-classpath name-or-ref)))

(defun instantiate (introspected)
  (verbose "~&Instantiating a ~A" introspected)
  (let* ((fully-qualified-classname 
	  (if (jinstance-of-p introspected "java.lang.Class")
	      (#"getName" introspected)
	      introspected))
	 (hook (gethash fully-qualified-classname *instantiate-hooks*)))
    (if hook
	(funcall hook introspected)
	(warn "~&Failed to find instantiation hook for ~A." fully-qualified-classname))))

(defun introspect-classpath (name-or-ref)
  (jclass-dynamic name-or-ref))

(defun dynamic-jars ()
    (loop :for jar :in *dynamic-classpath*
       :collecting jar))

(defconstant +java-null+ 
  (make-immediate-object nil :ref) 
  "A 'null' reference Java object")


;;; XXX somehow, we have to figure out how to enumerate available classloaders
(defun jclass-dynamic (name)
  "Returns the java.lang.Class for something on CL-USER:*added-to-classpath*"
  (#"forName" 'java.lang.Class
	      name
	      nil
	      (#"getClassLoader"  (jclass "dclass.Class"))))

;;; XXX need to fix classpath for when WSML2REASONER is not driving application
(defun jenum (&optional 
	      (enum "IRIS")
	      (enum-for-name
	       "org.wsml.reasoner.api.WSMLReasonerFactory$BuiltInReasoner")
	      (key #"toString")
	      (test #'equal))
  "Return java object for ENUM from ENUM-FOR-NAME type."
  (let* ((enum-class
	  (#"forName" 'java.lang.Class
		      enum-for-name
		      nil
		      (#"getClassLoader" (jobject-class (#"getFactory"
							 'DefaultWSMLReasonerFactory)))))
	 (enum-constants (#"getEnumConstants" enum-class)))
    (find enum enum-constants :key key :test test)))


;;; XXX
(defmethod print-object ((object java-object) stream )
  (print-unreadable-object (object stream :type t)
    (format stream "print-object" )))

(defvar *instantiate-hooks*
  (make-hash-table :test #'equal)
  "Hash of strings representing Java classnames to instantiate hooks")

(defun add-instantiate-hook (classname hook)
  "Possibly replace string indexed CLASSNAME with an instaniation HOOK
  of the form #'(lambda (classname) ..."
  (setf (gethash classname *instantiate-hooks*)
	hook))

;;; XXX generalize to returning different types of java.io.* interfaces
(defun jstream (file)
  "For a pathname for FILE, return a Java java.io.InputStreamReader"
  (handler-case
      (let* ((pathname (namestring (merge-pathnames file)))
	     (file-input-stream (cl-user::new 'FileInputStream pathname))
	     (input-stream-reader (cl-user::new 'InputStreamReader
						file-input-stream)))
	(verbose "Opened '~A' for read." file)
	input-stream-reader)
    ;;; XXX Fix java exception hierarchy
    (java-throwable (e)
	(error "Failed to load file '~S' because of throwable: ~A"
	       file e))
    (java-exception (e)
	(error "Failed to load file '~S' because of exception: ~A"
	       file e))))


;;; XXX
(defun jfield-static (classname field)
  (jfield (class-for-name-dynamic-classpath classname) field))

(defun jclass-dynamic (classname)
  (class-for-name-dynamic-classpath classname))

(defun class-for-name-dynamic-classpath (classname)
  (flet ((dynamic-classloader (classname)
	 (#"getClassLoader" (jobject-class classname)))
	 (introspect-classloaders ()
	   "dclass,Class"))
    (#"forName" 'java.lang.Class classname nil
		(dynamic-classloader (introspect-classloaders)))))
	

(defun jhashtable (hashtable)
  "Create a java.util.Hashtable from a HASHTABLE"
  (let ((results (new 'java.util.Hashtable)))
    (loop :for key :being :the :hash-keys :of hashtable 
       :using (hash-value value)
       do (#"put" results key value))
    results))

;;; XXX register-java-exception doensn't seem to work here, although
;;; the tests in ABCL seem to run ok.
(defmacro with-registered-exception (exception condition &body body)
  `(unwind-protect
       (progn
         (register-java-exception ,exception ,condition)
         ,@body)
     (unregister-java-exception ,exception)))

