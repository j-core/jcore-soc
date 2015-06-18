(ns soc-gen.errors
  "Utility for collecting and printing errors"
  (:refer-clojure :exclude [test]))

(def ^:dynamic ^{:private true} *errors* nil)

(defn- contains-errors? [errors]
  (boolean (some (comp #{:error} :level) errors)))

(defn error? []
  (boolean
   (when-let [errors *errors*]
     (contains-errors? @errors))))

(defn warning? []
  (boolean
   (when-let [errors *errors*]
     (some (comp #{:warning} :level) @errors))))

(defn- default-print-err [e]
  (println
   (str
    (case (:level e)
      :warning "WARN"
      :error "ERR")
    ":")
   (:msg e)))

(defn level-counts []
  (when-let [errors *errors*]
    (let [counts
          (->> @errors
               (map :level)
               frequencies)]
      (when (seq counts)
        counts))))

(defn dump
  ([] (dump default-print-err))
  ([pr-fn]
     (boolean
      (when-let [errors *errors*]
        (let [errs @errors]
          (doseq [e errs]
            (pr-fn e))
          (reset! errors [])
          (seq errs)
          (contains-errors? errs))))))

(defn clear []
  (when-let [errors *errors*]
    (reset! errors [])))

(defn- add [level msg opts]
  (when-let [errors *errors*]
    (swap! errors conj (assoc opts :msg msg :level level))
    nil))

(defn add-warning [msg & {:as m}]
  (add :warning msg m))

(defn add-error [msg & {:as m}]
  (add :error msg m))

(defmacro wrap-errors [& body]
  `(binding [*errors* (atom [])]
    ~@body))

(defn test []
  (wrap-errors
   (add-error "whoops")
   (println "error?" (error?))
   (dump)))
