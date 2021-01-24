(declare-project 
    :name "newt"
    :description "A janent project scaffolding tool"
    :dependencies  [
        "path"
        "https://github.com/yumaikas/janet-errs" # Installs as err
        "temple"
    ]
)

(declare-source
    :source "newt.janet")

(declare-executable 
    :name "newt"
    :entry "newt.janet")
