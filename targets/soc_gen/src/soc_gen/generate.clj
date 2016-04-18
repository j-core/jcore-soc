(ns soc-gen.generate
  (:require
   [clojure.string :as s]
   [soc-gen
    [vmagic :as v]
    [errors :as errors]
    [iobufs :as iobufs]
    [devices :as devices]
    [parse :as parse]
    c-header
    device-tree
    irq]
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
   (v/use-clause (str "work.config.all"))
   (v/use-clause (str "work.clk_config.all"))])

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

(defn- instantiate-device [design device label bus-signals all-ports port-overrides generic-overrides ring-elems]
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

           ;; ring bus in ports
           (mapcat
            (fn [port]
              (let [{:keys [stall word]} (get ring-elems (:id port))]
                [[(str (:id port) ".stall") (or stall v/std-logic-0)]
                 [(str (:id port) ".word") (or word (case (:id (:type port))
                                                      "rbus_8b" (v/constant "IDLE_8B" nil)
                                                      "rbus_9b" (v/constant "IDLE_9B" nil)))]]))
            (filter #(and (:ring-bus %) (= (:dir %) :in)) (vals ports)))

           ;; ring bus out ports
           (->> (vals ports)
                (filter #(and (:ring-bus %) (= (:dir %) :out)))
                (mapcat
                 (fn [port]
                   (let [{:keys [stall word]} (get ring-elems (:id port))]
                     [(when stall [(str (:id port) ".stall") stall])
                      (when word [(str (:id port) ".word") word])])))
                (filter identity))

           (instantiate-ports design {:type :device :id (:name device)} (:ports device) all-ports)

           port-overrides)

          ;; determine ports that are unassigned
          check-ports (remove :ring-bus (vals (:ports entity)))
          missing-ports (set/difference (apply hash-set (map :id check-ports))
                                        (apply hash-set (map first port-assigns)))
          inst ((instantiate-factory dev-cls)
                label
                (sort-by first port-assigns)
                (sort-by first (merge (:user-generics device) generic-overrides)))]
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

(defn- device-addr-prefixes
  "Returns a map from device name to a string like
  \"1010101111100000\" which is the left-most bits of the data address
  that must match to select the device.

  If the simple? is true, the returned addresses strings are
  simplified by removing trailing, right-most bits that don't serve to
  distinguish between devices. This allows the address decoding logic
  to consider fewer bits in the address, but means devices can be
  mirrored in adjacent parts of memory."

  [devices device-classes simple?]
  (let [prefixes
        (->> devices
             (map (fn [dev]
                    (let [addr (zero-pad-bin (:base-addr dev) 32)
                          ;; remove trailing bits that are used inside the
                          ;; device and not to distinguish between devices
                          left-bit (:left-addr-bit (get device-classes (:class dev)))
                          ;; left-bit is the left-most bit used by the
                          ;; device, so left-bit + 1 is the number of bits
                          ;; that don't distinguish between devices
                          addr (.substring addr 0 (- 32 left-bit 1))]
                      [(:name dev) addr])))
             (filter identity)
             (into {}))]
    (if simple?
      ;; simplify by removing trailing bits that don't distinguish
      ;; between devices
      (letfn [(trim-suffix [full-prefix prefix node]
                (cond
                  (string? node)
                  {:name node :prefix full-prefix}

                  (= 1 (count node))
                  (let [[k n] (first node)]
                    (trim-suffix full-prefix (str prefix k) n))

                  :else
                  (->> node
                       (map (fn [[k n]]
                              [(str prefix k) (trim-suffix (str full-prefix prefix k) "" n)]))
                       (into {}))))]
        (let [trie
              (reduce
               (fn [trie [name addr]]
                 (assoc-in trie addr name))
               {}
               prefixes)]

          (->>
           (trim-suffix "" "" trie)
           (tree-seq
            #(not (contains? % :name))
            vals)
           (filter :name)
           (map (juxt :name :prefix))
           (into {}))))
      prefixes)))

(defn- create-decode-fn [devices-enum devices-literals devices device-classes device-prefixes]
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
                  (v/set-comments
                   (v/return-stmt (get devices-literals (:name trie)))
                   (format "%08X-%08X"
                           (:base-addr trie)
                           (+ (:base-addr trie)
                              (dec (bit-shift-left 2 (:left-addr-bit trie))))))
                  (let [[left-prefix left-trie] (extract-prefix (dissoc trie \1))
                        [right-prefix right-trie] (extract-prefix (dissoc trie \0))
                        check-left left-prefix
                        check-right right-prefix
                        ;; Add the following two lines to simplify the
                        ;; decode logic and only include enough tests
                        ;; to differentiate between devices in this
                        ;; design. However, this can mirror the same
                        ;; device in memory multiple times.
                        ;;check-left (if (:name left-trie) "0" left-prefix)
                        ;;check-right (if (:name right-trie) "1" right-prefix)
                        ]
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
               (assoc-in trie (get device-prefixes (:name dev))
                         (-> dev
                             (select-keys [:name :base-addr])
                             (assoc :left-addr-bit
                                    (:left-addr-bit (get device-classes (:class dev)))))))
             {}
             devices)
            ;;_ (clojure.pprint/pprint trie)

            base-addrs (map (juxt :name :base-addr) devices)

            [prefix trie] (extract-prefix trie)
            ]
        ;;(println "PREFIX:\n" \" prefix \")
        ;;(print-ifs (.length prefix) trie)
        #_(doseq [dev (sort-by :base-addr devices)]
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

(defn- create-device-enables-fn [enables-type devices-literals devices device-classes device-prefixes]
  (let [addr (v/variable "addr" (v/std-logic-vector 32))
        enables (v/variable "enables" enables-type (v/agg-others (v/std-logic-literal 0)))
        device-by-name (into {} (map (fn [dev] [(:name dev) dev]) devices))
        assigns
        (map (fn [[name enum-val]]
               (let [assign
                     (v/varassign (v/array-elem enables enum-val) (v/std-logic-literal 1))]
                 (if-let [dev (device-by-name name)]
                   (let [prefix (.substring (get device-prefixes name) 4)]
                     (v/if-stmt
                      (v/v= (v/slice-downto addr 27 (- 28 (.length prefix)))
                            (v/literal prefix))
                      assign))
                   assign)))
             devices-literals)]
    (let [func
          (-> (v/func-body "decode_device_enables" enables-type [(v/id addr) (.getType addr)])
              (v/add-declarations [enables])
              (v/add-all v/statements
                         (v/set-comments
                          assigns
                          "Assumes addr(31 downto 28) = x\"a\"."
                          "Address decoding closer to CPU checks those bits.")
                         (v/return-stmt enables)))]
      func)))

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

(defn- generate-periph-bus-muxes [design]
  (let [global-signals (:global-signals design)
        internal-ports (filter-signal-ports global-signals :device "_internal")
        ports
        (reduce
         (fn [ports bus]
           (assoc ports bus
                  (zipmap
                   [:out :in]
                   (map (comp :signal :port internal-ports)
                        [(str bus "_periph_dbus_i") (str bus "_periph_dbus_o")]))))
         {}
         (keys (:peripheral-buses design)))


        {connected true
         disconnected false}
        (group-by val (:peripheral-buses design))

        connected (set (map first connected))
        disconnected (set (map first disconnected))

        create-bus-signals
        (fn [bus]
          (let [{:keys [in out]} (val (first ports))]
            {:out  (v/signal (str bus "_periph_dbus_i") (.getType out))
             :in (v/signal (str bus "_periph_dbus_o") (.getType in))}))

        mux-architectures
        (group-by :entity
                  (filter #(and (= :architecture (:type %))
                                (.startsWith (:entity %) "multi"))
                          (:vhdl-data design)))

        instantiate-mux
        (fn [label arch m1 m2 slave]
          (v/instantiate-arch
           label
           (v/libify-arch (v/vobj (first (mux-architectures arch))) "work")
           [["clk" (:signal (global-signals "clk_sys"))]
            ["rst" (:signal (global-signals "reset"))]
            ["m1_i" (:out m1)]
            ["m1_o" (:in m1)]
            ["m2_i" (:out m2)]
            ["m2_o" (:in m2)]
            ["slave_i" (:out slave)]
            ["slave_o" (:in slave)]]))

        muxes {:master-bus (ports "cpu0")
               :statements []
               :decls []}
        muxes
        (if (set/superset? connected #{"cpu0" "cpu1"})
          (let [bus (create-bus-signals "cpu01")]
            (-> muxes
                (assoc :master-bus bus)
                (update-in [:decls] into (vals bus))
                (update-in [:statements] conj
                           (instantiate-mux
                            "cpus_mux"
                            "multi_master_bus_mux"
                            (:master-bus muxes)
                            (ports "cpu1")
                            bus))))
          muxes)
        muxes
        (if (connected "dmac")
          (let [bus (create-bus-signals "cpudm")]
            (-> muxes
                (assoc :master-bus bus)
                (update-in [:decls] into (vals bus))
                (update-in [:statements] conj
                           (instantiate-mux
                            "dmac_mux"
                            "multi_master_bus_muxff"
                            (:master-bus muxes)
                            (ports "dmac")
                            bus))))
          muxes)
        ;; loop back the disconnected buses
        muxes
        (update-in muxes [:statements] conj
                   (v/set-comments
                    (map
                     (fn [bus]
                       (v/cond-assign (:out (ports bus))
                                      (v/func-call-pos
                                       (v/func-dec "loopback_bus" v/std-logic)
                                       (:in (ports bus)))))
                     disconnected)
                    "Disconnected peripheral buses"))]
    muxes))

(defn- generate-devices [design desc]
  (let [global-signals (:global-signals design)
        pbus-mux
        (generate-periph-bus-muxes design)
        
        devices (merge (:devices design) (:extra-devices desc))
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
                               (v/enum-type "rbus_8b")
                               [Standard/INTEGER])
        rb-9b-array
        (v/unconstrained-array "bus_array_9b"
                               (v/enum-type "rbus_9b")
                               [Standard/INTEGER])
        ;; create ring signals
        rings
        (->> (:rings design)
             (map-indexed
              (fn [ring-i {:keys [bus-width ring]}]
                (let [bus-range (v/range-to 0 (count ring))
                      sig (v/signal (str "rbus_" ring-i)
                                    (v/index-subtype-indication
                                     (case bus-width
                                       8 rb-8b-array
                                       9 rb-9b-array)
                                     [bus-range]))
                      ring-elems
                      (->>
                       ring
                       (mapcat
                        (fn [i {:keys [device ports]}]
                          (let [{:keys [in out]} ports
                                bus (v/array-elem sig i)
                                bus-next (v/array-elem sig (inc i))]
                            [[[device (:id out) :stall]
                              (v/rec-elem bus "stall")]
                             [[device (:id in) :word]
                              (v/rec-elem bus "word")]
                             [[device (:id in) :stall]
                              (v/rec-elem bus-next "stall")]
                             [[device (:id out) :word]
                              (v/rec-elem bus-next "word")]]))
                        (range))
                       (into {}))]
                  {:ring-index ring-i
                   :signals [sig]
                   ;; set the stall and word signals at the extremes
                   ;; of the ring bus
                   :stmts [(v/cond-assign
                            (v/rec-elem
                             (v/array-elem sig 0)
                             "word")
                            (v/constant (case bus-width
                                          8 "IDLE_8B"
                                          9 "IDLE_9B") nil))
                           (v/cond-assign
                            (v/rec-elem
                             (v/array-elem sig (count ring))
                             "stall")
                            v/std-logic-0)]
;;                   :devices devs
                   :ring-elems ring-elems}))))

        ring-elems
        (reduce
         (fn [elems [k v]]
           (assoc-in elems k v))
         {}
         (mapcat :ring-elems rings))

        ;; data bus support
        ;; ignore devices without data bus ports
        data-bus-devices
        (filter #(:data-bus (:entity (device-classes (:class %)))) (vals devices))

        dev-names
        (->> data-bus-devices
             (map :name)
             sort
             (apply vector "none"))
        devices-enum (apply v/enum-type "device_t"
                            (s/upper-case (first dev-names))
                            (map #(s/upper-case (str "DEV_" %)) (rest dev-names)))
        device-literals (zipmap dev-names (.getLiterals devices-enum))
        enables-type (v/constrained-array "data_bus_enables_t" v/std-logic
                                          [(v/range-to (v/attr devices-enum "left")
                                                       (v/attr devices-enum "right"))])
        dev-enables (v/signal "dev_enables" enables-type)
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

        device-prefixes (device-addr-prefixes data-bus-devices device-classes
                                              (case (get-in design [:system :data-bus-decode] :simple)
                                                :simple true
                                                :exact false))
        decode-fn (create-decode-fn devices-enum device-literals data-bus-devices
                                    device-classes device-prefixes)
        enables-fn (create-device-enables-fn enables-type device-literals data-bus-devices
                                             device-classes device-prefixes)
        devices
        (->>
         devices
         (map
          (fn [[name dev]]
            (let ;; create bus signals for this device
                [dev-literal (get device-literals name)
                 ;; flip in/out to be relative to device
                 bus-signals
                 (when dev-literal
                   {:out (v/array-elem (:in bus-signals) dev-literal)
                    :in (v/array-elem (:out bus-signals) dev-literal)})]
              [name
               (assoc dev
                 :inst (instantiate-device design dev
                                           (device-label dev)
                                           bus-signals
                                           global-signals
                                           (get (:port-overrides desc) name)
                                           (get (:generic-overrides desc) name)
                                           (get ring-elems (:name dev))))])))
         (into {}))

        active-dev (v/signal "active_dev" devices-enum)

        arch
        (-> (v/architecture "impl" entity)
            (v/add-declarations
             (map
              (comp :signal global-signals)
              (:devices (:signal-locations design)))
             (:decls pbus-mux)
             (when-let [ring-sigs (seq (mapcat :signals rings))]
               (concat
                [rb-8b-array rb-9b-array]
                ring-sigs))
             [devices-enum
              active-dev
              #_enables-type
              #_dev-enables]
             decls
             [decode-fn
              #_enables-fn]
             (:declarations desc))
            (v/add-all v/statements
                       (:statements pbus-mux)
                       (v/set-comments
                        [(v/cond-assign active-dev
                                        (v/func-call-pos decode-fn
                                                         (v/rec-elem (:in (:master-bus pbus-mux)) "a")))
                         (v/cond-assign (:out (:master-bus pbus-mux))
                                        (v/array-elem (:in bus-signals) active-dev))
                         #_(v/cond-assign dev-enables
                                        (v/func-call-pos enables-fn
                                                         (v/rec-elem (:in (:master-bus pbus-mux)) "a")))
                         (let [dev (v/constant "dev" nil)]
                           (-> (v/for-gen "bus_split" "dev" (v/range-to (v/attr devices-enum "left")
                                                                        (v/attr devices-enum "right")))
                               (v/add-all v/statements
                                          (v/cond-assign (v/array-elem (:out bus-signals) dev)
                                                         (v/func-call-pos
                                                          (v/func-dec "mask_data_o"
                                                                      StdLogic1164/STD_LOGIC)
                                                          (:in (:master-bus pbus-mux))
                                                          (v/func-call-pos
                                                             (v/func-dec "to_bit"
                                                                         StdLogic1164/STD_LOGIC)
                                                             (v/v= dev
                                                                   active-dev))
                                                          #_(v/array-elem dev-enables dev))))))]
                        "multiplex data bus to and from devices")
                       (let [none (get device-literals "none")]
                         (v/cond-assign
                          (v/array-elem (:in bus-signals) none)
                          (v/func-call-pos
                           (v/func-dec "loopback_bus" (.getType (:out bus-signals)))
                           (v/array-elem (:out bus-signals) none))))
                       (v/set-comments
                        (mapcat :stmts rings)
                        "Set stall and word signals at the ends of ring buses")
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

                       (:statements desc)))]

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
                    ["data_bus_pack"]
                    (mapcat
                     #(mapcat :pkgs (vals (:ports %)))
                     (vals devices))))))
                entity
                arch)]))

(defn generate-top [design desc]
  (let [global-signals (:global-signals design)

        instantiations
        (->> (:top-entities design)
             (sort)
             (map
              (fn [[label entity]]
                ((instantiate-factory entity)
                 label
                 (sort
                  (instantiate-ports design {:type :top :id label}
                                     (:ports entity) global-signals))
                 (sort (:user-generics entity))))))
        
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

(defn generate-pad-ring [design desc]
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
           ((case (:dir pin)
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
              [(v/lib-clause "unisim")
               (v/use-clause "unisim.vcomponents.all")])]

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

(def hdr-comment
  ["******************************************************************"
   "******************************************************************"
   "******************************************************************"
   "This file is generated by soc_gen and will be overwritten next time"
   "the tool is run. See soc_top/README for information on running soc_gen."
   "******************************************************************"
   "******************************************************************"
   "******************************************************************"])

(defn spit-vhdl [f content]
  (with-open [w (jio/writer f)]
    (VhdlOutput/toWriter content w)))

(defn- create-plugin [name]
  (case name
    "device_tree" (soc-gen.device-tree/->DeviceTreePlugin)
    "board.h" (soc-gen.c-header/->CHeaderPlugin)
    "aic1" (soc-gen.irq/->AIC1Plugin)
    "aic2" (soc-gen.irq/->AIC2Plugin)
    nil))

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
     (let [plugins
           (reduce
            (fn [plugins n]
              (if-let [p (create-plugin n)]
                (conj plugins p)
                (do
                  (errors/add-error (str "Unknown plugin name \"" n "\""))
                  plugins)))
            []
            (:plugins design))
           _ (when (errors/dump)
               (throw (Exception. "Cannot instantiate plugins.")))

           design (preprocess-design design)

           ;; call pregen on all plugins
           [plugins design]
           (reduce
            (fn [[plugs design] p]
              (let [[p design] (soc-gen.plugins/on-pregen p design)]
                [(conj plugs p) design]))
            [[] design]
            plugins)

           _ (when (errors/dump)
               (throw (Exception. "Plugin failed.")))

           plugin-gen
           (fn [plugins design file-id file-desc]
             (reduce
              (fn [desc p]
                (soc-gen.plugins/on-generate p design file-id desc))
              file-desc
              plugins))

           desc (plugin-gen plugins design :devices
                            {:port-overrides {}
                             :generic-overrides {}
                             :declarations []
                             :statements []
                             :extra-devices {}})
           [design devices-vhd] (generate-devices design desc)

           desc (plugin-gen plugins design :top {})
           [design top-vhd] (generate-top design desc)

           desc (plugin-gen plugins design :pad-ring {})
           [design pad-vhd] (generate-pad-ring design desc)

           files {"devices.vhd" devices-vhd
                  "soc.vhd" top-vhd
                  "pad_ring.vhd" pad-vhd}]

       (doseq [[name content] files]
         (if content
           (apply v/set-comments (seq (v/elements content)) hdr-comment)))
       (doseq [[name content] files]
         (if content
           (do
             (println "Writing" name)
             (spit-vhdl (jio/file directory name) content))
           (errors/add-warning (str "Failed to generate " name))))

       ;; allow plugins to generate files
       (let [extra-files
             (reduce
              (fn [files plugin]
                (into
                 files
                 (for [{file-id :id file-name :name
                        :as desc}
                       (soc-gen.plugins/file-list plugin)]

                   (let [desc (plugin-gen plugins design file-id file-name)]
                     {:id file-id
                      :name file-name
                      :buildmk? (get desc :buildmk? false)
                      :content
                      (soc-gen.plugins/file-contents plugin design file-id desc)}))))
              []
              plugins)]

         (doseq [{file-name :name
                  content :content} extra-files]
           (if content
             (do
               (println "Writing" file-name)
               (spit (jio/file directory file-name) content))
             (errors/add-warning (str "Failed to generate " file-name))))

         (let [f "build.mk"]
           (println "Writing" f)
           (spit (jio/file directory f)
                 (s/join
                  "\n"
                  (concat
                   ["# This file is generated by soc_gen and will be overwritten next time"
                    "# the tool is run. See soc_top/README for information on running soc_gen."]
                   (map #(str "$(VHDLS) += " %)
                        (concat
                         (keys files)
                         (map :name
                              (filter :buildmk? extra-files))))
                   ;; empty string to get final \n
                   [""]))))))
     (not (errors/dump)))))
