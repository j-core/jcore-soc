(ns soc-gen.core
  (:use [clojure.core.match :only (match)])
  (:require
   [clojure.java.io :as jio]
   [clojure.string :as s]
   [clojure.java.shell :as shell]
   [soc-gen devices parse generate design]))

(defn parse-pin-list
  ([] (parse-pin-list "../soc_module_1v1.pins" "IC1"))
  ([file part]
     (with-open [rdr (jio/reader file)]
       (let [lines (->> (line-seq rdr)
                        (drop-while #(not (.startsWith % part)))
                        (take-while #(not (s/blank? %)))
                        ;; remove comment lines
                        (filter #(not (.startsWith (s/trim %) "#")))
                        doall)
             ;; remove part name from the first line
             lines (conj (rest lines) (.substring (first lines) (.length part)))
             lines (filter #(not (.contains % "*** unconnected ***")) lines)
             parts (->> lines
                        (map #(s/split (s/trim %) #" +"))
                        (map (fn [[pad pin dir net]]
                               {:pad pad
                                :pin pin
                                :net (-> net
                                         s/lower-case
                                         (s/replace #"-" "_")
                                         (s/replace #"!" ""))}))
                        ;; ignore uninteresting nets
                        (filter #(not (let [net (:net %)]
                                        (or (#{"gnd" "3v3"} net)
                                            (.contains net "$") ;; ignore "N$66"
                                            (re-matches #"[0-9]v[0-9]" net))))))]
         parts))))

(defn parse-pin-names [file]
  (with-open [rdr (jio/reader file)]
    (->> (line-seq rdr)
         (filter #(not (s/blank? %)))
         (map s/trim)
         (filter #(not (.startsWith % "#")))
         (mapv (fn [net]
                 (let [[net pad]
                       (remove s/blank?
                               (s/split
                                (-> net
                                    s/lower-case
                                    (s/replace #"-" "_")
                                    (s/replace #"!" ""))
                                #"\s"))]
                   (merge {:net net} (when pad {:pad pad}))))))))

;;(def ucf  (parse-ucf-pins))
;;(def pins (parse-pin-list))
;; (doseq [pin (sort-by :net (map (fn [pin] (assoc pin :ucf (get ucf (s/lower-case (:pad pin))))) pins))] (apply println ((juxt :net :ucf) pin)))

(defn parse-ucf-pins
  ([] (parse-ucf-pins "../../../soc_hw/mcu_lib/constraints/fpga_module_v1p1/base.ucf"))
  ([file]
     (with-open [rdr (jio/reader file)]
       (let [lines (->> (line-seq rdr)
                        (map s/lower-case)
                        (map #(re-matches #"\s*net\s+([^\s]+)\s.*loc\s*=\s*([a-z][0-9]+)\s.*" %))
                        (filter identity)
                        (map (comp vec reverse rest))
                        (into {}))]
         (doall lines)))))

(defn split-pin-name [n]
  (mapv (fn [p]
          (if (Character/isDigit (first p))
            ;; zero pad all numbers
            (str
             (apply str (repeat (max 0 (- 8 (.length p))) \0))
             p)
            p))
        (re-seq #"[^0-9]+|[0-9]+" n)))

(defn compare-pins []
  (let [ucf (parse-ucf-pins)
        pins (parse-pin-list)
        pin-pairs (map (fn [pin] (assoc pin :ucf (get ucf (s/lower-case (:pad pin))))) pins)]
    (doseq [pin (sort-by (comp split-pin-name :net) pin-pairs)]
      (apply println ((juxt :net :ucf) pin)))))

(defn- delete-dir [^java.io.File file]
  ;; This is a dangerous operation. Don't recurse into subdirectories
  (println "delete" (.getPath file))
  (if (.isDirectory file)
    (doseq [f (.listFiles file)]
      (println "delete child" (.getPath f))
      (if (not (.delete f))
        (throw (Exception. (str "Cannot delete " f))))))
  (.delete file))

(defn- get-file-list [board-name]
  (if (or (s/blank? board-name) (re-find #"[\s./]" board-name))
    (println (str "Invalid board name \"" board-name "\""))
    (let [output-dir (str "soc_gen_output/" board-name)]
      ;; Delete old soc_gen output directory for this board. Have to
      ;; delete the contents of the directory first. Recursing is
      ;; dangerous, so instead explicitly delete the config sub
      ;; directory.
      (let [dir-file (jio/file "../.." output-dir)]
        (delete-dir (jio/file dir-file "config"))
        (delete-dir dir-file))
      (let [{:keys [exit out err]}
            (shell/sh "make" "-C" "../.." board-name
                      "TARGET=vhdl_list.txt"
                      "LAST_OUTPUT=false"
                      (str "REL_OUTPUT_DIR=" output-dir))]
        (println out)
        (if (= exit 0)
          (with-open [rdr (jio/reader (str "../../soc_gen_output/" board-name "/vhdl_list.txt"))]
            (doall (line-seq rdr)))
          (do
            (println (str "Failed to create vhdl file list for " board-name))
            (println err)))))))

(defn create-design
  ([] (create-design "soc_1v1_evb_2v0"))
  ([board-name]
     (let [board-dir (jio/file "../boards" board-name)
           design (soc-gen.design/load-design (jio/file board-dir "design.edn"))
           design
           (-> design
               (assoc
                 :name board-name
                 :board-dir board-dir)
               ;; validate board target
               (update-in [:target]
                          (fn [target]
                            (cond
                             (#{:tsmc :spartan6 :kintex7} target) target
                             ;; default target
                             (nil? target) :spartan6
                             :else (throw (Exception. (str "Unrecognized target " target)))))))

           ;; parse pin file
           {:keys [file part type] :or {type :pin-list}} (:pins design)
           design (cond
                   (and file part (= type :pin-list))
                   (assoc-in design [:pins :pins] (parse-pin-list file part))

                   (and file (= type :pin-names))
                   (assoc-in design [:pins :pins] (parse-pin-names file))

                   :else
                   design)

           ;; flatten vectors to make it easier to specify similar
           ;; pins and devices as subvectors
           design (reduce
                   (fn [design path]
                     (update-in design path (comp vec flatten)))
                   design
                   [[:devices]
                    [:pins :rules]
                    [:bist-chain]])

           ;; Gather the names of all entities used by the design.
           ;; These are used to limit the vhdl that is parsed.
           entities (set
                     (filter
                      identity
                      (concat
                       (for [[n v] (:padring-entities design)] (or (:entity v) n))
                       (for [[n v] (:top-entities design)] (or (:entity v) n))
                       (let [device-classes
                             (into {} (for [[n v] (:device-classes design)] [n (or (:entity v) n)]))
                             requires
                             (into {} (for [[n v] (:device-classes design)] [n (:requires v)]))]
                         (set
                          (concat
                           (for [dev (:devices design)] (device-classes (:class dev)))
                           ;; Add entities required by all the used device classes
                           (map device-classes (mapcat requires (map :class (:devices design))))))))))

           ;; force parsing of multi master buses for use in generated code
           entities (conj entities
                          "multi_master_bus_mux"
                          "multi_master_bus_muxff")

           vhdl-files (->> (get-file-list board-name)
                           (into [])
                           ;; ignore non-vhd files
                           (filter #(re-matches #".*\.vh[hd]$" %)))]
       (if (empty? vhdl-files)
         (println "No VHDL files found.")
         (let [{:keys [files data]} (soc-gen.parse/extract-all
                                     (into
                                      vhdl-files
                                      ;; Add additional VHDL files to parse list
                                      (map
                                       #(.getCanonicalPath (jio/file %))
                                       (:extra-vhdl design)))
                                     :entities entities)]
           ;; Now have information from design.edn and from parsing
           ;; the VHDL. Combine and validate this information to
           ;; produce a full design
           (if (and files data)
             (soc-gen.devices/combine-soc-description design files data)))))))

(defn generate-design
  ([design]
     (generate-design design (:board-dir design)))
  ([design output-dir]
     #_(if (nil? design)
       (throw (Exception. "Cannot generate design. Input invalid.")))
     (when design
       (soc-gen.generate/generate-design design output-dir))))

(defn go [design]
  (generate-design (create-design design)))

(defn go-all
  ([] (go-all #".*"))
  ([name-re]
   (let [names
         (->> (.listFiles (jio/file "../boards"))
              (filter (fn [f] (and (.isDirectory f)
                                  (some #(= "design.edn" (.getName %)) (.listFiles f)))))
              (map #(.getName %)))
         ignore (filter #(not (re-find name-re %)) names)
         names (sort (filter #(re-find name-re %) names))
         results (reduce
                  (fn [results board]
                    (println "Run" board)
                    (assoc results board (go board)))
                  {}
                  names)]
     {:success (sort (map key (filter val results)))
      :fail (sort (map key (filter (comp not val) results)))
      :ignore (sort ignore)})))

(defn go-all-print
  ([] (go-all-print #".*"))
  ([name-re]
   (let [{:keys [success fail ignore]} (go-all name-re)
         pr-list (fn [desc names] (when (seq names)
                              (println (count names) "builds" (str desc ":"))
                              (doseq [n names]
                                (println "   " n))))]
     (pr-list "succeeded" success)
     (pr-list "failed" fail)
     (pr-list "ignored" ignore)
     (and (boolean (seq success)) (not (boolean (seq fail)))))))
