(import path)
(import err)
(import temple)

(defn string/replace-pairs [replacements str] 
  # TODO: Move this into some extended strings library
  (assert 
    (indexed? replacements) 
    (string "expected replace to be array|tuple, got " (type replacements)))
  (assert (even? (length replacements)) "Expected an even number of replacements, got an odd one")
  (var retval str)
  (each (patt subst) (partition 2 replacements)
    (set retval (string/replace-all patt subst retval)))
  retval)

(defn clean-path-string [mypath] 
  (string/replace-pairs 
    [
     # Based on https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file
     # Either remove, or change unsafe chars
     "<" ""
     ">" ""
     ":" "."
     "\"" ""
     "/" ""
     "\\" "+"
     "?" ""
     "|" "+"
     "*" "+"
     ] mypath))

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
      (table (splice (flatten it))))))

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
    ```
    newt: A Janet Project Scaffolder

    Commands/flags

    help, -h: Shows this message
    -n <name>: Sets the project name
    -a <author>: Sets the name of the author of this project. Can be a person or an organization.
    -l <license>: Sets the license to be used for the project.
    -P: Don't create a project.janet
    -R: Don't create a README.md
    -L: Don't create a license
    -T: Don't create a test folder
    -list-licenses: Lists the liscense templates that are available
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
    @["-x"]              (on :newt/change-fs args/continue)
    @["-P"]              (on :newt/suppress-project args/continue)
    @["-T"]              (on :newt/suppress-test args/continue)
    @["-R"]              (on :newt/suppress-readme args/continue)
    @["-L"]              (on :newt/suppress-license args/continue)
    @["--list-licenses"] (on :newt/list-licenses args/stop)

    @["-a" author]       (kv :newt/project-author author)
    @["-l" license]      (add-license-opt opts license)
    @["-n" name]         (kv :newt/project-name name) 

    @["-a"]              (err/signal :newt/cli-err "-a flag requires a value")
    @["-l"]              (err/signal :newt/cli-err "-l flag requires a value")
    @["-n"]              (err/signal :newt/cli-err "-n flag requires a value")
    @[flag]              (err/signal :newt/cli-err "Unknown cli flag: " flag)
    )
  )

(def fullname-pat ~{
                    :main (* "Full Name" :s+ (capture (some (if-not "\n" 1))))
                    })

(defn get-user-full-name-windows [] 
  (def cmd (string "net user " (os/getenv "USERNAME")))
  (var retval nil)
  (with [f (file/popen cmd)]
    (while (def l (:read f :line))
      (when (def m (peg/match fullname-pat l))
        (set retval (m 0))
        (break)
        )
      )
    )
  retval
  )

(defn get-author-from-computer [] 
  (match (os/which)
    :windows (get-user-full-name-windows)
    # TODO: Add implementations for Linux and OSX
    _ nil))

(defn- ensure-project-author [opts] 
  (if-let [
           author (or (opts :newt/project-author)
                      (os/getenv "AUTHOR")
                      (get-author-from-computer))]
    (put opts :newt/project-author author)
    (err/signal 
      :newt/missing-project-info 
      "Author isn't set. It can be set using the"
      " -a flag, or the AUTHOR environment variable.")
    )
  )

(defn- ensure-project-name [opts] 
  (if-let [ 
           project-name (or 
                          (opts :newt/project-name)
                          (os/getenv "PROJECT_NAME"))
           ]
    (put opts :newt/project-name project-name)
    (err/signal 
      :newt/missing-project-info 
      "Project name isn't set. It can be set using the "
      "-n flag, or the PROJECT_NAME environment variable.")

    )
  )

(defn- ensure-project-license [opts] 
  (when (opts :newt/suppress-license) (break))
  (if-let [project-license 
           (or 
             (license-templates (keyword (opts :newt/project-license)))
             (os/getenv "PROJECT_LICENSE"))]
    (put opts :newt/project-license-text project-license)
    (err/signal 
      :newt/missing-project-info 
      "Project license isn't set. It can be set using the "
      "-l flag, or the PROJECT_LICENSE environment variable.")
    )
  )

(defn- template/test.janet [opts]
  (comptime
    (def tmpl 
      (temple/create
        ```
        # Tests for {{ (args :newt/project-name) }}
        (assert false "Add some tests here, maybe import testament?")
        ```
        "newt.janet")))
  (def outbuf @"")
  (with-dyns [:out outbuf] (tmpl opts))
  outbuf)

(defn- template/project.janet [opts]
  (comptime
    (def tmpl 
      (temple/create 
        ```(declare-project 
              :name "{{ (args :newt/project-name) }}"
              :description "EDIT ME!")
        ```
        "newt.janet")))
  (def outbuf @"")
  (with-dyns [:out outbuf] (tmpl opts))
  outbuf)

(defn- template/main-file [opts]
  (comptime
    (def tmpl 
      (temple/create 
        ```
        (defn main [& args] 
          (pp args))
        ```
        "newt.janet")))
  (def outbuf @"")
  (with-dyns [:out outbuf] (tmpl opts))
  outbuf)

(defn- template/readme [opts]
  (comptime (def tmpl (temple/create
    ```
    # {{ (args :newt/project-name) }}

    ## Status
    Just started! Edit me!!!
    ```
    "newt.janet")))
  (def outbuf @"")
  (with-dyns [:out outbuf] (tmpl opts))
  outbuf)

(defn- not-path-exist [p] (= (os/stat p) nil))


(defn- subst-license [opts] 
  (def license (opts :newt/project-license-text))
  (string/replace-pairs 
    ["{{ organization }}" (opts :newt/project-author)
     "{{ project }}" (opts :newt/project-name)
     "{{ year }}" (string ((os/date (os/time) :local) :year))]
    license))

(defn create-project [opts] 
  (def main-file (template/main-file opts))
  (def main-file-path 
    (-> 
      (string (opts :newt/project-name) ".janet") 
      (clean-path-string)))

  # TODO: Read off the opts

  # Spit README
  (when (not-path-exist "README.md") 
    (spit "README.md" (template/readme opts)))
  # Spit LICENSE
  (when (not-path-exist "LICENSE.md")
    (spit "LICENSE.md" (subst-license opts)))
  # Spit out project.janet
  (when (not-path-exist "project.janet")
    (spit "project.janet" (template/project.janet opts)))

  (when (not-path-exist main-file-path)
    (spit main-file-path main-file))
  (when (not-path-exist "test")
    (os/mkdir "test"))
  (def test-path (path/join "test" "test.janet"))
  (when (not-path-exist test-path)
    (spit test-path (template/test.janet opts)))

  (when (opts :newt/should-git-init)
    (os/shell "git init")))

(defn main [exename & args] 
  (def margs (array/slice args))

  (def opts @{})
  (while (> (length margs) 0)
    (err/try* 
      (do
        (def [remove-count arg-state] (handle margs opts))
        (array/remove margs 0 remove-count)
        (when (= arg-state args/stop) (break)))

      ([:newt/cli-err msg] 
        (do 
          (eprint msg)
          (os/exit 1)))))

  (when (opts :newt/show-help) 
    (print-help)
    (break))

  (when (opts :newt/list-licenses) 
    (print-licenses)
    (break))

  (err/try* 
    (do
      (ensure-project-author opts)
      (ensure-project-name opts)
      (ensure-project-license opts))
    ([:newt/missing-project-info message] 
     (do
      (eprint message)
      (os/exit 1))))

  (create-project opts))




