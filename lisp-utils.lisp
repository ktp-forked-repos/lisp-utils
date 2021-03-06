(in-package :lisp-utils)

(define-modify-macro appendf (&rest lists) append)

(defun compose (&rest fns)
  (labels ((rec (fns)
		(if (null fns)
		    #'identity
		  #'(lambda (arg)
		      (funcall (car fns)
			       (funcall (rec (cdr fns)) arg))))))
    (rec fns)))


(defmacro with-gensyms (arg-names &body body)
  (let ((let-list (loop for arg in arg-names collect
			`(,arg (gensym)))))
    `(let (,@let-list)
       ,@body)))

(defmacro once-only (syms &body body)
  (let ((sym-names (mapcar #'(lambda (sym) (declare (ignore sym)) (gensym)) syms)))
    `(let (,@(mapcar #'(lambda (sym-name) `(,sym-name (gensym))) sym-names))
       `(let (,,@(mapcar #'(lambda (sym-name sym) ``(,,sym-name ,,sym)) sym-names syms))
	  ,(let (,@(mapcar #'(lambda (sym sym-name) `(,sym ,sym-name)) syms sym-names))
		,@body)))))

(defun flatten (lst &key to-depth)
  (labels ((rec (built remaining cur-depth)
	     (cond ((null remaining) built)
		   ((or (atom (car remaining))
			(and (integerp to-depth)
			     (>= cur-depth to-depth)))
		    (rec (cons (car remaining) built)
			 (cdr remaining)
			 cur-depth))
		   (t
		    (rec (rec built (car remaining) (1+ cur-depth))
			 (cdr remaining)
			 cur-depth)))))
    (nreverse (rec nil lst 0))))

(defun cat-symbols (&rest symbols)
  (intern (apply #'concatenate (cons 'string (mapcar #'symbol-name symbols)))))

(defun symb (&rest symbols)
  (intern
   (with-output-to-string (s)
     (dolist (symb symbols)
       (princ symb s)))))

(defun to-keyword (symbol)
  (intern (symbol-name symbol) :keyword))

(defun remove-nils (list)
  (remove-if-not #'identity list))

(defun random-elt (list)
  (elt list (random (length list))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun mappend (fn &rest lsts)
    (apply #'append (apply #'mapcar fn lsts))))

(defun cross (l1 l2)
  (mappend #'(lambda (o1)
	       (mapcar #'(lambda (o2) (list o1 o2)) l2))
	   l1))

(defun remassoc (item alist &rest rest-args)
  (remove (apply #'assoc item alist rest-args)
	  alist :test #'equal))

(defmacro abbrev (long short &key body)
  (with-gensyms (args-sym)
    `(defmacro ,short (,(if body '&body '&rest) ,args-sym)
       `(,',long ,@,args-sym))))

(defmacro abbrevs (abbrevs)
  `(progn
     ,@(mappend #'(lambda (abbrev)
		    (list `(abbrev ,@abbrev)
			  `(export ',(cadr abbrev))))
		abbrevs)))

(abbrevs ((defparameter defpar)
	  (multiple-value-bind mvbind :body t)
	  (destructuring-bind debind :body t)
	  (defconstant defconst)))

(defmacro defn (name args &body body)
  (with-gensyms (arg-sym)
    `(defun ,name (,arg-sym)
       (debind ,args ,arg-sym
	       ,@body))))

(defmacro pincf (place &optional (delta 1))
  (with-gensyms (place-arg)
    `(let ((,place-arg ,place))
       (incf ,place ,delta)
       ,place-arg)))

(defun avg (&rest nums)
  (if (null nums)
      0
      (/ (apply #'+ nums) (length nums))))

(defmacro awhen (test &body body)
  `(let ((lisp-utils:it ,test))
     (when lisp-utils:it ,@body)))

(defmacro aif (test then &optional else)
  `(let ((lisp-utils:it ,test))
     (if lisp-utils:it ,then ,else)))

(defmacro aand (&rest clauses)
  (cond ((null clauses) t)
	((null (cdr clauses)) (car clauses))
	(t
	 `(aif ,(first clauses)
	       (aand ,@(rest clauses))))))

(defmacro asetf (&rest args)
  (with-gensyms (val)
    (when args
      `(let* ((lisp-utils:it ,(first args))
	      (,val ,(second args)))
	 (setf ,(first args) ,val)
	 ,(aif (cddr args)
	       `(asetf ,@(cddr args))
	       `,val)))))

(defmacro do-destructs ((lambda-list list) &body body)
  (once-only (list)
    (with-gensyms (element-sym)
      `(dolist (,element-sym ,list)
	 (destructuring-bind ,lambda-list ,element-sym
	   ,@body)))))

(defmacro d-lambda (lambda-list &body body)
  (with-gensyms (args-sym)
    `#'(lambda (&rest ,args-sym)
	 (destructuring-bind ,lambda-list ,args-sym
	   ,@body))))

(defun limit (list n)
  (labels ((rec (built-list rem n)
	     (cond
	       ((null rem) built-list)
	       ((= 0 n) built-list)
	       (t
		(rec (cons (car rem) built-list) (cdr rem) (- n 1))))))
    (nreverse (rec '() list n))))

(defun limiting-subseq (sequence start &optional end)
  (subseq sequence start (min (length sequence) end)))

(define-modify-macro set-conc (&rest strings) (lambda (&rest strings) (apply #'concatenate (cons 'string strings))))

(defun string-conc (&rest strings)
  (apply #'concatenate 'string strings))

(defun curry (fn &rest args)
  #'(lambda (&rest rest-args)
      (apply fn (append args rest-args))))

(defmacro bind-nil (vars &body body)
  `(let ,(mapcar #'(lambda (var) `(,var nil)) vars)
     ,@body))

(defmacro self-ref (sym &body body)
  (with-gensyms (body-result eval-body-fn)
    `(let ((,body-result))
       (labels ((,eval-body-fn () ,@body)
		(,sym () ,body-result))
	 (setf ,body-result (,eval-body-fn))
	 ,body-result))))

(defun alast (array)
  (let ((len (length array)))
    (when (> len 0)
      (aref array (- (length array) 1)))))

(defun afirst (array)
  (when (> (length array) 0)
    (aref array 0)))

(defmacro doarray ((var array &optional result) &body body)
  `(progn
     (loop for ,var across ,array do 
	  ,@body)
     ,result))

(defun gvector (&rest elements)
  (let ((array (make-array 0 :adjustable t :fill-pointer 0)))
    (dolist (element elements)
      (vector-push-extend element array))
    array))

(defun alist-to-ht (alist)
  (let ((ht (make-hash-table :test 'equal)))
    (dolist (association alist)
      (symbol-macrolet ((hash-location (gethash (car association) ht)))
	(let ((hash-location-val hash-location))
	  (cond ((null hash-location-val) (setf hash-location (cdr association)))
		((atom hash-location-val) (setf hash-location (list (cdr association) hash-location-val)))
		(t (setf hash-location (cons (cdr association) hash-location-val)))))))
    ht))

(defmacro all-case (keyform &body cases)
  (with-gensyms (keyform-sym)
    `(let ((,keyform-sym ,keyform))
       ,@(loop for case in cases collect
	      `(case ,keyform-sym
		 ,case)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; function objects
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun action-name (action)
  (first action))

(defun action-args (action)
  (second action))

(defun action-fn (action)
  (cddr action))

(defmacro def-fn-obj (name lambda-list &rest actions)
  (with-gensyms (dispatch-fn)
    `(defun ,(cat-symbols 'create- name) ,(cons '&key lambda-list)
       (labels (,@(append (mapcar #'(lambda (action)
				      `(,(action-name action)
					 ,(action-args action)
					 ,@(action-fn action)))
				  actions)
			  `((,dispatch-fn (sym)
					  (case sym
					    ,@(mapcar #'(lambda (action)
							  `(,(action-name action)
							     #',(action-name action)))
						       actions))))))
	 #',dispatch-fn))))

(defun send-message (obj message &rest args)
  (let ((action (funcall obj message)))
    (if args
	(apply action args)
	(funcall action))))

(defun get-action (obj action)
  (funcall obj action))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#+:sbcl
(defun gen-uuid-str ()
  (write-to-string (unicly:make-v4-uuid)))

#+:sbcl
(defmacro with-atomically-updated-file ((stream filespec &rest options) &body body)
  (with-gensyms (file-name pathspec)
    `(progn
       (let* ((,file-name (gen-uuid-str))
	      (,pathspec
		(merge-pathnames (make-pathname :name ,file-name)
				 (ensure-directories-exist
				  (make-pathname :directory 
						 (append (pathname-directory ,filespec)
							 '(".update-area")))))))
	 (with-open-file (,stream ,pathspec ,@options)
	   ,@body)
	 (rename-file ,pathspec ,filespec)))))

(defun hash-literal-transformer (stream subchar arg)
  (let ((sexp (read stream t)))
    (let ((hash-sym (gensym)))
      `(let ((,hash-sym (make-hash-table :test 'equal)))
	 ,@(loop for (key val) on sexp by #'cddr collect
		`(setf (gethash ,key ,hash-sym) ,val))
	 ,hash-sym))))

(set-dispatch-macro-character #\# #\h #'hash-literal-transformer)

(defun maphash-to-list (fn ht)
  (let ((list (list)))
    (maphash #'(lambda (k v) (push (funcall fn k v) list))
	     ht)
    (nreverse list)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; @ccessor macro
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun @ccessor-sym-p (sym prefixes)
  (some #'(lambda (prefix)
	    (eql (search (write-to-string (symb prefix '@))
			 (write-to-string sym))
		 0))
	prefixes))

(defun get-fetcher (acc-sym template)
  ;; TODO - can the eval be removed below???
  (eval `(let* ((symstr (write-to-string ',acc-sym))
		(place (intern (subseq symstr 0 (position #\@ symstr :from-end t))))
		(ind (intern (subseq symstr (1+ (position #\@ symstr :from-end t))))))
	   ,template)))

(defmacro with-@ccessors ((&rest vars) fetcher &body body)
  "fetcher example: ``,(getf ,place ',ind)"
  (when (notevery #'symbolp vars) (error "~a contains a non-atomic symbol" vars))
  (let ((@ccessor-syms (remove-duplicates
			(remove-if-not #'(lambda (atom)
					   (@ccessor-sym-p atom vars))
				       (flatten body)))))
    `(symbol-macrolet ,(mapcar #'(lambda (@-sym)
				   (list @-sym
					 (if fetcher
					     (get-fetcher @-sym fetcher)
					     (get-fetcher @-sym ``(,ind ,place)))))
			       @ccessor-syms)
       ,@body)))

(defmacro with-@ccessors* ((&rest vars) fetcher &body body)
  "example: (with-@ccessors* (student student@homeroom-teacher) <fetcher> student@homeroom-teacher@last-name)"
  (if vars
    `(with-@ccessors (,(car vars)) ,fetcher
       (with-@ccessors* ,(rest vars) ,fetcher ,@body))
    `(progn ,@body)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; environment reader char
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar *prop-file-path* nil)
(defun get-property-val (property)
  (assert (stringp property))
  (aif (osicat:environment-variable property)
       (with-input-from-string (s it)
	 (read s))
       (when *prop-file-path*
	 (with-open-file (s (cl-fad:pathname-as-file *prop-file-path*))
	   (gethash property (eval (read s)))))))

(defun env-literal-transformer (stream subchar arg)
  (declare (ignore subchar arg))
  (let ((str (read stream t)))
    `(get-property-val ,str)))

(set-dispatch-macro-character #\# #\e #'env-literal-transformer)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; do-tree
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun do-tree (predicate replacer-fn tree)
  (labels ((aux (processed tree)
	     (cond ((null tree) (nreverse processed))
		   ((and (car tree) (atom (car tree)))
		    (if (funcall predicate (car tree))
			(aux (cons (funcall replacer-fn (car tree)) processed) (cdr tree))
			(aux (cons (car tree) processed) (cdr tree))))
		   ((car tree)
		    (aux (cons (aux '() (car tree)) processed) (cdr tree)))
		   (t (aux (cons (car tree) processed) (cdr tree))))))
    (aux '() tree)))
