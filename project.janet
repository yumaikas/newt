(declare-project 
    :name "newt"
    :description "A janent project scaffolding tool"
    :author "Andrew Owen <yumaikas94@gmail.com>"
    :url "https://github.com/yumaikas/newt"
    :dependencies  [
        "path"
        "https://github.com/yumaikas/janet-errs" # Installs as err
        "https://github.com/yumaikas/janet-stringx" # Installs as stringx
        "temple"
    ]
)

(declare-source
    :source "newt.janet")

(declare-executable 
    :name "newt"
    :entry "newt.janet")
