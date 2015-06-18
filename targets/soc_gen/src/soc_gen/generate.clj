(ns soc-gen.generate
  (:require
   [clojure.string :as s]
   [soc-gen
    [vmagic :as v]
    [errors :as errors]
    [iobufs :as iobufs]
    [devices :as devices]
    [parse :as parse]]
   [clojure.java.io :as jio]
   [clojure.set :as set]
   [clojure.math.combinatorics :as comb]
   clojure.stacktrace)
  (:use [clojure.core.match :only (match)])
  (:import
   de.upb.hni.vmagic.output.VhdlOutput
   [de.upb.hni.vmagic.builtin
    Standard
    NumericStd
    StdLogic1164
    StdLogicArith
    StdLogicSigned
    StdLogicUnsigned]))

(def ^{:private true} std-uses
  [(v/lib-clause "ieee")
   StdLogic1164/USE_CLAUSE
   NumericStd/USE_CLAUSE
   (v/use-clause (str "work.config.all"))])

(defn- device-label
  ([dev]
     (if (nil? (:name dev))
       (println "Device has no :name" dev))
     (let [dev-name (or (:name dev) (:class dev))]
       (s/lower-case (name dev-name))))
  ([dev ring-name ring-i node-i]
     (s/lower-case
      (s/join
       "_"
       (filter identity
               ["ringdev" ring-i (name ring-name) node-i (device-label dev)])))))

(defn- make-uses [pkg-names]
  (->> pkg-names
       distinct
       sort
       (map #(v/use-clause (str "work." % ".all")))))

(defn- instantiate-ports [design ctx ports signals]
  (filter
   identity
   (for [[name port] ports]
     ;; grab signal from port-contexts in case the signal or value
     ;; were changed for the global signal
     (let [port (merge
                 port
                 (:port (some #(when (= (:id (:port %)) name) %)
                              ((:port-contexts design) ctx))))]
       (cond
        (:open? port) [name nil]
        (number? (:value port)) [name (v/num-val (v/vobj (:type port)) (:value port))]
        (symbol? (:value port)) [name (v/literal (:value port))]
        (:global-signal port)
        [name (:signal (get signals (:global-signal port)))])))))

(defn- instantiate-factory
  "Returns a factory function for instantiating an entity object in
  vhdl based on an entity from the design"
  [dev-cls]
  (let [[inst-fn thing]
        (match dev-cls
               {:instantiate-component? true}
               [v/instantiate-component (v/component (:id (:entity dev-cls)))]
               {:architecture arch}
               [v/instantiate-arch (v/libify-arch (v/vobj arch) "work")]
               {:configuration config}
               [v/instantiate-config (v/libify-config (v/vobj config) "work")])]
    (fn [arg & args]
      (apply inst-fn arg thing args))))

(defn- instantiate-device [design device label bus-signals all-ports]
  (if-let [dev-cls (get (:device-classes design) (:class device))]
    (let [entity (:entity dev-cls)
          config-name (or (:configration device) (:configs dev-cls))
          ports (:ports entity)
          port-assigns
          (concat
           ;; data bus ports
           (when-let [in (first (filter #(= :in (:data-bus %)) (vals ports)))]
             [[(:id in) (:in bus-signals)]])
           (when-let [out (first (filter #(= :out (:data-bus %)) (vals ports)))]
             [[(:id out) (:out bus-signals)]])
           (instantiate-ports design {:type :device :id (:name device)} (:ports device) all-ports)
           (if-let [irqs-port (:signal (get all-ports "irqs"))]
             (let [irq (:irq device)]
               (->> ports
                    (filter (comp :irq? val))
                    (map
                     (fn [[name port]]
                       [name (if irq (v/array-elem irqs-port irq))]))))))

          ;; determine ports that are unassigned
          missing-ports (set/difference (apply hash-set (keys (:ports entity)))
                                        (apply hash-set (map first port-assigns)))
          inst ((instantiate-factory dev-cls)
                label
                (sort port-assigns)
                (sort (:user-generics device)))]
      (when (seq missing-ports)
        (let [port-list (s/join ", " missing-ports)]
          (errors/add-warning (str "Missing ports for device " label ": " port-list))
          (v/set-comments inst (str "Missing ports: " port-list))))
      inst)
    (do
      (errors/add-warning (str "Unable to instantiate entity " label))
      (v/set-comments
       (v/instantiate-component label (v/component (:class device)) [])
       (str "WARNING: Device \"" (:class device) "\" is unknown")))))

(defn- filter-signals-by-context
  [context-sets & types]
  (let [possible-sets
        (->> types
             (map #(if (keyword? %) [%] %))
             (apply comb/cartesian-product)
             (map #(set (filter identity %)))
             set)]
    (mapcat context-sets possible-sets)))

(defn- zero-pad-bin [x n]
  (let [s (Long/toString x 2)]
    (str (apply str (repeat (- n (.length s)) \0)) s)))

(defn- create-decode-fn [devices-enum devices-literals devices device-classes]
  (let [addr (v/variable "addr" (v/std-logic-vector 32))]
    (letfn [(extract-prefix
              ;; Simplifies a trie by removing all the outer maps that
              ;; have only one option, either 0 or 1. Returns a prefix
              ;; string which is the concatenated single trie keys and
              ;; returns the inner trie with the prefix maps removed
              [trie]
              (loop [prefix "" trie trie]
                (if (= 1 (count trie))
                  (let [[k v] (first trie)]
                    (recur (str prefix k) v))
                  [prefix trie])))
            (build-cond
              ;; Returns addr(n downto n-3) = "1001" boolean conditions
              [index ^String expect]
              (if (= 1 (.length expect))
                (v/v= (v/array-elem addr index)
                      (if (= \0 (first expect))
                        StdLogic1164/STD_LOGIC_0
                        StdLogic1164/STD_LOGIC_1))
                (v/v= (v/slice-downto addr index
                                      (inc (- index (.length expect))))
                      (v/literal expect))))
            (build-ifs [offset trie]
              (let [index (- 31 offset)]
                (if (:name trie)
                  (v/return-stmt (get devices-literals (:name trie)))
                  (let [[left-prefix left-trie] (extract-prefix (dissoc trie \1))
                        [right-prefix right-trie] (extract-prefix (dissoc trie \0))
                        check-left (if (:name left-trie) "0" left-prefix)
                        check-right (if (:name right-trie) "1" right-prefix)]
                    (if (and (= check-left "0") (= check-right "1"))
                      ;; avoid unnecessary elsif for simple if 0 or 1 test
                      (v/if-stmt
                       (build-cond index check-left)
                       (build-ifs (+ offset (.length left-prefix)) left-trie)
                       (build-ifs (+ offset (.length right-prefix)) right-trie))
                      (v/if-stmt
                       (build-cond index check-left)
                       (build-ifs (+ offset (.length left-prefix)) left-trie)
                       (build-cond index check-right)
                       (build-ifs (+ offset (.length right-prefix)) right-trie)))))))

            ;; debugging function for printing contents of a trie
            #_(print-ifs [offset trie]
              (if (:name trie)
                (println (str (apply str (repeat offset " "))) (:name trie))
                (let [[left-prefix left-trie] (extract-prefix (dissoc trie \1))
                      [right-prefix right-trie] (extract-prefix (dissoc trie \0))]

                  (if-let [name (:name left-trie)]
                    (println (str (apply str (repeat offset " ")) \0) name)
                    (do
                      (println (str (apply str (repeat offset " ")) left-prefix))
                      (print-ifs (+ offset (.length left-prefix)) left-trie)))
                  (if-let [name (:name right-trie)]
                    (println (str (apply str (repeat offset " ")) 1) name)
                    (do
                      (println (str (apply str (repeat offset " ")) right-prefix))
                      (print-ifs (+ offset (.length right-prefix)) right-trie))))))]
      (let [trie
            (reduce
             (fn [trie dev]
               (assoc-in trie (zero-pad-bin (:base-addr dev) 32) dev))
             {}
             (vals devices))
            base-addrs (map (juxt :name :base-addr) (vals devices))

            [prefix trie] (extract-prefix trie)
            ]
        ;;(println "PREFIX:" prefix)
        ;;(print-ifs (.length prefix) trie)
        #_(doseq [dev (sort-by :base-addr (vals devices))]
          (println (zero-pad-bin (:base-addr dev) 32) (:name dev)))

        (let [func
              (-> (v/func-body "decode_address" devices-enum [(v/id addr) (.getType addr)])
                  (v/add-all v/statements
                             (v/set-comments
                              (if (<= (.length prefix) 4)
                                (build-ifs (.length prefix) trie)
                                (v/if-stmt
                                 (build-cond 27 (.substring prefix 4))
                                 (build-ifs (.length prefix) trie)))
                              "Assumes addr(31 downto 28) = x\"a\"."
                              "Address decoding closer to CPU checks those bits.")
                             (v/return-stmt (first (.getLiterals devices-enum)))))]
          func)))))

(defn- filter-signal-ports
  "Return a map of ports that match a given context in the signals"
  ([signals type]
     (filter-signal-ports signals type nil))
  ([signals type id]
     (let [filter-fn
           (if id
             #(= (:context %) {:type type :id id})
             #(= (:type (:context %)) type))]
       (->> (for [sig (vals signals)
                  :let [sig-no-ports (dissoc sig :ports)]
                  port (:ports sig)]
              (assoc sig :port port))
            (filter (comp filter-fn :port))
            (map (fn [p] [(:id (:port p)) p]))
            (into {})))))

(defn- generate-devices [design]
  (let [global-signals (:global-signals design)

        ;; data bus and irqs ports are special signals created on an
        ;; _internal device. Pull them out to assign directly.
        [data-out-port data-in-port
         cpu1-out-port cpu1-in-port
         irqs-port]
        (map #(:port (get (filter-signal-ports global-signals :device "_internal") %))
             ["cpu0_periph_dbus_i" "cpu0_periph_dbus_o"
              "cpu1_periph_dbus_i" "cpu1_periph_dbus_o"
              "irqs"])

        devices (:devices design)
        device-classes (:device-classes design)
        entity
        (reduce
         (fn [entity [name dir]]
             ((case dir
                :in v/add-in-ports
                :out v/add-out-ports)
              entity [(:signal (global-signals name))]))
         (v/entity "devices")
         (:top-devices (:signal-locations design)))

        rb-8b-array
        (v/unconstrained-array "bus_array_8b"
                               (v/enum-type "rbus_word_8b")
                               [Standard/INTEGER])
        rb-9b-array
        (v/unconstrained-array "bus_array_9b"
                               (v/enum-type "rbus_word_9b")
                               [Standard/INTEGER])
        ;; create ring signals
        rings
        (->> (:rings design)
             (map-indexed
              (fn [ring-i [ring-name ring]]
                (let [n (count (:nodes ring))
                      bus-range (v/range-to 0 n)]
                  [ring-name
                   (assoc ring
                     :data-sig
                     (v/signal (s/join "_" ["bus" (name ring-name) "data"])
                               (v/index-subtype-indication
                                (case (:width ring)
                                  8 rb-8b-array
                                  9 rb-9b-array)
                                [bus-range]))
                     :stall-sig
                     (v/signal (s/join "_" ["bus" (name ring-name) "stall"])
                               (v/std-logic-vector bus-range)))])))
             (into {}))

        ;; data bus support
        dev-names (apply vector "none" (sort (keys devices)))
        devices-enum (apply v/enum-type "device_t"
                            (s/upper-case (first dev-names))
                            (map #(s/upper-case (str "DEV_" %)) (rest dev-names)))
        device-literals (zipmap dev-names (.getLiterals devices-enum))

        [decls
         bus-signals]
        (let [in-type (v/constrained-array "data_bus_i_t" (v/sub-type "cpu_data_i_t" nil)
                                   [(v/range-to (v/attr devices-enum "left")
                                                (v/attr devices-enum "right"))])
              out-type (v/constrained-array "data_bus_o_t" (v/sub-type "cpu_data_o_t" nil)
                                   [(v/range-to (v/attr devices-enum "left")
                                                (v/attr devices-enum "right"))])
              in-bus (v/signal "devs_bus_i" in-type)
              out-bus (v/signal "devs_bus_o" out-type)]
          [[in-type out-type in-bus out-bus]
           {:in in-bus
            :out out-bus}])

        decode-fn (create-decode-fn devices-enum device-literals devices device-classes)

        devices
        (->>
         devices
         (map
          (fn [[name dev]]
            (let ;; create bus signals for this device
                [dev-literal (get device-literals name)
                 ;; flip in/out to be relative to device
                 bus-signals
                 {:out (v/array-elem (:in bus-signals) dev-literal)
                  :in (v/array-elem (:out bus-signals) dev-literal)}]
              [name
               (assoc dev
                 :inst (instantiate-device design dev
                                           (device-label dev)
                                           bus-signals global-signals))])))
         (into {}))

        loopback-bus (v/func-dec "loopback_bus" (.getType (:signal cpu1-in-port)))
        active-dev (v/signal "active_dev" devices-enum)
        arch
        (-> (v/architecture "impl" entity)
            (v/add-declarations
             (map
              (comp :signal global-signals)
              (:devices (:signal-locations design)))
             ;;[rb-8b-array rb-9b-array]
             #_(v/set-comments
              (mapcat
               (juxt :data-sig :stall-sig)
               (vals rings))
              "ring bus signals -- Currently unused until devices are connected by ring bus")
             [devices-enum
              active-dev]
             decls
             [decode-fn])
            (v/add-all v/statements
                       (v/set-comments
                        [(v/cond-assign active-dev
                                        (v/func-call-pos decode-fn
                                                         (v/rec-elem (:signal data-in-port) "a")))
                         (v/cond-assign (:signal data-out-port)
                                        (v/array-elem (:in bus-signals) active-dev))
                         (let [dev (v/constant "dev" nil)]
                           (-> (v/for-gen "bus_split" "dev" (v/range-to (v/attr devices-enum "left")
                                                                        (v/attr devices-enum "right")))
                               (v/add-all v/statements
                                          (v/cond-assign (v/array-elem (:out bus-signals) dev)
                                                         (v/func-call-pos
                                                          (v/func-dec "mask_data_o"
                                                                      StdLogic1164/STD_LOGIC)
                                                          (:signal data-in-port)
                                                          (v/func-call-pos
                                                           (v/func-dec "to_bit"
                                                                       StdLogic1164/STD_LOGIC)
                                                           (v/v= dev
                                                                 active-dev)))))))]
                        "multiplex data bus to and from devices")
                       (v/set-comments
                        (v/cond-assign (:signal cpu1-out-port)
                                       (v/func-call-pos
                                        loopback-bus
                                        (:signal cpu1-in-port)))
                        "second CPU's bus is not used currently")
                       (let [none (get device-literals "none")]
                         (v/cond-assign
                          (v/array-elem (:in bus-signals) none)
                          (v/func-call-pos
                           loopback-bus
                           (v/array-elem (:out bus-signals) none))))
                       (map :stmt (mapcat :nodes (vals rings)))
                       (v/set-comments
                        (map (comp :inst val)
                             (sort-by
                              ;; sort devices by id with ids that end
                              ;; in a number sorted numerically
                              (fn [[n _]]
                                (if-let [[_ word num] (re-matches #"([^0-9]+)([0-9]+)" n)]
                                  [word (Long/parseLong num)]
                                  [n 0]))
                              devices))
                        "Instantiate devices")

                       ;; determine which irqs aren't assigned and
                       ;; assign '0' to them
                       (when irqs-port
                         (v/set-comments
                          (map
                           #(v/cond-assign
                             (v/array-elem (:signal irqs-port) %)
                             StdLogic1164/STD_LOGIC_0)
                           (sort (set/difference (set (range (:num-irq (meta irqs-port))))
                                                 (set (filter identity (map :irq (vals devices)))))))
                          "Ununsed irqs"))))]

    [(assoc design
       :device-entity entity
       :device-arch arch)
     (v/add-all (v/vhdl-file) v/elements
                std-uses
                (map
                 #(v/use-clause (str "work." % ".all"))
                 (sort
                  (distinct
                   (concat
                    [#_"ring_bus_pack" "data_bus_pack"]
                    (mapcat
                     #(mapcat :pkgs (vals (:ports %)))
                     (vals devices))))))
                entity
                arch)]))

(defn generate-top [design]
  (let [global-signals (:global-signals design)

        instantiations
        (map
         (fn [[label entity]]
           ((instantiate-factory entity)
            label
            (sort
             (instantiate-ports design {:type :top :id label}
                                (:ports entity) global-signals))
            (sort (:user-generics entity))))
         (:top-entities design))
        
        devices-inst
        (v/instantiate-arch
         "devices"
         (v/libify-arch (:device-arch design) "work")
         (sort
          (map (fn [[n p]] [n (:signal (global-signals n))])
               (:top-devices (:signal-locations design)))))

        entity
        (reduce
         (fn [entity [name dir]]
             ((case dir
                :in v/add-in-ports
                :out v/add-out-ports)
              entity [(:signal (global-signals name))]))
           (-> (v/entity "soc"))
           (:padring-top (:signal-locations design)))

        arch
        (-> (v/architecture "impl" entity)
            (v/add-declarations
             (->> (vals (:top-entities design))
                  (filter :instantiate-component?)
                  (map (comp v/vobj :entity))
                  distinct
                  (map v/component))
             (map
              (comp :signal global-signals)
              (:top (:signal-locations design))))
            (v/add-all v/statements
                       instantiations
                       devices-inst
                       (v/set-comments
                        (map
                         (fn [[sig-name signal]]
                           (v/cond-assign (:signal signal) (v/zero-val (:signal signal))))
                         (filter-signal-ports global-signals :top "_zero"))
                        "Zero out unused signals")))]
    [(assoc design
       :top-entity entity
       :top-arch arch)
     (v/add-all (v/vhdl-file) v/elements
                std-uses
                (make-uses (:signals-uses design))
                entity
                arch)]))

(defn- pad-space-right [^String s len]
  (str s (s/join (repeat (- len (.length s)) \ ))))

(defn- create-tsmc-io-components []
  (v/set-comments
   (for [drive-strength ["0204" "0408" "0812" "1216"]
         pull-up [true false]
         schmitt [true false]
         slew-rate [true false]]
     (-> (v/component (str "P"
                           (if slew-rate "R" "D")
                           (if pull-up "U" "D")
                           "W"
                           drive-strength
                           (when schmitt "S")
                           "CDG"))
         (v/add-in-ports
          (map #(v/signal % v/std-logic)
               ["DS" "OEN" "I" "PE" "IE"]))
         (v/add-out-ports
          (map #(v/signal % v/std-logic)
               ["C"]))
         (v/add-inout-ports
          (map #(v/signal % v/std-logic)
               ["PAD"]))))
   "TSMC I/O Cells"))

(defn generate-pad-ring [design]
  (let [global-signals (:global-signals design)
        context-sets (:context-sets design)
        pins (:pins (:pins design))
        pins (map
              (fn [pin]
                (let [sig-name (str "pin_" (:net pin))]
                  (-> pin
                      (assoc
                          :sig-name sig-name
                          :sig (v/signal sig-name StdLogic1164/STD_LOGIC))
                      (assoc-in [:attrs :loc] (:pad pin)))))
              pins)
        pins-map (into {} (map (fn [pin] [(:net pin) pin]) pins))
        pio-stmts
        (let [po (:signal (get global-signals "po"))
              pi (:signal (get global-signals "pi"))
              pio-part-fn
              (fn [sub-idx val]
                (if (integer? val)
                  (v/num-val v/std-logic val)
                  (let [pin (:pin val)
                        pin (if (string? pin)
                              pin
                              (nth pin sub-idx))]
                    (:sig (get pins-map pin)))))
              pio-fn
              (fn [idx sub-idx val]
                (let [pi (v/array-elem pi idx)
                      po (v/array-elem po idx)
                      [in out name]
                      (if (integer? val)
                        [val nil nil]
                        [(:in val) (:out val) (:name val)])
                      in (if in (pio-part-fn sub-idx in))
                      out (if out (pio-part-fn sub-idx out))
                      stmts (filter identity
                                    [(v/cond-assign pi (or in po))
                                     (if out (v/cond-assign out po))])]
                  (if name
                    (v/set-comments stmts name)
                    stmts)))]
          (->> (:pio (:system design))
               (mapcat
                (fn [[idx val]]
                  (if (integer? idx)
                    [[idx 0 val]]
                    (map vector (range (first idx) (inc (second idx))) (range) (repeat val)))))
               (sort-by first)
               (mapcat #(apply pio-fn %))
               (filter identity)))

        top-inst
        (v/instantiate-arch
         "soc"
         (v/libify-arch (:top-arch design) "work")
         (sort
          (map (fn [sig] [(:id sig) (:signal sig)])
               ;; any signal that crosses between padring and top
               (filter-signals-by-context
                context-sets
                [:pin :padring :expose] [:pin :padring :expose] [:pin :padring :expose]
                [:top :device] [:top :device]))))

        port-contexts (:port-contexts design)

        other-insts
        (->> (:padring-entities design)
             (map
              (fn [[id entity]]
                ((instantiate-factory entity)
                 id
                 (sort
                  (instantiate-ports design {:type :padring :id id}
                                     (:ports entity) global-signals))
                 (sort (:user-generics entity)))))
             (sort-by #(.getLabel %)))

        sub-signal-expression
        (fn [exp part-list]
          (if part-list
            (loop [base-signal exp
                   exp nil
                   part-list part-list]
              (if (seq part-list)
                (let [part (first part-list)
                      [field idx] (if (vector? part) part
                                      [part nil])
                      exp (if exp
                            (v/rec-elem exp field)
                            base-signal)
                      exp (if idx
                            (v/array-elem exp idx)
                            exp)]
                  (recur base-signal exp (rest part-list)))
                exp))
            exp))

        update-pin-signals
        (fn [pin invert-signals]
          (reduce
           (fn [[pin invert-signals stmts] [dir name-key]]
             (if-let [{:keys [signal-name element-name]} (get-in pin [dir name-key])]
               (let [signal (:signal (global-signals signal-name))
                     signal (sub-signal-expression signal element-name)]
                 (if (get-in pin [dir :invert])
                   (let [n-name (str "pad_"
                                     (if element-name
                                       (s/join "_" (flatten element-name))
                                       signal-name)
                                     "_n")
                         n-signal (invert-signals n-name)
                         ;; create and assign inverted signal if new
                         [n-signal n-assign] (if n-signal
                                               [n-signal []]
                                               (let [n-signal (v/signal n-name v/std-logic)]
                                                 [n-signal
                                                  (if (= dir :in)
                                                    [(v/cond-assign signal (v/v-not n-signal))]
                                                    [(v/cond-assign n-signal (v/v-not signal))])]))
                         invert-signals (assoc invert-signals n-name n-signal)]
                     [(assoc-in pin [dir name-key :exp] n-signal)
                      invert-signals
                      (into stmts n-assign)])
                   [(assoc-in pin [dir name-key :exp] signal) invert-signals stmts]))

               [(if-let [value (get-in pin [dir :value])]
                  (assoc-in pin [dir name-key :exp] (v/num-val v/std-logic value))
                  pin)
                invert-signals stmts]))
           [pin invert-signals []]
           (comb/cartesian-product
            [:in :out :out-en]
            devices/pin-info-sig-names)))

        [pins invert-signals invert-stmts]
        (reduce
         (fn [[pins invert-signals stmts] pin]
           (let [[pin invert-signals new-stmts]
                 (update-pin-signals pin invert-signals)]
             [(conj pins pin) invert-signals (into stmts new-stmts)]))
         [[] {} []]
         pins)

        iob (iobufs/iobufs-factory (:target design))

        [internal-signals iobufs]
        (->> pins
             ;; group together differential pins pairs
             (group-by (fn [pin]
                         (let [in (:diff (:in pin))
                               out (:diff (:out pin))]
                           (if in
                             [:diff-in (:signal-name (:name (:in pin)))]
                             (if out
                               [:diff-out (:signal-name (:name (:out pin)))]
                               nil)))))

             ;; move the list of normal pins up to the level of the
             ;; list of differential pins
             (mapcat
              (fn [[[diff-dir sig-name] pins]]
                (if diff-dir
                  [{:type diff-dir :pins pins}]
                  (map (fn [pin] {:type :single :pin pin}) pins))))

             (reduce
              (fn [[internal-signals statements] pin-info]
                (let [{new-internal :internal-signals
                       new-statements :statements}
                      (case (:type pin-info)
                        :diff-in
                        (apply iobufs/create-ibuf-differential
                               iob internal-signals (sort-by (comp :diff :in) (:pins pin-info)))
                        :diff-out
                        (apply iobufs/create-obuf-differential
                               iob internal-signals (sort-by (comp :diff :out) (:pins pin-info)))
                        :single
                        (let [pin (:pin pin-info)]
                          (match pin
                                 ;; pin buffers can be disabled and
                                 ;; should be connected directly instead
                                 {:buff false :in in}
                                 {:internal-signals {}
                                  :statements [(v/cond-assign (get-in in [:name :exp]) (:sig pin))]}

                                 {:buff false :out out}
                                 {:internal-signals {}
                                  :statements [(v/cond-assign (:sig pin) (get-in out [:name :exp]))]}

                                 {:in in :out out :out-en out-en}
                                 (iobufs/create-iobuf iob internal-signals pin)

                                 {:out out :out-en out-en}
                                 (iobufs/create-obuft iob internal-signals pin)

                                 {:out out}
                                 (iobufs/create-obuf iob internal-signals pin)

                                 {:in in}
                                 (iobufs/create-ibuf iob internal-signals pin))))]
                  (apply v/set-comments new-statements
                         (:name (:pin pin-info))
                         (map :name (:pins pin-info)))
                  [(merge internal-signals new-internal)
                   (into statements new-statements)]))
              [{} []]))

        pin-attrs
        (let [pins (map (fn [pin]
                          (update-in pin [:attrs]
                                     (fn [attrs]
                                       (->>
                                        ;; remove non-attributes from pin attrs
                                        (dissoc attrs
                                                :drive :iostandard :diff_term
                                                :opendrain? :speed :pull :slew)
                                        ;; remove attributes with nil values
                                        (map (fn [[k v]] (when-not (nil? v) [k v])))
                                        (filter identity)
                                        (into {})))))
                        pins)]
          (concat
           ;; declare attributes first
           (->> pins
                (mapcat (comp keys :attrs))
                (map name)
                set
                sort
                (map #(v/attr-dec
                       %
                       ;; hacky, but use a fake enum type to
                       ;; refer to string type
                       (v/enum-type "string"))))
           (let [;; find max length of attribute and port names so vhdl
                 ;; can be aligned with spaces
                 attr-max-len
                 (apply max 0
                        (->> pins
                             (mapcat (comp keys :attrs))
                             (map (comp count name))))
                 sig-max-len
                 (apply max 0 (map (comp count :sig-name) pins))]
             (v/set-comments
              (->> pins
                   (sort-by :sort)
                   (mapcat
                    (fn [pin]
                      (->> (:attrs pin)
                           (map
                            (fn [[constraint value]]
                              (v/attr-spec
                               (pad-space-right (name constraint) attr-max-len)
                               [(pad-space-right (:sig-name pin) sig-max-len)] (str value)))
                            )))))
              "Pin attributes"))))

        flatten-record
        (fn flatten-record [type]
          (if (= (:type type) :record)
            (mapcat
             (fn [[field t]]
               (map #(update-in % [:path] conj field) (flatten-record t)))
             (:fields type))
            [{:type (parse/extract-type (v/resolve-type (v/vobj type) {}))}]))

        expose-sigs
        (->> (filter-signals-by-context
              context-sets
              :expose
              [:top :device :padring])
             (mapcat
              (fn [sig]
                (map
                 (fn [{:keys [path type]}]
                   (let [n (get (:expose-signals design) (:id sig))
                         n (if (or (nil? n) (= :same n))
                             (:id sig)
                             n)]
                     {:pin (v/signal
                            (s/join "_" (apply vector n path))
                            (v/vobj type))
                      :direct?
                      (and (or (= n (:id sig))) (empty? path))
                      :exp (if (seq path) (apply v/rec-elem (:signal sig) path) (:signal sig))
                      :dir (:dir (first (filter #(= (:type (:context %)) :expose) (:ports sig))))}))
                 (flatten-record (:type sig)))))
             (sort-by #(v/get-id (:pin %))))

        entity (v/entity "pad_ring")
        ;; add pin ports
        entity
        (reduce
         (fn [entity pin]
           ((case (if (= (:target design) :tsmc)
                    ;; treat all pins as inout for asic because IO
                    ;; cell PAD is inout
                    :inout
                    (:dir pin))
              :in v/add-in-ports
              :out v/add-out-ports
              :inout v/add-inout-ports
              nil (fn [entity _] entity))
            entity [(:sig pin)]))
         entity
         pins)

        ;; add ports for exposed signals
        entity
        (reduce
         (fn [entity expose-sig]
           ((case (:dir expose-sig)
              :in v/add-out-ports
              :out v/add-in-ports)
            entity [(:pin expose-sig)]))
         entity
         expose-sigs)

        expose-stmts
        (map
         (fn [{:keys [pin dir exp direct?]}]
           (when-not direct?
             (case dir
               :in (v/cond-assign pin exp)
               :out (v/cond-assign exp pin))))
         expose-sigs)

        ;; Some exposed pins go directly to the ports instead of via
        ;; signals in the padring. Create a set of these port names to
        ;; avoid creating signals for them.
        direct-expose-sigs
        (->> expose-sigs
             (filter :direct?)
             (map (comp v/get-id :pin))
             set)

        arch
        (-> (v/architecture "impl" entity)
            (v/add-declarations
             pin-attrs
             (when (= (:target design) :tsmc)
               (create-tsmc-io-components))
             (v/set-comments
              (->> (vals (:padring-entities design))
                   (filter :instantiate-component?)
                   (map (comp v/vobj :entity))
                   distinct
                   (map v/component))
              "Components for other verilog modules instantiated")
             (map
              (comp :signal global-signals)
              (filter (complement direct-expose-sigs)
                      (:padring (:signal-locations design))))
             (vals invert-signals)
             (vals internal-signals))
            (v/add-all v/statements
                       (v/set-comments expose-stmts "Expose some signals directly")
                       top-inst
                       other-insts
                       pio-stmts
                       invert-stmts
                       iobufs))

        uses (concat
              (when-not (= (:target design) :tsmc)
                [(v/lib-clause "unisim")
                 (v/use-clause "unisim.vcomponents.all")]))]

    [design
     (v/add-all (v/vhdl-file) v/elements
                std-uses
                (make-uses (:signals-uses design))
                uses
                entity
                arch)]))


(defn- categorize-signals
  "We are generating three entities: padring, top, and devices.
Determine which signals are declared as signals in each entitiy.
Decide which signals are ports of the top and devices entities and
whehter they are in or out ports."
  [designs]
  (let [context-sets (:context-sets designs)

        find-src-context
        (fn [signal]
          (let [contexts
                (->> (:ports signal)
                     (filter #(= :out (:dir %)))
                     (map #(let [ctx (:type (:context %))]
                             ;; translate :pin to :padring so there
                             ;; is a unique context per entity
                             (get {:pin :padring} ctx ctx)))
                     set)]
            (if (not= (count contexts) 1)
              (throw (Exception. (str "Signal " (:id signal)
                                      " must be output from a single context: "
                                      (s/join " " contexts))))
              (first contexts))))]

    (assoc designs
      :signal-locations
      {:padring-top
       (sort
        (->>
         (filter-signals-by-context
          context-sets
          [:pin :padring :expose] [:pin :padring :expose] [:pin :padring :expose]
          [:top :device] [:top :device])
         (map (fn [s] [(:id s) ({:pin :in
                                :padring :in
                                :expose :in
                                :device :out
                                :top :out}
                               (find-src-context s))]))))

       :top-devices
       (sort (map (fn [s] [(:id s) ({:pin :in
                                    :padring :in
                                    :expose :in
                                    :device :out
                                    :top :in}
                                   (find-src-context s))])
                  (filter-signals-by-context
                   context-sets
                   [:pin :padring :expose :top]
                   [:pin :padring :expose :top]
                   [:pin :padring :expose :top]
                   [:pin :padring :expose :top]
                   :device)))

       :padring
       (sort (map :id (filter-signals-by-context
                       context-sets
                       [:pin :padring :expose]
                       [:pin :padring :expose]
                       [:pin :padring :expose]
                       [:top :device nil]
                       [:top :device nil])))

       :top
       (sort (map :id (filter-signals-by-context
                       context-sets
                       :top
                       [:device nil])))

       :devices
        (sort (map :id (filter-signals-by-context
                        context-sets
                        :device)))})))

(defn- preprocess-design
  "augments a design with any preprocessing that would be useful when
  generating the various vhl files"
  [design]

  (let [design
        (-> design
            ;; create vhdl signals for each port and global signal
            (update-in
             [:global-signals]
             #(reduce
               (fn [sigs [id sig]]
                 (assoc sigs id
                        (assoc sig
                          :signal (v/signal id (v/vobj (:type sig)))
                          :ports (mapv (fn [port]
                                         (assoc port
                                           :signal (v/signal (:id port) (v/vobj (:type port)))))
                                       (:ports sig))
                          ;; collect all context types that a
                          ;; signal is used in
                          :context-types (set (map (comp :type :context) (:ports sig))))))
               {}
               %)))

        ;; separate from above -> design statement because below
        ;; one reads modified global-signals
        design
        (-> design
            ;; create use clauses for all signal types
            (assoc :signals-uses
              (distinct (mapcat :pkgs (vals (:global-signals design)))))

            ;; map port context to signal and individual ports.
            ;; Useful for connecting ports of an entity to signals.
            (assoc :port-contexts
              (->> (:global-signals design)
                   (mapcat (fn [[_ signal]]
                             (map #(assoc signal :port %) (:ports signal))))
                   (group-by (comp :context :port))))

            ;; map sets of context types to lists of signals that
            ;; contain only those types. Useful for determining
            ;; which signals go between the padring, top and
            ;; devices entities
            (assoc :context-sets
              (->> (:global-signals design)
                   vals
                   (group-by
                    (fn [signal]
                      (set (map (comp :type :context) (:ports signal)))))))

            (update-in [:zero-signals] identity))

        design (categorize-signals design)]
    design))

(defn spit-vhdl [f content]
  (with-open [w (jio/writer f)]
    (VhdlOutput/toWriter content w)))

(defn generate-design [design directory]
  (let [directory (jio/file directory)]
    (when (and (.exists directory) (not (.isDirectory directory)))
      (throw (Exception. (str "Cannot store design. "
                              (.getPath directory)
                              " exists and is not a directory"))))

    (when-not (or (.isDirectory directory) (.mkdirs directory))
      (throw (Exception. (str "Cannot store design. Cannot create directory "
                              (.getPath directory)))))
    ;; TODO: should we delete existing files in the directory?
    (errors/wrap-errors
     (let [design (preprocess-design design)

           [design devices-vhd] (generate-devices design)
           [design top-vhd] (generate-top design)
           [design pad-vhd] (generate-pad-ring design)
           files {"devices.vhd" devices-vhd
                  "soc.vhd" top-vhd
                  "pad_ring.vhd" pad-vhd}]
       (doseq [[name content] files]
         (if content
           (do
             (println "Writing" name)
             (spit-vhdl (jio/file directory name) content))
           (errors/add-warning (str "Failed to generate " name))))
       (let [f "build.mk"]
         (println "Writing" f)
         (spit (jio/file directory f)
               (s/join (mapcat vector (map #(str "$(VHDLS) += " %) (keys files)) (repeat "\n"))))))
     (not (errors/dump)))))
