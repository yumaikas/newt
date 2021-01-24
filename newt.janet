(import path)
(import err)

(defn string/replace-pairs [replacements str] 
    # TODO: Move this into some extended strings library
    (assert 
        (indexed? replacements) 
        (string "expected replace to be array|tuple, got " (type replacements)))
    (assert (even? (length replacements)) "Expected an even number of replacements, got an odd one")
    (var retval str)
    (each (patt subst) (partition 2 replacements)
        (set retval (string/replace-all patt subst retval))
    )
    retval
)

(def license-templates 
    (do
        (def l-path (path/join "license-templates" "templates"))
        (as-> 
            (os/dir l-path) it
            (map |[
                    (keyword 
                        (string/replace-pairs [".txt" "" "_" "-"]
                    $))
                    (slurp (path/join l-path $))
                ] it) 
            (table (splice (flatten it)))
        )
    )
)

(defn- print-licenses []
    (print "")
    (print "Available licenses for use:")
    (def to-print 
        (->> 
            license-templates 
            (keys) 
            (filter |(not (string/find "-header" $))) 
            (sort)))
    (each lice to-print
        (print "  " lice)
    )
) 

(defn- print-help [] 
    (print 
    ```newt: A Janet Project Scaffolder
    Commands/flags
      help, -h: Shows this message
      -n <name>: Sets the project name
      -a <author>: Sets the name of the author of this project. Can be a person or an organization.
      -l <license>: Sets the license to be used for the project.
      -P: Don't create a project.janet
      -R: Don't create a README.md
      -L: Don't create a license
      -T: Don't create a test folder
      --list-licenses: Lists the liscense templates that are available
      
      
    ```)
)

(def- args/stop @"") 
(def- args/continue @"")
(defn- handle [args opts]

    (defn- add-license-opt [opts license] 
        (if (license-templates (keyword license)) 
            (put opts :newt/project-license license)
            (err/signal :cli-err "Unknown license " license ".")
        )
        [2 args/continue]
    )
    
    (defn on [key &opt state] 
        (put opts key true)
        [1 (or state args/continue)]
    )
    (defn off [key &opt state]
        (put opts key false)
        [1 (or state args/continue)]
    )
    
    (defn kv [key val &opt state] 
        (put opts key val)
        [2 (or state args/continue)]
    )
    
    (match args
        @["help"]            (on :newt/show-help args/stop)
        @["-h"]              (on :newt/show-help args/stop)
        @["-P"]              (on :newt/suppress-project args/continue)
        @["-T"]              (on :newt/suppress-test args/continue)
        @["-R"]              (on :newt/suppress-readme args/continue)
        @["-L"]              (on :newt/suppress-license args/continue)
        @["--list-licenses"] (on :newt/list-licenses args/stop)
        @["-n" name]         (kv :newt/project-name name) 
        @["-a" author]       (kv :newt/project-author author)
        @["-l" license]      (add-license-opt opts license)
        
        @["-l"]              (err/signal :cli-err "-l flag requires a value")
        @["-a"]              (err/signal :cli-err "-a flag requires a value")
        @["-n"]              (err/signal :cli-err "-n flag requires a value")
        @[flag]              (err/signal :cli-err "Unknown cli flag: " flag)
    )
)
 
(defn main [exename & args] 
    (def margs (array/slice args))
    
    (def opts @{})
    (while (> (length margs) 0)
        (try (do
            (def [remove-count arg-state] (handle margs opts))
            (when (= arg-state args/stop) (break))
            (array/remove margs 0 remove-count)
            (error "THINGS ARE WRONG")
        )
        ([err fib] (do (match err
            [:cli-err msg] (eprint msg)
            _ (propagate err fib)
            ))
            (os/exit 1)
        ))
    )
    
    (when (opts :newt/show-help) 
        (print-help)
        (break)
    )
    (when (opts :newt/list-licenses) 
        (print-licenses)
        (break)
    )
)
