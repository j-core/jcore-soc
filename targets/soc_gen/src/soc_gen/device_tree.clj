(ns soc-gen.device-tree
  (:require
   [clojure.string :as s]
   [soc-gen
    plugins
    [errors :as errors]]))

(def ^{:const true :private true} byte-array-type (type (byte-array 0)))
(defn- bytes? [x] (= (type x) byte-array-type))

(defn- prop-val-str
  ([val] (prop-val-str "%d" nil val))
  ([fmt bits val]
   (cond
     (number? val) (format (case fmt :hex "0x%x" :dec "%d" fmt) val)
     (string? val) (pr-str val)
     (keyword? val) (name val)
     (list? val) (str (when bits (str "/bits/ " bits " "))
                      "<" (s/join " " (map (partial prop-val-str fmt bits) val)) ">")
     (bytes? val) (str "[" (s/join " " (map (partial prop-val-str "%02x" bits) val)) "]")
     (vector? val) (s/join ", " (map (partial prop-val-str fmt bits) val))
     (map? val) (let [old-fmt fmt
                      old-bits bits
                      {:keys [label v after fmt bits]} val]
                  (s/join [(when label (str label ": "))
                           (prop-val-str (case fmt :hex "0x%x" :dec "%d" old-fmt)
                                         (or bits old-bits)
                                         v)
                           (when after (str " " after ": "))])))))

(defn- props-to-str [props]
  (for [[n v] props]
    (when n
      (let [n (cond
                (map? n)
                (let [{:keys [label v]} n]
                  (str label ": " (name v)))
                n
                (name n))
            ;; Add a comment string after property
            cmt (when (map? v)
                  (when-let [cmt (:cmt v)]
                    (str " // " cmt)))]
        (str n (when v (str " = " (prop-val-str v))) ";" cmt)))))

(defn to-str
  "Returns a string containing a device tree in dts format

  A DT node is of the form

    [name-str {:properties [ ... ]
               :children [ ... ]}]

  The properties vector contains zero or more name-value pairs,
  vectors containing a single name, or empty vectors.

  [prop-name prop-val]
  [prop-name]
  []

  The empty vector is output as a blank line between properties and is
  used only for formatting. The length one vector results in an
  property with no value.

  [\"ranges\"] => ranges;

  The prop name-value pair outputs a property with a value. The type
  of the value determines how it is output.

  [\"a\" \"a string\"] => a: \"a string\";

  [\"a\" '(1 2 3)] => a: <0x1 0x2 0x3>;

  [\"a\" [\"a string\" '(1)]] => a: \"a string\", <0x1>;

  [\"a\" (bytes [1 2 3 4])] => a: [0x01 0x02 0x03 0x04];
  "
  ([dt] (str "/dts-v1/;\n\n" (to-str 0 dt)))
  ([indent dt]
   (let [[node-name {:keys [properties children]}] dt
         ind (s/join (repeat indent "\t"))

         body
         (doall
          (concat
           (map
            (fn [x]
              (if (s/blank? x)
                "\n"
                (str ind "\t" x "\n")))
            (props-to-str properties))
           (interleave
            (repeat "\n")
            (->> children
                 (filter identity)
                 (map (partial to-str (inc indent)))))))

         lines
         (concat
          [(str ind node-name " {")]
          (when (seq body) ["\n"])
          body
          [(str (if (seq body) ind " ") "};\n")])]
     (s/join lines))))

(defn- compat-open [model]
  (str "jcore," model))

(defn- compat-closed [model]
  (str "sei," model))

#_(defn go []
  (println (to-str ["/"
    {:properties
     [["compatible" [(compat-open "j2-soc")]]
      ["#address-cells" '(1)]
      ["#size-cells" '(1)]
      ["interrupt-parent" '("&intc")]]
     :children
     [["chosen" {}]
      ["aliases" {}]
      ["memory" {:properties
                 [["device_type" "memory"]
                  ["reg" '(0, 40000000)]]}]
      ["soc" {:properties
              [["compatible" [(compat-open "js-soc") "simple-bus"]]
               ["#address-cells" '(1)]
               ["#size-cells" '(1)]
               ["ranges" nil]]
              :children
              [["aic: interrupt-controller"
                {:properties
                 [["compatible" (compat-open "js-soc-aic-0.1")]
                  ["interrupt-controller"]
                  ["#interrupt-cells" '(1)]
                  ["reg" ['(0x50041000 0x1000) '(0x50040100 0x0100)]]]}]]}]]}])))

(defn node-name [label n & addrs]
  (str (when label (str label ": "))
       n
       (when (seq addrs) (str "@" (s/join "," (map #(format "%x" %) addrs))))))

(defn- dev-to-dt [dev dev-cls-name dev-cls]
  [(node-name (:dt-label dev) (:dt-node-name dev))
   {:properties
    (concat
     (->> (:dt-props dev)
          sort
          (map
           (fn [[k v]]
             [(name k) v])))
     [["reg" {:fmt :hex :v (list (:dt-base-addr dev) (:dt-reg-width dev))
              :cmt (format "%08X-%08X" (:base-addr dev) (+ (:base-addr dev) (:dt-reg-width dev) -1))}]]
     (when-let [irq (some #(if (:dt? %) %) (vals (:irq dev)))]
       [["interrupts"
         {:fmt :hex :v (list (or (:dt-irq irq) (:irq  irq)))}]]))
    :children (concat (:dt-children dev-cls) (:dt-children dev))}])

(defn to-dt
  "Convert soc design to device tree"
  [design]

  (let [dram (get-in design [:system :dram] [0x10000000 0x8000000])
        memory
        [(node-name nil "memory" (first dram))
         {:properties
          [["device_type" "memory"]
           ["reg" {:fmt :hex :v (apply list dram)}]]}]

        devs
        (->> (:devices design)
             (filter (fn [[_ dev]]
                       (let [cls (get (:device-classes design) (:class dev))]
                         (and
                          ;; only data bus devices
                          (:data-bus (:entity cls))
                          ;; that want to have a dt node
                          (get
                           (merge (select-keys cls [:dt-node])
                                  (select-keys dev [:dt-node]))
                           :dt-node true)))))

             ;; merge dev and dev class info
             (map (fn [[n dev]]
                    (let [cls (get (:device-classes design) (:class dev))]
                      (-> dev
                          (assoc :dt-label (or (:dt-label dev) (:dt-label cls)))
                          (assoc :dt-name (or (:dt-name dev) (:dt-name cls) (:class dev)))
                          (assoc :dt-props (merge {} (:dt-props cls) (:dt-props dev))))))))

        ;; determine which device names are reused and thus need the
        ;; @addr suffix
        multi-names
        (->>
         devs
         (map :dt-name)
         (frequencies)
         (filter (fn [[n freq]] (> freq 1)))
         (map key)
         set)

        bus-base
        (apply min (map :base-addr devs))

        ;; determine base-addr and node-name for devices
        devs
        (map
         (fn [dev]
           (let [base-addr (- (:base-addr dev) bus-base)
                 cls (get (:device-classes design) (:class dev))]
             (assoc dev
                    :dt-base-addr base-addr
                    :dt-reg-width (bit-shift-left 1 (inc (:left-addr-bit cls)))
                    :dt-node-name
                    (let [n (:dt-name dev)]
                      (if (multi-names n)
                        (node-name nil n base-addr)
                        (node-name nil n))))))
         devs)

        bus-width
        (- (apply max (map #(+ (:base-addr %) (:dt-reg-width %)) devs)) bus-base)

        cache-compat "jcore,soc-cache-0.1"
        ;; translate devices to device-tree nodes
        soc-children
        (concat
         (:dt-children (:soc design))
         (->> devs
              (map (fn [dev]
                     (let [dev-cls (get (:device-classes design) (:class dev))
                           ;; remove interrupt info from
                           ;; jcore,soc-cache-0.1 devices. That
                           ;; information is instead attached to the
                           ;; ipi node in the device tree.
                           dev
                           (if (= (get-in dev-cls [:dt-props :compatible])
                                  cache-compat)
                             (dissoc dev :irq)
                             dev)]
                       (dev-to-dt dev (:class dev) dev-cls))))
              (sort-by first)
              (filter identity)))

        cache-info
        (when-let
            [dev
             (->> devs
                  (some (fn [dev]
                          (let [dev-cls (get (:device-classes design)
                                             (:class dev))]
                            (when (= (get-in dev-cls [:dt-props :compatible])
                                     cache-compat)
                              dev)))))]
          {:irqs (->> (:irq dev)
                      vals
                      (map (fn [x] (or (:dt-irq x) (:irq x))))
                      set)
           :addr (:base-addr dev)})

        stdout-path
        (when-let [stdout (some #(when (:dt-stdout %) %) devs)]
          (str "/" (node-name nil "soc" bus-base) "/" (:dt-node-name stdout)))

        is-smp (get (:peripheral-buses design) "cpu1" false)]

    (when (> (count (:irqs cache-info)) 1)
      (errors/add-error (str "Cache " cache-compat " uses more than one irq ("
                             (s/join "," (sort (:irqs cache-info)))
                             ") but device tree will only describe a single interrupt number for IPI.")))

    ["/"
     {:properties
      [["model" (:name design)]
       ["compatible" [(compat-open "j2-soc")]]
       ["#address-cells" '(1)]
       ["#size-cells" '(1)]
       ["interrupt-parent" '(:&aic)]]
      :children
      [["chosen"
        {:properties
         [(when stdout-path
            [:stdout-path stdout-path])]}]
       ["cpus"
        (let [periph-buses (:peripheral-buses design)]
          {:properties
           [["#address-cells" '(1)]
            ["#size-cells" '(0)]
            (when is-smp
              ["enable-method" (compat-open "j2-soc-smp-0.1")])]
           :children
           (concat
            [[(node-name nil "cpu" 0)
              {:properties
               [["device_type" "cpu"]
                ["compatible" (compat-open "j2-0.1")]
                ["reg" '(0)]]}]]
            (when is-smp
              [[(node-name nil "cpu" 1)
                {:properties
                 [["device_type" "cpu"]
                  ["compatible" (compat-open "j2-0.1")]
                  ["reg" '(1)]]}]]))})]
       memory
       [(node-name nil "soc" bus-base)
        {:properties
         [["compatible" [(compat-open "j2-soc") "simple-bus"]]
          ["ranges" {:fmt :hex :v (list 0 bus-base bus-width)}]
          ["#address-cells" '(1)]
          ["#size-cells" '(1)]]
         :children
         soc-children}]
       ["cpuid"
        {:properties
         [["compatible" "jcore,soc-cpuid-0.1"]
          ["reg" {:fmt :hex :v (list 0xabcd0600 4)}]]}]
       (when is-smp
         ["cpustart"
          {:properties
           [["compatible" "jcore,soc-cpustart-0.1"]
            ["reg" {:fmt :hex :v (list 0xabcd0640 4 0x8000 4)}]]}])
       (when (and is-smp cache-info)
         ["ipi"
          {:properties
           [["compatible" "jcore,soc-ipi-0.1"]
            (when-let [addr (:addr cache-info)]
              ["reg" {:fmt :hex :v (list addr 8)}])
            (when-let [irq (first (:irqs cache-info))]
              ["interrupts" {:fmt :hex :v (list irq)}])]}])]}]))


(deftype DeviceTreePlugin []
    soc-gen.plugins/SocGenPlugin
    (on-pregen [plugin design]
      [plugin design])
    (file-list [plugin]
      [{:id ::dts
        :name "board.dts"}])
    (on-generate [plugin design file-id file-desc]
      file-desc)
    (file-contents [plugin design file-id file-desc]
      (when (= file-id ::dts)
        (to-str (to-dt design)))))
