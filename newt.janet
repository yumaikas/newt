(import path)
(import err)
(import temple)
(import spork/argparse :prefix "")

(temple/add-loader)

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
    (print "  " lice))) 

# This will be removed once all of the flags have been translated to argparse form
(comment print-help [] 
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
    --list-licenses: Lists the liscense templates that are available
    ```)
  )

(def argparse-params 
  [```
   newt - A janet project Scaffolder
   ```

   "name" {:kind :option 
           :short "n"
           :help "The name of the project to generate the stub for"}
   "author" {:kind :option 
             :short "a"
             :help "The author of the project (you, or your company)" }
   "license" {:kind :option 
             :short "l"
             :help "The license to be generated in the project" }
   "list-licenses" {:kind :flag 
                    :default false 
                    :help "List the licenses available for use in project templates"}

   ])

(def fullname-pat 
  ~{
    :main (* "Full Name" :s+ (capture (some (if-not "\n" 1))))
    })

# @task[Replace this with a version that pulls from git meat info
(defn get-user-full-name-windows [] 
  (def cmd (string "net user " (os/getenv "USERNAME")))
  (var retval nil)
  (with [f (file/popen cmd)]
    (while (def l (:read f :line))
      (when (def m (peg/match fullname-pat l))
        (set retval (m 0))
        (break))))
  retval)

(defn get-author-from-computer [] 
  (match (os/which)
    :windows (get-user-full-name-windows)
    # TODO: Add implementations for Linux and OSX
    _ nil))

(defn- ensure-project-author [opts] 
  (if-let [author (or (opts :newt/project-author)
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
  (if-let [project-name (or 
                          (opts :newt/project-name)
                          (os/getenv "PROJECT_NAME"))]
    (put opts :newt/project-name project-name)
    (err/signal 
      :newt/missing-project-info 
      "Project name isn't set. It can be set using the "
      "-n flag, or the PROJECT_NAME environment variable.")

    ))

(defn- ensure-project-license [opts] 
  (when (opts :newt/suppress-license) (break))
  (if-let [project-license 
             (license-templates 
               (or 
                 (keyword (opts :newt/project-license))
                 (keyword (os/getenv "PROJECT_LICENSE"))))]
    (put opts :newt/project-license-text project-license)
    (err/signal 
      :newt/missing-project-info 
      "Project license isn't set. It can be set using the "
      "-l flag, or the PROJECT_LICENSE environment variable.")))

(import ./templates/test.janet :as "test.janet")
(import ./templates/project.janet :as "project.janet")
(import ./templates/main.janet :as "main.janet")
(import ./templates/README.md :as "README.md")

(defn- not-path-exist [p] (= (os/stat p) nil))

(defn- subst-license [opts] 
  (def license (opts :newt/project-license-text))
  (string/replace-pairs 
    ["{{ organization }}" (opts :newt/project-author)
     "{{ project }}" (opts :newt/project-name)
     "{{ year }}" (string ((os/date (os/time) :local) :year))]
    license))

(defmacro render-spit-safe [tmpl args path] 
  ~(when (,not-path-exist ,path)
     (with [f (file/open ,path :w)]
       (with-dyns [:out f]
         (,(symbol tmpl "/render-dict") ,args)))))

(defn spit-safe [path str] 
  (when (not-path-exist path)
     (spit path str)))

(defn create-project [opts] 
  (def main-path 
    (-> 
      (string (opts :newt/project-name) ".janet") 
      (clean-path-string)))

  (render-spit-safe main.janet opts main-path)

  (spit-safe "LICENSE.md" (subst-license opts))
  (render-spit-safe README.md opts "README.md")
  (render-spit-safe project.janet opts "project.janet")

  (when (not-path-exist "test")
    (os/mkdir "test"))

  (def test-path (path/join "test" "test.janet"))
  (render-spit-safe test.janet opts test-path)

  (when (opts :newt/should-git-init)
    (os/shell "git init")))

(defn main [exename & args] 
  # dargs = Dict Args
  (def dargs (argparse ;argparse-params))
  (unless dargs (os/exit))

  (def opts 
    @{
      :newt/project-author (dargs "author")
      :newt/project-name (dargs "name")
      :newt/project-license (dargs "license")
      :newt/list-licenses (dargs "list-licenses")
      })

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




