(ns soc-gen.plugins.device-tree
  (:require
   [clojure.string :as s]
   [soc-gen
    [errors :as errors]]
   soc-gen.plugins.plugin)
  (:import
   [de.upb.hni.vmagic.literal
    DecimalLiteral]))

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

(defn node-name [label n & addrs]
  (str (when label (str label ": "))
       n
       (when (seq addrs) (str "@" (s/join "," (map #(format "%x" %) addrs))))))

(defn- relative-reg
  "Subtracts a base value from the offsets in a reg property"
  [regs base]

  (let [nums (if (map? regs) (:v regs) regs)
        ;; subtract from 1st, 3rd, 5th, ... number in nums
        nums
        (apply list (map-indexed
                     (fn [i x]
                       (if (zero? (mod i 2))
                         (- x base)
                         x))
                     nums))]
    ;; return result in same format as regs arg
    (if (map? regs)
      (assoc regs :v nums)
      nums)))

(defn- dev-to-dt [dev dev-cls-name dev-cls]
  [(node-name (:dt-label dev) (:dt-node-name dev))
   {:properties
    (concat
     (->> (:dt-props dev)
          sort
          (map
           (fn [[k v]]
             [(name k)
              (if (= k :reg)
                (relative-reg v (:dt-bus-base dev))
                v)])))

     ;; if not set explicitly in :dt-props, set "reg" based on base addr
     (when (not (contains? (:dt-props dev) :reg))
       [["reg" {:fmt :hex :v (list (:dt-base-addr dev) (:dt-reg-width dev))
                :cmt (format "%08X-%08X" (:base-addr dev) (+ (:base-addr dev) (:dt-reg-width dev) -1))}]])
     (when-let [irq (some #(if (:dt? %) %) (vals (:irq dev)))]
       [["interrupts"
         {:fmt :hex :v (list (or (:dt-irq irq) (:irq  irq)))}]]))
    :children (concat (:dt-children dev-cls) (:dt-children dev))}])

(defn to-dt
  "Convert soc design to device tree"
  [design cpu-freq]

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
                    :dt-bus-base bus-base
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

        cache-compat "jcore,cache"
        ;; translate devices to device-tree nodes
        soc-children
        (concat

         ;; Add :soc :dt-children, but first convert any reg
         ;; properties to be relative to soc bus base address
         (for [[child-name child] (:dt-children (:soc design))]
           [child-name
            (let [props
                  (mapv
                   (fn [prop]
                     (if (= :reg (first prop))
                       [:reg (relative-reg (second prop) bus-base)]
                       prop))
                   (:properties child))]
              (assoc child :properties props))])

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

        ipi-info (:ipi-info design)

        stdout-path
        (when-let [stdout (some #(when (:dt-stdout %) %) devs)]
          (str "/" (node-name nil "soc" bus-base) "/" (:dt-node-name stdout)))

        is-smp (get (:peripheral-buses design) "cpu1" false)

        cpu-props
        [["device_type" "cpu"]
         ["compatible" (compat-open "j2")]
         ["clock-frequency" (list cpu-freq)]]]

    (when is-smp
      (let [irq-count (count (:irqs ipi-info))]
        (cond
          ;; Comment out this check for now. It fails for asic_1v0.
          ;;(zero? irq-count)
          ;;(errors/add-error (str "Cannot determine ipi irq. No irqs detected."))
          (> irq-count 1)
          (errors/add-error (str "Cannot determine ipi irq. Multiple irqs detected for ipi ("
                                 (s/join "," (sort (:irqs ipi-info)))
                                 ") but device tree will only describe a single interrupt number for IPI."))))
      (when-not (:addr ipi-info)
        (errors/add-error "Cannot determine memory region for ipi")))

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
              ["enable-method" (compat-open "spin-table")])]
           :children
           (concat
            [[(node-name nil "cpu" 0)
              {:properties (conj cpu-props ["reg" '(0)])}]]
            (when is-smp
              [[(node-name nil "cpu" 1)
                {:properties
                 (conj cpu-props ["reg" '(1)] ["cpu-release-addr" {:fmt :hex :v (list 0xabcd0640 0x8000)}])}]]))})]
       ["clocks"
        {:properties []
         :children
         [[(node-name "bus_clock" "bus_clock")
           {:properties
            [["compatible" "fixed-clock"]
             ["#clock-cells" '(0)]
             ["clock-frequency" (list cpu-freq)]]}]]}]
       memory
       [(node-name nil "soc" bus-base)
        {:properties
         [["compatible" "simple-bus"]
          ["ranges" {:fmt :hex :v (list 0 bus-base bus-width)}]
          ["#address-cells" '(1)]
          ["#size-cells" '(1)]]
         :children
         soc-children}]
       ["cpuid"
        {:properties
         [["compatible" "jcore,cpuid-mmio"]
          ["reg" {:fmt :hex :v (list 0xabcd0600 4)}]]}]
       (when (and is-smp ipi-info)
         ["ipi"
          {:properties
           [["compatible" "jcore,ipi-controller"]
            (when-let [addr (:addr ipi-info)]
              ["reg" {:fmt :hex :v (list addr 8)}])
            (when-let [irq (first (:irqs ipi-info))]
              ["interrupts" {:fmt :hex :v (list irq)}])]}])]}]))


(defrecord DeviceTreePlugin []
    soc-gen.plugins.plugin/SocGenPlugin
    (on-pregen [plugin design]
      (let [cpu-freq
            ;; try to determine CPU frequency from config package constants
            (if-let [period-ns
                     (some (fn [x]
                             (let [val (:value x)]
                               (if (and (= (:type x) :constant)
                                        (= (:id x) "cfg_clk_cpu_period_ns")
                                        (instance? DecimalLiteral val))
                                 (Long/parseLong (.getValue val)))))
                           (:vhdl-data design))]
              ;; convert period in ns to frequency
              (quot 1000000000 period-ns)
              (errors/add-error (str "Unable to determine cpu frequency from CFG_CLK_CPU_PERIOD_NS")))]
        [(assoc plugin :cpu-freq cpu-freq)
         design]))
    (file-list [plugin]
      [{:id ::dts
        :name "board.dts"}])
    (on-generate [plugin design file-id file-desc]
      file-desc)
    (file-contents [plugin design file-id file-desc]
      (when (= file-id ::dts)
        (to-str (to-dt design (:cpu-freq plugin))))))
