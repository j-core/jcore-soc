(ns soc-gen.main
  (:require
   clojure.stacktrace
   [watchtower.core :as watch]
   [soc-gen.core :as core]
   [clojure.java.io :as jio]
   [clojure.string :as s])
  (:use [clojure.tools.cli :refer [parse-opts]])
  (:gen-class))

(def cli-options
  [["-r" "--regen" "Watches the file for changes and reruns the generator when it changes"]
   ["-a" "--all" "Run soc_gen on all boards"]
   ["-h" "--help"]])

(defn -main [& args]
  ;;(println "OPTIONS" (parse-opts args cli-options))
  (let [{:keys [options arguments summary errors]} (parse-opts args cli-options)]
    (cond
     errors
     (do (doseq [e errors] (println e)) (System/exit 1))

     (and (not= 1 (count arguments)) (nil? (:all options)))
     (do (println "Invalid arguments. Expect a single board name.") (System/exit 1))

     (:help options)
     (do (println summary) (System/exit 0))

     (:all options)
     (let [board (first arguments)
           {:keys [success fail ignore]}
           (if (s/blank? board)
             (core/go-all)
             (core/go-all (re-pattern (s/trim board))))
           pr-list (fn [desc names] (when (seq names)
                                     (println (count names) "builds" (str desc ":"))
                                     (doseq [n names]
                                       (println "   " n))))]
       (pr-list "succeeded" success)
       (pr-list "failed" fail)
       (pr-list "ignored" ignore)
       (System/exit (if (or (not (seq success)) (seq fail)) 1 0)))

     :else
     (let [board (first arguments)
           file-name "design.edn"
           board-dir (jio/file "../boards" board)
           go (fn [x]
                (try
                  (println "Parsing input")
                  (if-let [d (core/create-design board)]
                    (do
                      (println "Generate design")
                      (core/generate-design d))
                    (println "Parsing failed"))
                  (catch Exception e
                    (clojure.stacktrace/print-stack-trace e)
                    (println "Failed"))))]

       (if (:regen options)
         (watch/watcher
          [board-dir]
          (watch/rate 500)
          (watch/file-filter (fn [f] (= (.getName f) file-name)))
          (watch/on-change
           go))
         (System/exit (if (go nil) 0 1)))))))
