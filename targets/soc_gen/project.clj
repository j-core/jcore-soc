(defproject soc_gen "0.1.0-SNAPSHOT"
  :description ""
  :dependencies [[org.clojure/clojure "1.6.0"]
                 [org.clojure/core.match "0.2.2"]
                 [org.clojure/math.combinatorics "0.0.8"]
                 ;; antlr-runtime 3.2 matches vmagic-parser's dependency
                 [org.antlr/antlr-runtime "3.2"]
                 [org.clojure/tools.cli "0.3.1"]
                 [watchtower "0.1.1"]
                 [com.stuartsierra/dependency "0.1.1"]
                 [rkworks/baum "0.1.2"]]
  :java-source-paths ["lib/logic"]
  :resource-paths ["lib/vmagic-0.4-SNAPSHOT.jar"
                   "lib/vmagic-parser-0.4-SNAPSHOT.jar"]
  :main ^:skip-aot soc-gen.main
  :target-path "target/%s"
  :profiles {:uberjar {:aot :all}})
