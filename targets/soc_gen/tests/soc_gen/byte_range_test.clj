(ns soc-gen.byte-range-test
  (:require [clojure.test :refer :all]
            [soc-gen.byte-range :refer :all]))

(deftest overlap?-test
  (testing "overlap?"
    (is (overlap? [1 2] [2 3]))
    (is (overlap? [2 3] [1 2]))
    (is (overlap? [1 2] [1 2]))
    (is (overlap? [1 2] [0 1]))
    (is (overlap? [5 10] [7 8]))
    (is (overlap? [5 10] [7 12]))
    (is (overlap? [5 10] [2 6]))
    (is (overlap? [5 10] [2 12]))

    (is (not (overlap? [1 2] [3 4])))
    (is (not (overlap? [1 2] [6 9])))
    (is (not (overlap? [6 9] [15 18])))))

(deftest overlaps-test
  (testing "overlaps"
    (is (= (overlaps []) []))
    (is (= (overlaps [[1 2]]) []))
    (is (= (overlaps [[1 2] [3 4]]) []))
    (is (= (overlaps [[3 3] [3 4]]) [[3 3] [3 4]]))
    (is (= (overlaps [[3 4] [3 4]]) [[3 4] [3 4]]))
    (is (= (overlaps [[4 5] [3 4]]) [[4 5] [3 4]]))
    (is (= (overlaps [[4 5] [3 4] [6 7] [10 15] [12 13]]) [[4 5] [3 4] [10 15] [12 13]]))))

(deftest expand-test
  (testing "expand"
    (is (= (expand [1 2] 4) [0 3]))
    (is (= (expand [0 2] 4) [0 3]))
    (is (= (expand [3 6] 4) [0 7]))
    (is (= (expand [1 3] 4) [0 3]))
    (is (= (expand [1 4] 4) [0 7]))
    (is (= (expand [1 5] 4) [0 7]))))
