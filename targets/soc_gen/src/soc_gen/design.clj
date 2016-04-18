(ns soc-gen.design
  "Support loading the design description from one or more files"
  (:use [clojure.core.match :only (match)])
  (:require
   clojure.edn
   [clojure.java.io :as jio]
   [clojure.string :as s]
   [baum.core :as baum]))

(defn- remove-by-filter
  "Returns a function for filtering objects based on a :remove-by key
  pair"
  [k vs]
  (let [vs (set vs)]
    (cond
      (nil? k)
      (fn [x] (not (contains? vs x)))
      (vector? k)
      (fn [x] (not (contains? vs (get-in x k))))
      :else
      (fn [x] (not (contains? vs (get x k)))))))

(defn- custom-merge [a b]
  (cond
   ;; recursively merge maps
   (and (map? a) (map? b))
   (let [a (if-let [rem (:remove b)]
             ;; support removing specific keys from map a before merge
             (apply dissoc a rem)
             a)
         a (if-let [rem-by (:remove-by b)]
             ;; support removing items from a based on the value of
             ;; a key or a seq of keys within each item
             (reduce
              (fn [a [k vs]]
                (filter (remove-by-filter k vs) a))
              a
              rem-by)
             a)
         b (dissoc b :remove :remove-by)]
     (->> (merge-with custom-merge a b)))
   ;; concat vectors
   (and (vector? a) (vector? b))  (into a b)
   ;; maps merged into vectors with special {:remove [] :insert {}
   ;; :insert []} command maps
   (and (vector? a) (map? b))
   (let [{rem :remove :keys [insert append remove-by]} b
         rem (set rem)
         a
         (->> a
              ;; remove indices in the remove seq
              (map vector (range))
              (remove #(rem (first %))))
         ;; remove items from a based on the value of a key or a seq
         ;; of keys within each item
         a
         (reduce
          (fn [a [k vs]]
            (filter (comp (remove-by-filter k vs) second) a))
          a
          remove-by)
         a
         (->> a
              ;; insert values
              (concat insert)
              (sort-by first)
              (mapv second))]
     ;; append values
     (into a append))
   :else b))

(defn- vectorize [v]
  (if (vector? v) v [v]))

(defn- import-multiple [v importer]
  (->> v
       vectorize
       (map importer)
       (remove nil?)
       (reduce custom-merge)))

(defn- update-relative-files [cwd files]
  (mapv
   (fn [f]
     (if (or (string? f) (instance? java.io.File f))
       (let [f (jio/file f)]
         (if (.isAbsolute f) f (jio/file cwd f)))
       f))
   (vectorize files)))

(defn- sub-include [f opts]
  (let [f (.getCanonicalFile (jio/file (:cwd opts) f))
        opts (assoc opts :cwd (.getParentFile f))
        path (.getPath f)]
    (if (contains? (:previous-files opts) path)
      (throw (Exception.
              (str "Loop detected in design includes. Already parsed \"" path "\""))))
    (baum/read-config f (update-in opts [:previous-files] conj path))))

(defn- import-config [v opts]
  (import-multiple
   v
   #(if (or (nil? %) (map? %)) % (sub-include % opts))))

(defn- custom-include-reduce [m v opts]
  (import-config (conj (vectorize v) m) opts))

(baum/defreader select-reader [v opts]
  (let [{:keys [file only exclude]} v]
    (let [only (remove nil? (vectorize only))
          exclude (remove nil? (vectorize exclude))
          data (sub-include file opts)
          data (if (empty? only) data (select-keys data only))]
      (apply dissoc data exclude))))

(baum/defreader file-reader [v opts]
  (let [f (jio/file v)]
    (if (.isAbsolute f)
      f
      (jio/file (:cwd opts) f))))

(defn- files-reader [v]
  (let [f (fn [v opts]
            (let [[path & [re]] (vectorize v)
                  ;; make path relative before calling real files reader
                  v [(first (update-relative-files (:cwd opts) path)) re]
                  [f v]
                  (:baum.core/invoke (baum/files-reader v))]
              ;; invoke real files reader and make any results absolute
              (update-relative-files (:cwd opts) (f v opts))))]
    {:baum.core/invoke [f v]}))

(defn- make-reader-relative
  "Wrap an existing reader whose values are files with one that
  considers paths relative to the directory of the current config
  file"
  [sym]
  (let [f (fn [v opts]
            (let [[f v]
                  (:baum.core/invoke
                   (((:readers opts) sym)
                    (update-relative-files (:cwd opts) v)))]
              (f v opts)))]
    (fn [v]
      {:baum.core/invoke [f v]})))

(defn- make-reducer-relative
  "Wrap an existing reducer to make file paths relative to current
  config file"
  [reducer]
  (fn [m v opts]
    (reducer m (update-relative-files (:cwd opts) v) opts)))

(defn- read-edn [f]
  (sub-include f {:edn? true
                  :shorthand? true
                  :readers {'select select-reader
                            'soc-gen/import (make-reader-relative 'baum/import)
                            'soc-gen/import* (make-reader-relative 'baum/import*)
                            'baum/file file-reader
                            'baum/files files-reader}
                  :reducers {:soc-gen/include custom-include-reduce
                             :soc-gen/include* custom-include-reduce
                             :baum/override (make-reducer-relative
                                             (:baum/override (baum/default-reducers)))
                             :baum/override* (make-reducer-relative
                                              (:baum/override* (baum/default-reducers)))}
                  :aliases {'soc-gen/import 'import
                            'soc-gen/import* 'import*
                            :soc-gen/include '$include
                            :soc-gen/include* '$include*}
                  :previous-files #{}
                  :cwd "."}))

(defn- remove-nil-values [m]
  (if (map? m)
    (->> m
         ;; Remove any key->nil mappings. These are used to remove keys
         ;; from merged maps.
         (remove (comp nil? val))
         (map (fn [[k v]]
                [k (if (map? v) (remove-nil-values v) v)]))
         (into {}))
    m))

(defn load-design [file]
  (let [r (remove-nil-values (read-edn file))]
    ;;(clojure.pprint/pprint r)
    r))
