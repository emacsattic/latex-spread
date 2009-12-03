;; ----------------------------------------------------------------------
;; latex-spread.el 
;; ----------------------------------------------------------------------
;; latex-spread.el V0.9#4 -- Simple spreadsheet minor mode for LaTeX:
;; allows including formulas in LaTeX files and using emacs to update them 
;; 
;; M. Hermenegildo (started 23-10-95) 
;; http://www.clip.dia.fi.upm.es/~herme
;; herme@fi.upm.es 
;; based on spread.el mode by Benjamin C. Pierce
;; with suggestions from Daniel Cabeza, Manuel Carro, Julio Marinyo, 
;; and Niels L Ellegaard
;;
;; Installation instructions:
;;     - Place latex-spread.el in a directory on your emacs load path
;;     - Add the following lines to your .emacs file:
;;  (autoload 'latex-spread-mode "latex-spread" "Simple LaTeX spreadsheet."  t)
;; 
;; Use: within latex-mode, AUC-TeX-mode, etc. do "M-x latex-spread-mode"
;; 
;; Complete documentation appears in the header of the latex-spread-mode 
;; function, at the top of this file (can be viewed easily by typing
;; C-h f and "latex-spread-mode" inside emacs once the code is
;; loaded). 
;;
;; Please keep the original source information and document changes if
;; you make any modifications to this file. I would also be very
;; grateful if you send the changes back: I will try to keep an
;; updated version with any improvements that I receive. In
;; particular, it may be useful to develop a library of aggregation
;; functions and, in general, more powerful aggregation facilities. 
;; 
;; Now values in val need not be numbers (can be strings)
;; 
;; Known bugs / future improvements:
;; - does not work correctly on Emacs-18 (and not tested on xemacs)
;; - comma format is lost if result is smaller than 1,000
;; - more flexible formats (e.g., scientific notation, in addition to
;;   commas, european format) should be added
;; - handling of result being larger than the provided format could
;;    be improved
;; - the imperative flavour could be eliminated if new editing commands
;;   (giving new names to array variables automatically, for example)
;;   were provided. 
;;
;; This package is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 1, or (at your option)
;; any later version.
;;   Spread-latex-mode is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;   You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA. 


;; --------------------------------------------------------------------------
;; Set-up and keybindings
;; --------------------------------------------------------------------------

(defvar latex-spread-running-FSF19 
  (and (string-match "^19" emacs-version) 
       (not (string-match "Lucid" (emacs-version)))))
(defvar latex-spread-running-18 (string-match "^18" emacs-version))

;; Minor mode toggling vars
(defvar latex-spread-mode nil
  "Non-nil if using latex-spread-mode mode as a minor mode of
   some other mode.") 
(make-variable-buffer-local 'latex-spread-mode)
(put 'latex-spread-mode 'permanent-local t)

;; Install mode in minor mode alist
(or (assq 'latex-spread-mode minor-mode-alist)
    (setq minor-mode-alist (append minor-mode-alist
                    (list '(latex-spread-mode " LSp")))))

;; Key bindings
;; Made compatible with AUC-TeX bindings
(defvar latex-spread-mode-prefix-map nil)
(if latex-spread-mode-prefix-map
    nil
  (setq latex-spread-mode-prefix-map (make-sparse-keymap))
  (define-key latex-spread-mode-prefix-map "i" 'latex-spread-insert-commands)
  (define-key latex-spread-mode-prefix-map "r" 'latex-spread-recalc)
  (define-key latex-spread-mode-prefix-map "1" 'latex-spread-recalc-once)
  (define-key latex-spread-mode-prefix-map "v" 'latex-spread-init-vars)
  (define-key latex-spread-mode-prefix-map "o" 'overwrite-mode)
  )

(defvar latex-spread-mode-map nil "")
(if latex-spread-mode-map
    nil
  (setq latex-spread-mode-map (make-sparse-keymap))
  (define-key latex-spread-mode-map "\C-c" latex-spread-mode-prefix-map))

;; Install key bindings in minor mode alist
(or (assq 'latex-spread-mode minor-mode-map-alist)
      (setq minor-mode-map-alist
	    (cons (cons 'latex-spread-mode latex-spread-mode-map)
		  minor-mode-map-alist)))

;; Main
(defun latex-spread-mode (&optional arg)
  "Toggle minor mode for simple spreadsheets in LaTeX files. With arg,
turn latex-spread-mode on if arg is positive, off otherwise. 

Quick reference:
    recalculate                         \\[latex-spread-recalc]
    recalculate-once                    \\[latex-spread-recalc-once]
    toggle overwrite-mode               \\[overwrite-mode]
    init-vars (after
    introducing new variables)          \\[latex-spread-init-vars]


OVERVIEW
--------

A latex-spreadsheet is an ordinary latex buffer with embedded \"cells\" of
the form

       \\val{VALUE}{FORMULA}

or

       \\var{VALUE}{FORMULA}{NAME}

or

       \\eva{FORMULA}

where

    * VALUE, the current value of the cell, is a single word (typically a 
      number);
    * FORMULA is an arbitrary lisp expression, used to recalculate VALUE; and
    * NAME, if present, is a lisp variable to which VALUE is assigned 
      after each recomputation.

A single recalculation step, triggered by typing
\\[latex-spread-recalc-once], consists of scanning the buffer,
recalculating each cell by replacing the current VALUE by the result
of evaluating FORMULA.  A complete recalculation, triggered by typing
\\[latex-spread-recalc], iterates this process until the buffer stops
changing. 

When an old value is replaced, the first character of the newly
computed value is placed in the same column as the first character of
the old.  If the values are numeric, the new value is truncated to the
same number of decimal places as the old.  The spacing of the
remainder of the line is preserved, except if the length of the new
value is greater that of the old one, in which case new space is
inserted.

For correct operation, a suitable definition should be provided in the
latex file for the \"val\", \"var\", and \"eva\" commands. Normally,
the idea is to print the first argument (the value) and ignore the
rest, except in \"eva\" commands, where generally nothing is
printed. The simplest example is:

\\newcommand{\\val}[2]{#1}
\\newcommand{\\var}[3]{#1}
\\newcommand{\\eva}[1]{  }

but you could also use, for example

\\newcommand{\\val}[2]{{\\bf #1}}
\\newcommand{\\var}[3]{{\\bf #1}}
\\newcommand{\\eva}[1]{  }

or similar commands. 

FORMULAS
--------

The formula associated with a cell may be just a constant.  This form is 
useful for making names for common constants; e.g.:

        \\var{10}{10}{length}

More generally, a formula may involve arbitrary arithmetic calculations
including variables whose values are set by other cells:

 \\var{ 555    }{ 555                }{ breadth }
 \\var{ 5550   }{ (* length breadth) }{ area }
 \\var{ 29137  }{ (* area 5.25)      }{ total-cost }

Values can be printed also in ``comma format,'' which is easier to
read for large numbers. This is triggered by simply including a comma
anywhere in the VALUE field: \\val{,000000000}{12345678}. Note that
enough space must be left also for the commas in the value field.

In Emacs version 19 and later (both FSF and Lucid), floating-point
numbers may also be used in formulas.  If the value part of a formula
is written with a decimal point, new values will be truncated to the
same length when it is updated. As an example, here is a small LaTeX
table:

\\begin{tabular}{|r|r|r|r|}
\\hline
Nagents        &   Time               &  Speedup                 \\\\
\\hline
  Seq.         & \\var{33.0}{33.0}{ts} &  \\val{1.000}{1.000    }\\\\
\\var{1}{1}{n} & \\var{33.4}{33.4}{tp} &  \\val{0.988}{(/ ts tp)}\\\\
\\var{2}{2}{n} & \\var{17.5}{17.5}{tp} &  \\val{1.886}{(/ ts tp)}\\\\
\\var{3}{3}{n} & \\var{11.9}{11.9}{tp} &  \\val{2.773}{(/ ts tp)}\\\\
\\hline
\\end{tabular}

Variables are updated destructively, following the textual (top-down,
left-right) file order. This is not conceptually elegant but it is
very useful in practice because it allows building tables as the one
above (where the same variable name is used in each line) by simple
cutting and pasting, without having to come up with new variable names
every time.  Any reference to a variable in an expression always
refers to the last assigned value.

VALUE AGGREGATION:
------------------

Sometimes it is desirable to perform operations which affect all the
values that have been given to a variable over a certain region of the
file. This is the case, for example, when computing the total for a
column in a table and in other similar aggregation functions. For this
purpose all the values that are assigned to a variable are stored in a
list which is associated with the variable as a property (the property
has the name \"history\"). This list can be accessed in any lisp
expression, which allows computing averages and more complex
functions. Also, the variable can be cleared, for example before a new
table that reuses a variable name used in a previous table, by simply
assigning the value nil to the aggregation variable.  A function (gh
'var) is provided which return the history of variable (the variable
name should be quoted in the call). Also functions (ch 'var) and (sh
'var value) respectively clear the history of a variable and set the
history of variable to a given value.  Here is an example of the use
of aggregation variables in the previous table:

%% This clears the value histories of tp and sp:
%% \\eva{(ch 'tp)}
%% \\eva{(ch 'sp)}
\\begin{tabular}{|r|r|r|r|}
\\hline
Nagents        &   Time               &  Speedup                 \\\\
\\hline
  Seq.         & \\var{33.0}{33.0}{ts} &  \\val{1.000}{1.000    }\\\\
\\var{1}{1}{n} & \\var{33.4}{33.4}{tp} &  \\val{0.988}{(/ ts tp)}\\\\
\\var{2}{2}{n} & \\var{17.5}{17.5}{tp} &  \\val{1.886}{(/ ts tp)}\\\\
\\var{3}{3}{n} & \\var{11.9}{11.9}{tp} &  \\val{2.773}{(/ ts tp)}\\\\
\\hline
{\\bf Sp. Avg.} &  & \\val{1.882}{(/ (sumlist (gh 'sp)) (length (gh 'sp)))}\\\\
%% \\eva{(setq sum (sumlist (gh 'tp)))}
{\bf Total}   & \val{62.80}{sum} & \\
\\hline
\\end{tabular}

OTHER USEFUL FUNCTIONS:
-----------------------

A possibly useful function is (date-and-time), which returns the
current date and time compressed into a single word:

       \\val{  18/10/1995-19:18    }{ (date-and-time)  }

As examples of functions operating on aggregation variables a number
of other functions are provided: sumh, numh, mean, sumlist, prodlist,
etc. -- see their descriptions for more information. Others can be
included in this file or defined in the LaTeX file via an \"eva\"
construct.

Also, it is possible to use the \\eva/\\val constructs to perform other
operations. Here is an example (by Niels Langager):

\\eva{(defun greet (friend) (concat \"Hi \" friend))}
\\val{\"Hi Bob\" }{(greet \"Bob\")}

CUSTOMIZATION
-------------

Invoking latex-spread-mode calls the value of text-mode-hook and then of
latex-spread-mode-hook, if they are non-nil."

  (interactive "P")
  (setq latex-spread-mode
	(if (null arg) (not latex-spread-mode)
	  (> (prefix-numeric-value arg) 0)))
  (if latex-spread-mode
      (progn
	(latex-spread-mode-setup)
	(run-hooks 'latex-spread-mode-hook))
    (setq selective-display nil))
    (if latex-spread-running-FSF19 (force-mode-line-update))
  )

(defun latex-spread-mode-setup ()
    (setq truncate-lines t)
    (auto-fill-mode nil)
    (latex-spread-init-vars)
)

(defun latex-spread-init-vars ()
  (interactive)
  (let (varchars val varname)
    (latex-spread-debug "Initializing variables")
    (save-excursion
      (goto-char (point-min))
      (while (search-forward "\\var{" (point-max) t)
        (re-search-forward "[-0-9.,/\:]")
        (setq val (latex-spread-number-under-cursor))
        (re-search-forward "{")
        (re-search-forward "{")
        (re-search-forward "\\w+")
	(setq varchars (buffer-substring (match-beginning 0) (match-end 0)))
        (setq varname (intern varchars))
        (latex-spread-debug "'%s' := '%s'" varname val)
        (make-variable-buffer-local varname)
        (set varname val)
	(put varname 'history nil)
        (latex-spread-debug "'%s' history := '%s'" varname (get varname 'history))
	))))

;; --------------------------------------------------------------------------
;; Recalculation
;; --------------------------------------------------------------------------

(defvar latex-spread-recalc-limit 40 
  "*Maximum iterations of latex-spreadsheet recalculation")

(defun latex-spread-recalc ()
  "Recalculate all computed cells in buffer, iterating until all cells'
values have stabilized or for SPREAD-RECALC-LIMIT iterations, whichever
comes first."
  (interactive)
  (message "Recalculating... ")
  (let ((limit 0))
    (while (save-excursion (latex-spread-recalc-once))
      (message "Recalculating... (%s)" limit)
      (sit-for 0)
      (setq limit (+ limit 1))
      (if (= limit latex-spread-recalc-limit)
          (latex-spread-error "Recalculation looping!"))))
    (message "Recalculating... done"))

(defun latex-spread-get-next-cell (cont)
  (if (search-forward-regexp "[\\]\\(val\\|var\\|eva\\){" (point-max) t)
      (let (after eol b e res start end contents var formula formula-start)
        (latex-spread-debug "found a cell")
	(backward-char 4)
	(if (looking-at "eva{")
	  (progn
	    (latex-spread-debug "(an eva cell)")
	    (re-search-forward "{")
	    ;; start has the point at which the formula starts
	    (setq formula-start (point))
	    (re-search-forward "}")
	    (backward-char 1)
	    ;; end has the point at which the formula ends
	    (setq eol (point))
	    (setq res (read-from-string (buffer-substring formula-start eol)))
	    ;; formula has the formula
	    (setq formula (car res))
	    (latex-spread-debug "formula: '%s'" formula)
	    (setq contents (latex-spread-eval formula))
    	    (latex-spread-debug "returned value: '%s'" contents))
	  ;; Looking at val or var
	  (progn
	    (cond 
	     ((looking-at "var{")
	      (latex-spread-debug "(a var cell)")
	      (forward-char 4)
	      (while (looking-at "[^-0-9.,/\:]") (forward-char 1))
	      ;; start has the point at which the initial value starts
	      (setq start (point))
	      (while (looking-at "[-0-9.,/\:-]") (forward-char 1))
	      ;; end has the point just after the initial value
	      (setq end (point))
	      ;; now contents has the initial value
	      (setq contents (buffer-substring start end)))
	     (t
	      (latex-spread-debug "(a val cell)")
	      (forward-char 4)
	      ;; values do not really have to be parsed:
	      ;; a value is just an output and can be even a string
	      ;; a value cannot contain }
	      (setq start (point))
	      (re-search-forward " *}") ;; skip trailing blanks
	      (backward-char 1)
	      (setq end (match-beginning 0))
	      ;; (setq end (point))
	      ;; now contents has the initial value
	      (setq contents (buffer-substring start end))))
	    (latex-spread-debug "contents: '%s'" contents)
	    (re-search-forward "{")
	    ;; formula-start has the first point of the formula 
	    (setq formula-start (point))
	    (re-search-forward "}")
	    (backward-char 1)
	    ;; eol has the end of the formula
	    (setq eol (point))
	    (forward-char 1)
	    ;; after has the point after the formula (to be updated later
	    ;; if there is a variable name)
	    (setq after (point))
	    (goto-char formula-start)
	    ;; res has ( <formula> . <number of characters> )
	    (setq res (read-from-string (buffer-substring formula-start eol)))
	    ;; formula has the formula
	    (setq formula (car res))
	    (latex-spread-debug "formula: '%s'" formula)
	    (re-search-backward "{")
	    (re-search-backward "{")
	    (re-search-backward "va")
	    ;; at beginning of command
	    (if (looking-at "var{")
		(progn 
		  (search-forward "{")
		  (search-forward "{")
		  (search-forward "{")
		  (setq b (point))
		  (search-forward "}")
		  (setq after (point))
		  (backward-char 1)
		  (setq e (point))
		  (setq var (intern (buffer-substring b e)))
		  (latex-spread-debug "variable: '%s'" var)
		  ))
	    (goto-char after)
	    (if latex-spread-running-FSF19
		(latex-spread-fontify-cell start end after))
;;         (latex-spread-debug 
;;   "cont:%s \n start:%s end:%s contents:%s var:%s formula:%s after:%s" 
;;    cont start end contents var formula after)
	    (funcall cont start end contents var formula after)))
	t)
    nil))

(defun latex-spread-recalc-once ()
  "Recalculate all computed cells in buffer.  Return T if any of them
change their values, NIL otherwise."
  (interactive)
  (latex-spread-debug "Recalculating once")
  (let ((any-changes nil)
        cell)
    (goto-char (point-min))
    (while (latex-spread-get-next-cell
       '(lambda (cell-start cell-end contents var formula formula-end)
               (goto-char cell-start)
               (setq new (latex-spread-eval formula))
               (setq new-string (latex-spread-format-like contents new))
               (setq new-length (length new-string))
               (latex-spread-debug "'%s'  <---  '%s'    from '%s'" 
                             contents new-string formula)
               (if (not (string= new-string contents))
                   (progn 
                     (setq any-changes t)
                     (goto-char cell-start)
                     (if (>= new-length (length contents))
                         (progn
                           (delete-region cell-start cell-end)
;; Changed so that source commands are not overwritten when result is
;; larger than initial value.
;;                         (delete-region cell-start (+ cell-start new-length))
			   (latex-spread-debug "inserting '%s'" new-string)
                           (insert new-string))
                       (progn
                         (delete-region cell-start cell-end)
			 (latex-spread-debug "inserting '%s'" new-string)
			 (latex-spread-debug "inserting padding '%s'" 
		           (make-string (- (length contents) new-length) 32))
                         (insert 
                          new-string
                          (make-string (- (length contents) new-length) 32)))
                       )))
               (if var 
                  (progn
                    (latex-spread-debug "'%s' := '%s'" var new)
                    (set var new)
		    (put var 'history (cons new (get var 'history)))
                    (latex-spread-debug "'%s' history := '%s'" var 
					(get var 'history))))
               (goto-char formula-end)
               )))
    any-changes))

(defun latex-spread-eval (exp)
  (condition-case err
      (eval exp)
    (void-variable 
     (let ((r 88888))
       (latex-spread-warning 
        (format "Variable \"%s\" is unbound; using value %d" 
                (car (cdr err)) r))
       r))
    (error 
     (let ((r 99999))
       (latex-spread-warning 
        (format "Evaluation failed with \"%s\"; using value %d" err r))
       r))))

(defun latex-spread-insert-commands ()
  "Insert dummy LaTeX macros for latex-spread commands"
  (interactive)
  (insert-string
"\\newcommand{\\val}[2]{#1}
\\newcommand{\\var}[3]{#1}
\\newcommand{\\eva}[1]{  }

"))

;; ----------------------------------------------------------------------
;; Some useful user-level functions
;; 
;; Note: the names of these functions do not have the "latex-spread"
;; prefix in order to minimize the space their calls take in the LaTeX
;; source file. However, be careful with clashes with other packages
;; within emacs...
;; You can always take them out from this file and include the ones
;; needed at the beginning on the LaTeX file, inside eva statements.
;; ----------------------------------------------------------------------

;; User functions for accessing a variable's history
(defun gh (varname)
  "Return history of variable (variable name should be quoted)"
  (get varname 'history))

(defun ch (varname)
  "Clear history of variable (variable name should be quoted)"
  (put varname 'history nil))

(defun sh (varname value)
  "Set history of variable (variable name should be quoted)"
  (put varname 'history value))

;; Some aggregate functions
(defun sumh (varname)
  "Return the sum of the numbers in the history of the quoted variable
   given as argument"
  (sumlist (gh varname)))

(defun numh (varname)
  "Return the number of elements in the history of the quoted variable
   given as argument"
  (length (gh varname)))

(defun mean (varname)
  "Return the average of the numbers in the history of the quoted variable
   given as argument"
  (let ((hist (gh varname)))
    (/ (sumlist hist) (length hist))))

(defun gmean (varname)
  "Return the geometric mean of the numbers in the history of the
  quoted variable given as argument"
  (let ((hist (gh varname)))
    (expt (prodlist hist) (/ 1.0 (length hist)))
 ))


(defun sumlist (list)
  "Return the sum of the numbers in the list of numbers given as argument."
  (if (eq list nil) 
      0
      (+ (car list) (sumlist (cdr list)))))

(defun prodlist (list)
  "Return the product of the numbers in the list of numbers given as argument."
  (if (eq list nil) 
      1
      (* (car list) (prodlist (cdr list)))))

(defun date-and-time ()
  "Returns the current date and time as a string, stripping the seconds
and substituting dashes for blanks"
  (interactive)
  (concat (if (string= (substring (current-time-string) 8 9) " ")
              ""
            (substring (current-time-string) 8 9))
          (substring (current-time-string) 9 10)
          "/"
	  (latex-spread-month-to-digits (substring (current-time-string) 4 7))
          "/"          
	  (substring (current-time-string) 20)
          "-"
          (substring (current-time-string) 11 16)
          ))

;; Number dates have the advantage of being legible in more languages
;; and contexts... 
(defun latex-spread-month-to-digits (string)
  (cond ((string= string "Jan") "01")
	((string= string "Feb") "02")
	((string= string "Mar") "03")
	((string= string "Apr") "04")
	((string= string "May") "05")
	((string= string "Jun") "06")
	((string= string "Jul") "07")
	((string= string "Aug") "08")
	((string= string "Sep") "09")
	((string= string "Oct") "10")
	((string= string "Nov") "11")
	((string= string "Dec") "12")
        (t "00")))
      
;; ----------------------------------------------------------------------
;; Utility functions
;; --------------------------------------------------------------------------

(defun latex-spread-number-under-cursor ()
  (interactive)
    (save-excursion
      (goto-char (+ (point) 1))
      (re-search-backward "\\(^\\|[^-0-9.,/\:]\\)\\([-0-9.,/\:]\\)")
      (let ((begin (match-beginning 2)))
        (goto-char begin)
        (re-search-forward "[^-0-9.,/\:]")
        (string-to-int (latex-spread-rm-commas 
         ;; (in V19, this actually returns a float if necessary!)
         (buffer-substring begin (match-beginning 0)))))))

(defun latex-spread-rm-commas (numberstring)
  (if (string= numberstring "")
    ""
    (if (string= (substring numberstring 0 1) "\,")
      (latex-spread-rm-commas (substring numberstring 1))
      (concat (substring numberstring 0 1) 
	      (latex-spread-rm-commas (substring numberstring 1))))))

(defun latex-spread-format-like (old new)
  (if latex-spread-running-18
      ;; If we're running emacs 18, then floating point numbers
      ;; do not make sense anyway, so just format it as an integer
      (latex-spread-add-commas 
       (int-to-string new old nil))
    (progn
      (let ((old-decimal (string-match "\\." old)))
        (setq new 
              (cond
               ((stringp new) new)
               ((numberp new)
                (if old-decimal
                    (let ((oldprecision (- (length old) 1 old-decimal)))
		      (latex-spread-add-commas 
		       (latex-spread-float-to-string-with-precision 
			new oldprecision) old t))
		  (latex-spread-add-commas 
		   (int-to-string (truncate new)) old nil)))
               (t 
                (prin1-to-string new))))
        (if (latex-spread-contains-char new 32)
            (setq new (concat "\"" new "\"")))
        new
        ))))

(defun latex-spread-add-commas (string old decflag)
  (if (latex-spread-contains-char old ?, ) 
      (let (len i rem result)
	(if decflag 
	    (setq len (string-match "\\." string))
	  (setq len (length string)))
	(setq rem (- len (*  3 (truncate (/ len 3)))))
	(setq result (substring string 0 rem))
	(setq i rem)
	(while (< i len)
	  (setq result 
		(concat result 
			(if (string= result "") "" ",")
			(substring string i (+ i 3))))
	  (setq i (+ i 3)))
	(if decflag (setq result (concat result (substring string len))))
	result)
    string))

(defun latex-spread-float-to-string-with-precision (n p)
  (let ((float-output-format (concat "%." (int-to-string p) "f")))
    (format "%s" (float n))))

(defun latex-spread-contains-char (s c)
  (let ((len (length s))
        (i 0)
        (found nil))
    (while (and (not found) (< i len))
      (if (char-equal (elt s i) c)
          (setq found t)
        (setq i (+ i 1))))
    found))

;; ----------------------------------------------------------------------
;; Font support for FSF19
;; ----------------------------------------------------------------------

(defun latex-spread-fontify-cell (val-start val-end cell-end)
  (add-text-properties val-start val-end '(face bold))
  (add-text-properties (+ 1 val-end) cell-end '(face italic))
)

;; ----------------------------------------------------------------------
;; Debugging and error reporting
;; ----------------------------------------------------------------------

(defvar latex-spread-debugging nil "*Debugging for latex-spreadsheet 
recalculations") 

(defun latex-spread-debug (&rest args)
  (if latex-spread-debugging
      (progn
        (save-window-excursion
          (switch-to-buffer "*Spread-LaTeX-Debug*")
          (goto-char (point-max))
          (insert (apply 'format args))
          (insert "\n")
        ))))

(defun latex-spread-error (m)
  (error "Spreadsheet error: %s" m))

(defun latex-spread-warning (m)
  (message "Warning: %s" m)
  (beep)
  (sit-for 2))

;; ----------------------------------------------------------------------
;; latex-spread.el END
;; ----------------------------------------------------------------------
