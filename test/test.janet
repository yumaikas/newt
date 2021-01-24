 (use testament)
 (use ../newt)
 
 (deftest string/replace-pairs-works
    (assert-equal 
        (string/replace-pairs ["&" "-" "|" "-"] "a&b|c")
        "a-b-c")
 )
 
 (run-tests!)
