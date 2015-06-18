(ns soc-gen.main
  (:require
   clojure.stacktrace
   [watchtower.core :as watch]
   [soc-gen.core :as core]
   [clojure.java.io :as jio])
  (:use [clojure.tools.cli :refer [parse-opts]])
  (:gen-class))

(def cli-options
  [["-r" "--regen" "Watches the file for changes and reruns the generator when it changes"]
   ["-h" "--help"]])

(defn -main [& args]
  ;;(println "OPTIONS" (parse-opts args cli-options))
  (let [{:keys [options arguments summary errors]} (parse-opts args cli-options)]
    (cond
     errors
     (do (doseq [e errors] (println e)) (System/exit 1))

     (not= 1 (count arguments))
     (do (println "Invalid arguments. Expect a single board name.") (System/exit 1))

     (:help options)
     (do (println summary) (System/exit 0))

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
                  (catch Exception e (clojure.stacktrace/print-stack-trace e))))]

       (if (:regen options)
         (watch/watcher
          [board-dir]
          (watch/rate 500)
          (watch/file-filter (fn [f] (= (.getName f) file-name)))
          (watch/on-change
           go))
         (System/exit (if (go nil) 0 1)))))))
