(ns soc-gen.byte-range)

(defn overlap? [[l1 r1] [l2 r2]]
  (if (< l2 l1)
    (overlap? [l2 r2] [l1 r1])
    (or
     ;; l1=< r1=> l2=[ r2=]
     ;; <[]>
     (> r1 r2)
     ;; <[>]
     (>= r1 l2))))

(defn overlaps
  "Returns a set of the overlapping byte-ranges"
  [ranges]
  (let [ranges (map-indexed vector ranges)]
    (loop [ranges ranges
           overlaps #{}]
      (if-let [ranges (seq ranges)]
        (let [r (first ranges)
              ranges (rest ranges)
              overlapping (filter #(overlap? (second r) (second %)) ranges)]
          (recur ranges
                 (if (seq overlapping)
                   (into (conj overlaps r) overlapping)
                   overlaps)))
        (mapv second (sort-by first overlaps))))))

(defn expand
  "expand a byte-range to completely fill an aligned region. Returns
  the smallest byte-range that contains the given range and has the
  lower bound equal to N*alignment and the upper bound is equal to
  M*alignment-1."
  [[l r] alignment]
  [(* (quot l alignment) alignment)
   (dec (* (inc (quot r alignment)) alignment))])
