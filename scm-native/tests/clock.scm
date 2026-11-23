;; current-second and current-jiffy count from the Unix epoch, as on the JVM
(import (scheme base) (scheme write) (scheme time))
(write (list (> (current-second) 1.7e9)
             (> (current-jiffy) 1700000000000000)
             (< (abs (- (current-second) (/ (current-jiffy) (jiffies-per-second)))) 1.0)))
(newline)
