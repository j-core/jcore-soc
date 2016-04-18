(ns soc-gen.irq
  "Plugins for connecting aic and aic2 to the devices"
  (:require
   [clojure.string :as s]
   [clojure.set :as set]
   [soc-gen
    [vmagic :as v]
    [errors :as errors]])
  (:import
   [de.upb.hni.vmagic.object
    Constant]
   [de.upb.hni.vmagic.literal
    DecimalLiteral]))

(defn- aic1-update-devices [design desc aic-devs]
  (let [devices (:devices design)
        irqs-signals
        (into {}
              (map
               (fn [cpu]
                 [cpu (v/signal (str "irqs" cpu) (v/std-logic-vector 8) (v/agg-others v/std-logic-0))])
               (keys aic-devs)))
        irq-signals
        (apply merge
               (map
                (fn [[cpu sig]]
                  (into {} (map (fn [i]
                                  [{:cpu cpu :path [i]} (v/array-elem sig i)])
                                (range 8))))
                irqs-signals))

        ;; Find IRQ lines that are set by multiple devices. These will
        ;; be ORed together.
        dup-irqs
        (->>
         (for [[device-name device] devices
               [port-name i] (:irq device)]
           (assoc i :device device-name :port port-name))
         (group-by #(select-keys % [:cpu :irq :path]))
         (filter #(< 1 (count (val %))))
         (mapcat (fn [[_ irqs]]
                   (map-indexed
                    (fn [i irq]
                      (assoc irq
                             :i i
                             :signal
                             (v/signal (s/join "_"
                                               (concat
                                                ["irq"
                                                 (:cpu irq)]
                                                (:path irq)
                                                [(char (+ (int \a) i))]))
                                       v/std-logic)))
                    irqs))))

        ]

    (-> desc
        (update-in [:declarations] into
                   (concat
                    (map val (sort-by key irqs-signals))
                    (map :signal dup-irqs)))
        (update-in [:statements] conj
                   (v/set-comments
                    (->> dup-irqs
                         (group-by #(select-keys % [:cpu :path]))
                         (map
                          (fn [[k irqs]]
                            (v/cond-assign (get irq-signals k)
                                           (apply v/v-or (map :signal irqs))))))
                    "Combine irqs")
                   ;; determine which irqs aren't assigned and
                   ;; assign '0' to them
                   #_(let [used-irqs
                         (mapcat (comp vals :irq) (vals devices))
                         assign-unused-irqs
                         (fn [port cpu]
                           (map
                            #(v/cond-assign
                              (v/array-elem (:signal port) %)
                              v/std-logic-0)
                            (sort (set/difference
                                   (set (range (:num-irq (meta port))))
                                   (set (map :irq (filter #(= cpu (:cpu %)) used-irqs)))))))]
                     (v/set-comments
                      (concat
                       (when irqs0-port
                         (assign-unused-irqs irqs0-port 0))
                       (when irqs1-port
                         (assign-unused-irqs irqs1-port 1)))
                      "Ununsed irqs")))

        (update-in [:port-overrides]
                   (fn [overrides]
                     (let [overrides
                           (reduce
                            (fn [overrides [n device]]
                              (let [;; override irq signals for lines used
                                    ;; by this device that are shared by
                                    ;; other devices
                                    irq-signals
                                    (into irq-signals
                                          (->> dup-irqs
                                               (filter #(= n (:device %)))
                                               (map (fn [x] [(select-keys x [:port :cpu :path]) (:signal x)]))))]
                                (reduce
                                 (fn [overrides [port-name v]]
                                   (assoc-in overrides [n port-name]
                                             (let [v (select-keys v [:cpu :path])]
                                               (or (get irq-signals (assoc v :port port-name))
                                                   (get irq-signals v)))))
                                 overrides
                                 (:irq device))))
                            overrides
                            devices)]

                       ;; assign irq ports of aics
                       (reduce
                        (fn [overrides [cpu aic-name]]
                          (assoc-in overrides [aic-name "irq_i"] (get irqs-signals cpu)))
                        overrides
                        aic-devs))))

        (update-in [:generic-overrides]
                   (fn [overrides]
                     (let [t (v/std-logic-vector 8)
                           irq-paths
                           (reduce
                            (fn [paths {:keys [cpu path irq]}]
                              (assoc-in paths [cpu (first path)] irq))
                            {}
                            (mapcat (comp vals :irq) (vals devices)))]
                       (reduce
                        (fn [overrides [cpu aic-name]]
                          (let [cpu-paths (get irq-paths cpu {})]
                            (assoc-in overrides [aic-name "vector_numbers"]
                                      (apply v/pos-agg
                                             (->> (range 8)
                                                  (map #(get cpu-paths % 0))
                                                  (map #(v/num-val t %)))))))
                        overrides
                        aic-devs)))))))

(defn- set-timer-irq [design irq]
  (update-in design [:soc :dt-children]
             (fn [dt-children]
               (mapv
                (fn [[n v]]
                  [n
                   (case n
                     "timer"
                     (update-in v [:properties] conj
                                [:interrupts {:fmt :hex :v (list irq)}])
                     v)])
                dt-children))))

(defrecord AIC1Plugin []
    soc-gen.plugins/SocGenPlugin
    (on-pregen [plugin design]
      (let [;; Auto set irq and path for devices with only irq
            ;; set. This assumes a mapping between the 0-7 paths and
            ;; vector addresses (:irq).
            design (update-in design [:devices]
                              (fn [devices]
                                (->> devices
                                     (map (fn [[n d]]
                                            [n
                                             (update-in d [:irq]
                                                        (fn [irq]
                                                          (when irq
                                                            (->> irq
                                                                 (map
                                                                  (fn [[port v]]
                                                                    [port
                                                                     (if (nil? (:path v))
                                                                       (assoc v
                                                                              :path [(:irq v)]
                                                                              ;; assume vector numbers start at 0x11 based on v_irq_t of aic.vhd
                                                                              :irq (+ 0x11 (:irq v)))
                                                                       v)]))
                                                                 (into {})))))]))
                                     (into {}))))

            ;; find aic devices to find their aic ports
            aic-devs
            (filter
             #(= "aic" (:class %))
             (vals (:devices design)))

            all-irq (->> (vals (:devices design))
                         (filter :irq)
                         (mapcat (fn [dev] (map #(assoc % :dev (:name dev)) (vals (:irq dev))))))

            ;; aic.vhd's internal countdown timer
            countdown-trap 0x19

            ;; find unused trap number in 16-31 range for pit timer
            used-traps
            (set (concat
                  [countdown-trap]
                  (map :irq all-irq)))

            ;; select unused trap number for pit
            pit-trap
            (some #(when-not (contains? used-traps %) %) (range 16 32))]

        ;; ensure each AIC belongs to a cpus 0, 1, ..., num_cpu-1
        (when-not (= (set (map :cpu aic-devs)) (set (range (count aic-devs))))
          (errors/add-error (str "AIC devices are connected to unexpected cpus: " (sort (map :cpu aic-devs)))))

        ;; ensure irq paths make sense
        (doseq [{cpu :cpu dev :dev} all-irq]
          (when-not (and (integer? cpu) (>= cpu 0))
            (errors/add-error (str "Device \"" dev "\" irq connects to invalid cpu " cpu))))

        (doseq [{path :path dev :dev} all-irq]
          (if-not (and (vector? path) (= (count path) 1) (integer? (first path)) (>= (first path) 0) (< (first path) 8))
            (errors/add-error (str "Invalid irq path \"" path "\" for device \"" dev "\". Must be integer 0-7"))))

        ;; irqs with matching cpu and path must have the same irq in order to share
        (when-not (errors/error?)
          (doseq [[[cpu path] irqs]
                  (filter
                   #(not= 1 (count (second %)))
                   (group-by (juxt :cpu :path) all-irq))]
            (let [irq-nums (set (map :irq irqs))]
              (when (not= 1 (count irq-nums))
                (errors/add-error
                 (str "Multiple device irq ports connect to cpu " cpu " path " path " with different irq numbers: " (s/join ", " (sort irq-nums))))))))
        [(assoc plugin
                :aic-devs
                (->> aic-devs
                     (map (fn [dev] [(:cpu dev) (:name dev)]))
                     (into {})))
         (if pit-trap
           (set-timer-irq design pit-trap)
           design)]))
    (file-list [plugin])
    (on-generate [plugin design file-id file-desc]
      (case file-id
        :devices
        (aic1-update-devices design file-desc (:aic-devs plugin))
        file-desc))
    (file-contents [plugin design file-id file-desc]))


(defn- aic2-update-devices [design desc plugin]
  (let [devices (:devices design)
        aic-devs (:aic-devs plugin)
        null-irq (:null-irq plugin)
        irq-a-t (:irq-a-t plugin)
        all-irq-desc
        (->> (vals devices)
             (mapcat (fn [dev]
                       (map (fn [[port-name irq-desc]]
                              (assoc irq-desc :port port-name :dev (:name dev)))
                            (:irq dev)))))

        ;; signals for each aic
        direct-sigs
        (->>
         (keys aic-devs)
         (map (fn [cpu]
                [cpu (v/signal (str "irq_s" cpu) (v/std-logic-vector 8) (v/agg-others v/std-logic-0))]))
         (into {}))
        grp-sigs
        (->>
         (keys aic-devs)
         (map (fn [cpu]
                [cpu (v/signal (str "irq_grp" cpu) (v/vobj irq-a-t) (v/agg-others (Constant. "NULL_IRQ" v/std-logic)))]))
         (into {}))
        sub-grp-sigs
        (->>
         all-irq-desc
         (filter #(= (count (:path %)) 2))
         (map (fn [irq] [(:cpu irq) (first (:path irq))]))
         set
         sort
         (map (fn [[cpu grp]]
                [[cpu grp] (v/signal (str "irq_grp" cpu "_glue" grp) (v/std-logic-vector 5) (v/agg-others v/std-logic-0))]))
         (into {}))

        tglue-names
        (->> sub-grp-sigs
             keys
             (map (fn [[cpu grp]]
                    [[cpu grp] (str (:name (aic-devs cpu)) "_tglue" grp)]))
             (into {}))]
    (-> desc
        (update-in [:declarations] into
                   (concat
                    (map val (sort-by key grp-sigs))
                    (map val (sort-by key sub-grp-sigs))
                    (map val (sort-by key direct-sigs))))
        (update-in [:extra-devices] merge
                   (->> sub-grp-sigs
                        keys
                        (map (fn [[cpu grp]]
                               (let [dev
                                     {:name (tglue-names [cpu grp])
                                      :class "aic2_tglue"
                                      :ports {"clk_sys" {:global-signal "clk_sys"}
                                              "rst_i" {:global-signal "reset"}}}]
                                 [(:name dev) dev])))
                        (into {})))
        (update-in [:port-overrides]
                   (fn [overrides]
                     (let [;; assign irq ports of aics
                           overrides
                           (reduce
                            (fn [overrides [cpu aic]]
                              (-> overrides
                                  (assoc-in [(:name aic) "irq_grp_i"] (grp-sigs cpu))
                                  (assoc-in [(:name aic) "irq_s_i"] (direct-sigs cpu))))
                            overrides
                            aic-devs)

                           ;; assign irq ports of tglue
                           overrides
                           (reduce
                            (fn [overrides [[cpu grp] sig]]
                              (let [n (tglue-names [cpu grp])]
                                (-> overrides
                                    (assoc-in [n "irq_o"] (v/array-elem (grp-sigs cpu) grp))
                                    (assoc-in [n "irqs"] sig))))
                            overrides
                            sub-grp-sigs)

                           overrides
                           (reduce
                            (fn [overrides {:keys [path cpu dev port]}]
                              (assoc-in overrides [dev port]
                                        (case (count path)
                                          1 (v/array-elem (direct-sigs cpu) (first path))
                                          2 (v/array-elem (sub-grp-sigs [cpu (first path)]) (second path)))))
                            overrides
                            all-irq-desc)]
                       overrides)))
        (update-in [:generic-overrides]
                   (fn [overrides]
                     (let [;; set generics of aic2 entities
                           overrides
                           (reduce
                            (fn [overrides {:keys [cpu path irq]}]
                              (assoc-in overrides [(:name (aic-devs cpu)) (str "IRQ_SI" (first path) "_NUM")]
                                        (v/literal (+ 64 irq))))
                            overrides
                            (filter #(= (count (:path %)) 1) all-irq-desc))

                           t (v/std-logic-vector 6)
                           ;; set generics of aic2_tglue entities
                           overrides
                           (reduce
                            (fn [overrides {:keys [cpu path irq]}]
                              (assoc-in overrides [(tglue-names [cpu (first path)]) (str "NUM_M" (second path))]
                                        (v/num-val t irq)))
                            overrides
                            (filter #(= (count (:path %)) 2) all-irq-desc))]
                       overrides))))))

(defrecord AIC2Plugin []
    soc-gen.plugins/SocGenPlugin
    (on-pregen [plugin design]
      (let [;; find aic devices to find their aic ports
            aic-devs
            (->> (vals (:devices design))
                 (filter #(= "aic2" (:class %)))
                 (map (fn [dev] [(:cpu dev) dev]))
                 (into {}))

            all-vhdl
            (into {} (map (fn [d] [((juxt :type :id) d) d]) (:vhdl-data design)))

            null-irq (all-vhdl [:constant "null_irq"])
            irq-a-t (all-vhdl [:array-type "irq_a_t"])

            all-irq (->> (vals (:devices design))
                         (mapcat (fn [dev] (map (fn [[port-name irq]] (assoc irq :dev (:name dev) :port port-name)) (:irq dev)))))

            used-traps
            (set (concat
                  ;; The aic2 entity has a generic for setting the
                  ;; trap number used for the countdown. Determine
                  ;; what numbers are being used in the current build.
                  (->> (vals aic-devs)
                       (map
                        (fn [aic]
                          (when-let [v
                                     (get
                                      (:user-generics aic)
                                      "irq_ii0_num"
                                      (get-in design [:device-classes "aic2" :entity :generics "irq_ii0_num" :default-value]))]
                            (when (instance? DecimalLiteral v)
                              (Long/parseLong (.getValue v))))))
                       (filter identity))
                  (map #(+ 64 (:irq %)) all-irq)))

            ;; select unused trap number for pit
            pit-trap
            (some #(when-not (contains? used-traps %) %) (range 64 128))]

        (when-not null-irq
          (errors/add-error "Cannot find constant NULL_IRQ"))
        (when-not irq-a-t
          (errors/add-error "Cannot find array type irq_a_t"))

        ;; ensure each AIC belongs to a cpus 0, 1, ..., num_cpu-1
        (when-not (= (set (keys aic-devs)) (set (range (count aic-devs))))
          (errors/add-error (str "AIC devices are connected to unexpected cpus: " (sort (keys aic-devs)))))

        ;; ensure irq paths make sense
        (doseq [{cpu :cpu dev :dev} all-irq]
          (when-not (and (integer? cpu) (>= cpu 0))
            (errors/add-error (str "Device \"" dev "\" irq connects to invalid cpu " cpu))))

        (doseq [{path :path dev :dev} all-irq]
          (if-not (and (vector? path) (every? integer? path)
                       (or (and (= 1 (count path)) (<= 0 (first path)) (< (first path) 8))
                           (and (= 2 (count path)) (<= 0 (first path)) (< (first path) 10)
                                (<= 0 (second path)) (< (second path) 5))))
            (errors/add-error (str "Invalid irq path \"" path "\" for device \"" dev "\". Must be integer [0-7] or [0-9 0-4]"))))

        ;; prevent multiple irqs connecting to the same aic paths
        ;; TODO: aic1 plugin supports OR-ing irqs together in the case. Should we do this too?
        (when-not (errors/error?)
          (doseq [[[cpu path] irqs]
                  (filter
                   #(not= 1 (count (second %)))
                   (group-by (juxt :cpu :path) all-irq))]
            (errors/add-error
             (str "Multiple device irq ports connect to cpu " cpu " path " path ": " (s/join ", " (map #(str (:dev %) "." (:port %)) irqs))))))
        [(assoc plugin
                :aic-devs aic-devs
                :null-irq null-irq
                :irq-a-t irq-a-t)
         (-> (if pit-trap
               (set-timer-irq design pit-trap)
               design)
             ;; set :dt-irq in each irq description to absolute vector number displayed in device_tree
             (update-in [:devices]
                        (fn [devices]
                          (->> devices
                               (map (fn [[n dev]]
                                      [n
                                       (if-let [irq (:irq dev)]
                                         (assoc dev :irq
                                                (->> irq
                                                     (map (fn [[port irq]]
                                                            [port (assoc irq :dt-irq (+ 64 (:irq irq)))]))
                                                     (into {})))
                                         dev)
                                       ]))
                               (into {})))))]))
    (file-list [plugin])
    (on-generate [plugin design file-id file-desc]
      (case file-id
        :devices
        (aic2-update-devices design file-desc plugin)
        file-desc))
    (file-contents [plugin design file-id file-desc]))
