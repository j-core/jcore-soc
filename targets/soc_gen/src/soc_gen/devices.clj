(ns soc-gen.devices
  (:require
   [clojure.string :as s]
   [clojure.set :as set]
   clojure.stacktrace
   [soc-gen.errors :as errors]
   [soc-gen.vmagic :as v]
   [soc-gen.parse :as parse]
   [soc-gen.byte-range :as br]
   [clojure.math.combinatorics :as comb])
  (:use [clojure.core.match :only (match)]))

;; keys that appear in sub-maps of pins that contain signal names
;; TODO: When supporting pins that connect to multiple signals (like
;; DDR) need to add to this vector
(def pin-info-sig-names [:name])

(defn- match-type [type desc]
  (and (= (:type type) (:type desc))
       (= (:id type) (:id desc))))

(defn- lower-case [s]
  (when s (s/lower-case s)))

(defn- choose-device-arch [devices entities archs]
  (let [archs-by-ent (group-by :entity archs)]
    (reduce
     (fn [devs [id dev]]
       (let [entity-id (lower-case (or (:entity dev) id))
             config-id (lower-case (:configuration dev))
             arch-id (lower-case (:architecture dev))
             entity (get entities entity-id)
             archs (get archs-by-ent entity-id)
             configs (if entity (:configs entity) [])
             config (when config-id
                      (some #(when (= config-id (:id %)) %) configs))
             arch (if arch-id
                    ;; select architecutre by id
                    (first (filter #(= arch-id (:id %)) archs))
                    (when (= 1 (count archs)) (first archs)))

             prop
             (cond
              (nil? entity)
              (do
                ;;(println "ENTITY NAMES:" (keys entities))
                (errors/add-error (str "Unable to map device \"" id "\" " entity-id " to entity")))

              (and config-id (nil? config))
              (errors/add-error (str "Unable to find configuration \"" config-id
                                     "\" of entity \"" entity-id "\" for device \"" id "\""))

              (and arch-id (nil? arch))
              (errors/add-error (str "Unable to find architecture \"" arch-id
                                     "\" of entity \"" entity-id "\" for device \"" id "\""))

              ;; specifying both an architecture and configuration is
              ;; redundant, but allow it if they match.
              (and config arch)
              (if (= (:id arch) (:architecture config))
                [:configuration config]
                (errors/add-error (str "Mismatching architecture \"" arch-id
                                       "\" and configuration \"" config-id
                                       "\" for device \"" id "\". Set only configuration.")))

              config
              [:configuration config]
              arch
              [:architecture arch]

              :else
              (errors/add-error
               (if (zero? (count archs))
                 (str "Unable to find any architecture for device \"" id "\"")
                 (str "Unable to find single architecture for device \"" id "\""))))]
         (if prop
           (assoc devs id
                  (into
                   (dissoc dev :architecture :configuration)
                   [[:entity entity]
                    prop]))
           devs)))
     {}
     devices)))

(defn- process-device-arch
  "Update a device class based on the architecture parsed from the vhdl"
  [dev]
  (let [arch (:architecture dev)
        regs (:regs dev)

        ;; Update each register
        regs (second
              (reduce
               (fn [[addr regs] reg]
                 (let [addr (or (:addr reg) addr)
                       width (or (:width reg) 4)
                       reg (assoc reg
                                  ;; calculate default address offsets using widths and known
                                  ;; offsets
                                  :addr addr
                                  :width width
                                  ;; clean up register name
                                  :name (s/trim (s/lower-case (:name reg))))]
                   [(+ addr width) (conj regs reg)]))
               [0 []]
               regs))

        dev (if (seq regs)
              (assoc dev :reg-range
                     (let [[low high]
                           (reduce
                            (fn [[min-addr max-addr] {:keys [addr width]}]
                              [(min min-addr addr) (max max-addr addr (+ addr width -1))])
                            [Long/MAX_VALUE Long/MIN_VALUE]
                            regs)]
                       ;; round to aligned 4 byte boundaries
                       (br/expand [low high] 4)))
              dev)
        ;; determine how to map registers to the available bus ports
        ;; of the entity
        reg-types (group-by :type regs)]
    (assoc dev :regs regs)))

(defn- gen-unique-name [prefix existing-names]
  (some (fn [i]
          (let [name (str prefix i)]
            (if (contains? existing-names name)
              nil
              name)))
        (range)))

(defn- assign-device-names
  "All devices should have a unique name. It can be assigned by the
  user, but will be generated from the device class name if not.
  Device names are also prefixed to port names to create the global
  names if they are not yet assigned."
  [devices]
  (let [user-names (for [dev devices
                         :let [name (:name dev)]
                         :when name]
                     name)
        user-name-set (atom (into #{} user-names))
        class-counts (frequencies (map :class devices))]
    (doseq [[name count] (frequencies user-names)]
      (when (> count 1)
        (errors/add-error (str "Multiple devices named \"" name
                               "\". Names must be unique."))))
    (into {} (map
              (fn [dev]
                (let [name
                      (or (:name dev)
                          ;; for a device with a single
                          ;; instance, use the device name
                          ;; itself if unique
                          (if (and (= (get class-counts (:class dev)) 1)
                                   (not (contains? @user-name-set (:class dev))))
                            (:class dev)
                            (gen-unique-name (:class dev) @user-name-set)))]
                  ;; add name to set so it isn't used for
                  ;; anything else
                  (swap! user-name-set conj name)
                  [name (assoc dev :name name)]))
              devices))))

(defn assign-device-ports
  "Assigns global names to ports that don't yet have them using the
  name of the device. Also renames signals using given map."
  [dev rename-signals]
  (update-in dev [:ports]
             (fn [ports]
               (let [ports
                     (reduce
                      (fn [ports [name port]]
                        (let [port
                              (if ((some-fn :irq? :data-bus :open? :value) port)
                                ;; 'special' ports are not connected
                                ;; based on global-signal names, so
                                ;; remove those names
                                port
                                (let [sig-name (or (:global-signal port)
                                                   (str (:name dev) "_" (or (:local-signal port)
                                                                            (:id port))))]
                                  (assoc port :global-signal (get rename-signals sig-name sig-name))))]
                          (assoc ports name port)))
                      {}
                      ports)]
                 ports))))

(defn- resolve-device-port
  "Resolve any generic values in a single port type. This only handles
  simple cases. Currently std_logic_vectors of with generic values in
  the array's range left and right."
  [port generic-vals]
  (let [vtype (:vobj (meta (:type port)))
        vtype (v/resolve-type vtype generic-vals)]
    (assoc port
      :type (with-meta (parse/extract-type vtype)
              (assoc (meta (:type port))
                :vobj vtype)))))

(defn- resolve-device-generics
  "Ensure generics assigned to a device exist for the entity, and
  update the port types based on the user-set or default generics.
  This is important for vectors whose left and right bounds involve a
  generic (SPI CS lines)"
  [dev entity]
  (let [entity-generics (:generics entity)
        user-generics
        ;; create literals for generics set by the user
        (reduce
         (fn [m [name val]]
           (let [gen (get entity-generics name)]
             (assoc m (s/lower-case name)
                    (if (and gen (number? val))
                      (v/num-val (v/vobj (:type gen)) val)
                      (v/literal val)))))
          {}
          (:generics dev))
        ports (:ports dev)

        ;; determine the generic values that are used for this device
        generic-vals
        (merge
         ;; pull default values for generics from entity
         (reduce
          (fn [m [name gen]]
            (assoc m name (:default-value gen)))
          {}
          entity-generics)
         user-generics)]

    ;; check that all set generics match ones defined in the entity
    (doseq [name (keys generic-vals)]
      (if (not (contains? entity-generics name))
        (errors/add-error (str "Unknown generic \"" name "\" for device \"" (:name dev) "\"."))))

    (assoc dev
      :user-generics user-generics
      :ports
      (->> (:ports entity)
           (map (fn [[name port]]
                  [name (merge
                         (resolve-device-port port generic-vals)
                         ;; merge original port map to allow
                         ;; overridding values in design
                         (let [orig-port (get ports name)]
                           (if (string? orig-port)
                             {:global-signal orig-port}
                             orig-port)))]))
           (into {})))))

(defn- types-used
  "Returns sequence of type names referenced by a port's type."
  [t]
  (match t
         {:type :enum-type :id id} [id]
         {:type :record :id id} [id]
         ;; TODO: An index sub type could reference variables in it's
         ;; left and right bounds which could be defined in a separate
         ;; lib. Should return these also?
         {:type :index-sub-type :base base} (types-used base)
         {:type :std} nil
         {:type :array-type :id "unsigned"} nil
         {} (throw (Exception. (str "Unhandled type " (v/vstr (v/vobj t)))))))

(defn- resolve-port-types
  "The types used in entity ports require using certain packages. If
  these types become signals, then those packages must be used in
  other files as well. Identify the packages that need to be used for
  each entity's ports and add a :pkgs [list of pkg names] to each port."
  [dev entity pkgs]

  (let [libs (->> (:uses entity)
                  (map #(s/split % #"\."))
                  (filter #(= "work" (first %)))
                  (mapv second))
        type->lib
        (into {}
              (for [lib libs
                    decl (:decls (get pkgs lib))]
                [decl lib]))]
    (update-in dev [:ports]
               (fn [ports]
                 (into {}
                       (for [[n p] ports]
                         (let [pkgs (->> (:type p)
                                         types-used
                                         (map type->lib)
                                         (filter identity)
                                         distinct
                                         vec)]
                           [n (assoc p :pkgs pkgs)])))))))

(defn- update-dev-from-class
  "Update a device based on information from the device class"
  [dev dev-class]
  (let [dev
        ;; merge port info
        (reduce
         (fn [dev [n p]]
           (update-in dev [:ports n] #(merge p %)))
         dev
         (:ports dev-class))
        ;; merge generics info
        dev
        (update-in dev [:generics] #(merge (:generics dev-class) %))]
    dev))

(defn- resolve-entities [ents entities archs pkgs merge-signals]
  (let [ents (choose-device-arch ents entities archs)]
    (if (errors/error?)
      ents
      (->> ents
           (map
            (fn [[name ent]]
              [name
               (-> ent
                   (assoc :name name)
                   (resolve-device-generics (:entity ent))
                   (resolve-port-types (:entity ent) pkgs)
                   (assign-device-ports merge-signals))]))
           (into {})))))

(defn- assign-all-device-ports
  "Copies device class ports to each device. Assigns a global name to
  those ports that don't have them"
  [design pkgs]
  (let [classes (:device-classes design)]
    (update-in design [:devices]
               (fn [devs]
                 (reduce
                  (fn [devs [name dev]]
                    (let [dev-class (get classes (:class dev))
                          entity (:entity dev-class)]
                      (assoc devs
                        name
                        (-> dev
                            (update-dev-from-class dev-class)
                            (resolve-device-generics entity)
                            (resolve-port-types entity pkgs)
                            (assign-device-ports (:merge-signals design))))))
                  {}
                  devs)))))

(defn- expose-signals
  "Certain signals can be 'exposed' meaning they are connected up to
  ports that don't match existing pins and no IO buffers are created.
  If the signals are records, they are split into std_logic and
  std_logic_vector ports. This is needed when pad ring is not the real
  top and another outer entity needs to deal with the signals
  directly."
  [design]

  (let [expose-sigs (keys (:expose-signals design))
        signals (select-keys (:global-signals design) expose-sigs)]
    (when-let [missing (seq (filter #(not (contains? signals %)) expose-sigs))]
      (errors/add-error (str "Cannot expose missing signals: " (s/join ", " missing))))
    (let [signals
          (->> signals
               (map (fn [[n s]]
                      [n
                       (update-in s [:ports] conj
                                  {:id n
                                   :global-signal n
                                   :context {:type :expose :id n}
                                   :name (str "top.expose[" n "]")
                                   :type (:type s)
                                   :dir (if (some #{:out} (map :dir (:ports s)))
                                          :in :out)})])))]
      (update-in design [:global-signals] into signals))))

(defn- process-pins [design]
  (let [build-matcher
        (fn [pattern]
          (if (string? pattern)
            (let [pattern (re-pattern pattern)]
              (fn [pin]
                (when (re-matches pattern pin)
                  {})))
            (let [syms (->> pattern
                            (filter symbol?)
                            (map vector (range))
                        (into {}))
                  pattern (->> pattern
                              (map (fn [x] (cond (string? x) x
                                                (symbol? x) "([0-9]+)")))
                              s/join
                              re-pattern)]
              (fn [pin]
                (when-let [m (re-matches pattern pin)]
                  (reduce
                   (fn [ctx [idx sym]]
                     (assoc ctx sym (nth m (inc idx))))
                   {}
                   syms))))))

        sig-name-builder
        (fn [name]
          (cond
           (= name true) (fn [pin ctx] (:net pin))
           (string? name) (constantly name)
           (vector? name) (fn [pin ctx]
                            (s/join
                             (map #(cond (symbol? %) (ctx %) :else %) name)))))

        pins (:pins (:pins design))

        ;; add a key for sorting pins nicer
        pins
        (mapv
         (fn [pin]
           (let [net (:net pin)
                 [_ first-word] (re-matches #"([^0-9]+)([0-9].*|)" net)]
             (assoc pin :sort
                    (if-let [[_ name num] (re-matches #"([^0-9]+)([0-9]+)([^0-9].*|)" net)]
                      [first-word [name (Integer/parseInt num) net]]
                      [first-word [net]]))))
         pins)

        ;; apply pin rules to the pins and normalize the resuling pin descriptions
        pins
        (reduce
         (fn [pins rule]
           (let [matcher (build-matcher (:match rule))
                 sigs
                 (->> [:signal :in :out :out-en]
                      (map (fn [k]
                             (if (contains? rule k)
                               [k
                                (let [sig (get rule k)]
                                  (cond
                                   (nil? sig) nil
                                   (number? sig) {:value sig}
                                   (map? sig) (assoc sig
                                                :name
                                                (sig-name-builder (:name sig)))
                                   :else {:name (sig-name-builder sig)}))])))
                      (filter identity)
                      (into {}))
                 matched-pins
                 (map (fn [pin] [pin (matcher (:net pin))]) pins)]
             (if (every? (comp nil? second) matched-pins)
               (errors/add-warning (str "Pin rule " (pr-str (:match rule)) " does not match any pins")))
             (mapv (fn [[pin ctx]]
                     (if ctx
                       ;; merge the rules attributes
                       ;; into existing rules of the pin
                       (let [pin (update-in pin [:attrs] merge (:attrs rule))
                             ;; copy some other keys over if present
                             pin
                             (reduce
                              (fn [pin k]
                                (if (contains? rule k)
                                  (assoc pin k (k rule))
                                  pin))
                              pin
                              [:buff :name])]
                         ;; if rules specifies signal,
                         ;; then update the pin's signal attribute
                         (reduce
                          (fn [pin [k sig]]
                            (if sig
                              ;; any value that is a function, call
                              ;; and replace it
                              (assoc pin k
                                     (->> sig
                                          (map (fn [[k v]]
                                                 (if (fn? v)
                                                   [k (v pin ctx)]
                                                   [k v])))
                                          (into {})))
                              (dissoc pin k)))
                          pin
                          sigs))
                       pin))
                   matched-pins)))
         pins
         (:rules (:pins design)))

        dissoc-nil-vals #(into {} (filter (comp not nil? val) %))
        ;; remove keys with nil values. They're used by a later rule
        ;; to clear the value from a newer rule.
        pins
        (mapv
         (fn [pin]
           (dissoc-nil-vals (update-in pin [:attrs] dissoc-nil-vals)))
         pins)]

    (assoc-in design [:pins :pins] pins)))

(defn- match-pins-to-signals [design]
  (let [pins (:pins (:pins design))
        global-signals (:global-signals design)

        base-signal-name (fn [name] (second (re-matches #"([^.(]+)([.(].*|)" name)))
        sub-signal-name
        (fn [name]
          (mapv
           (fn [part]
             (let [[field index] (rest (re-matches #"([^.(]+)(?:\(\s*([0-9]+)\s*\))?" part))]
               (if index
                 [field (Integer/parseInt index)]
                 field)))
           (s/split name #"\.")))
        pins
        (->> (sort-by :sort pins)

             ;; infer whether generic :signal pins are input or output
             ;; based on existing signal port directions
             (map
              (fn [pin]
                (match (select-keys pin [:signal :in :out :out-en])
                       ({:signal info} :only [:signal])
                       ;; what about differential signals!?
                       (let [sig-name (base-signal-name (:name info))]
                         (if-let [sig (get global-signals sig-name)]
                           (-> pin
                               (dissoc :signal)
                               (assoc
                                (if (and (some #(= :out (:dir %)) (:ports sig))
                                         ;; direction of fake "pi" signal
                                         ;; is :out, but always infer
                                         ;; input pins for it
                                         (not= sig-name "pi"))
                                  :out
                                  :in) info))
                           (update-in pin [:missing] conj (:name info))))
                       :else pin)))
             (filter identity)

             ;; decide pin directions based on pin key present
             (map
              (fn [pin]
                (if (:missing pin)
                  pin
                  (let [sig-keys (select-keys pin [:in :out :out-en])]
                    (match sig-keys
                           ({:in in} :only [:in])
                           (assoc pin :dir :in)

                           ({:out out} :only [:out])
                           (assoc pin :dir :out)

                           ({:out out :out-en out-en} :only [:out :out-en])
                           (assoc pin :dir :out)

                           {:in in :out out :out-en out-en}
                           (assoc pin :dir :inout)

                           :else
                           (if (empty? sig-keys)
                             (assoc pin :ignore true)
                             (assoc pin :invalid true)))))))

             ;; lookup all pin names. Add any non-existent ones to a
             ;; missing list in the pin.
             (map
              (fn [pin]
                (reduce
                 (fn [pin [dir name-key]]
                   (if-let [sig-name (get-in pin [dir name-key])]
                     (let [base-name (base-signal-name sig-name)]
                       (if-let [signal (global-signals base-name)]
                         (assoc-in pin [dir name-key]
                                   (merge
                                    {:name sig-name
                                     :signal-name base-name}
                                    (when (not= base-name sig-name)
                                      {:element-name (sub-signal-name sig-name)})))
                         (update-in pin [:missing] conj sig-name)))
                     pin))
                 pin
                 (comb/cartesian-product
                  [:in :out :out-en]
                  pin-info-sig-names)))))

        ignored-pins (filter :ignore pins)
        missing-pins (filter :missing pins)
        pins (doall (filter #(not (or (:ignore %) (:missing %))) pins))

        std-logic (parse/extract-type v/std-logic)

        pin-ports
        (mapcat
         (fn [pin]
           (let [port {:name (str "pin." (:net pin) ".")
                       :id (:net pin)
                       :context {:type :pin :id (:net pin)}
                       :type std-logic}]

             (for [[sig-key dir] [[:in :out] [:out :in] [:out-en :in]]
                   name-key pin-info-sig-names
                   :let [dir-info (sig-key pin)
                         name-info (name-key dir-info)
                         sig-name (:name name-info)]
                   :when sig-name]
               (-> port
                   (update-in [:name] str (name sig-key))
                   (assoc :global-signal (:signal-name name-info)
                          :sub-signal? (boolean (:element-name name-info))
                          :dir dir
                          :info dir-info)))))
         pins)

        ;; add pins that connect to signals to the global signals maps
        ;; as ports, that is, sources or sinks for signals
        global-signals
        (reduce
         (fn [global-signals port]
           (update-in global-signals [(:global-signal port) :ports] conj port))
         global-signals
         pin-ports)
        ]

    (if (seq ignored-pins)
      (errors/add-warning (str "Ignoring pins " (s/join ", " (map :net ignored-pins)))))

    (doseq [[miss pin-names]
            (->> missing-pins
                 (mapcat (fn [pin] (for [miss (distinct (:missing pin))]
                                    (assoc pin :miss (base-signal-name miss)))))
                 (group-by :miss)
                 sort
                 (map (fn [[miss pins]] [miss (distinct (map :net pins))])))]
      (errors/add-warning (str "No signal with name " miss
                               " found for pins " (s/join ", " pin-names))))

    (doseq [pin pins]
      (if (:invalid pin)
        (errors/add-error (str "Pin " (:net pin) " description invalid: " (pr-str pin)))))

    ;; differential signals must match
    (doseq [[dir msg] [[:in "input from"] [:out "output to"]]]
      (let [diff-ins (->> pins
                          (filter (comp :diff dir))
                          (group-by (comp :name dir)))]
        (doseq [[name pins] diff-ins]
          (when-not (and (= (count pins) 2) (= #{:pos :neg} (set (map (comp :diff dir) pins))))
            (errors/add-error (str "Signal " name " is " msg " mismatched differential pins: "
                                   (s/join ", " (map :net pins))))))))

    (-> design
        (assoc-in [:pins :pins] pins)
        (assoc :global-signals global-signals))))

(defn- fixup-pi
  "Hack to fixup the pi signal. If no pins connect to it, then the
  fake signal added for it should be :dir :out instead of :dir :in so
  that it correctly flows from the padring to the pio entity."
  [design]
  (if-let [pi ((:global-signals design) "pi")]
    (if (not-any? #(= :out (:dir %)) (:ports pi))
      (assoc-in
       design
       [:global-signals
        "pi"
        :ports
        ;; index of fake pi port
        (first
         (keep-indexed
          (fn [i x] (when (= (:name x) "padring.pi[pi]") i))
          (:ports pi)))
        :dir]
       :out)
      design)
    design))

(defn- remove-write-only-signals
  "Avoid creating signals in the vhdl for ports that are assigned values directly"
  [design]
  (update-in design [:global-signals]
             (fn [signals]
               (->> signals
                    (filter #(or (some (comp #{:in} :dir) (:ports (val %)))
                                 (some (comp #{:pin} :type :context) (:ports (val %)))))
                    (into {})))))

(defn- fake-record-type
  "Creates an extract vhdl type representing a record type. For some reason, vmagic parses a port with a record type as an empty EnumerationType, so replicate that behaviour."
  [name]
  (parse/extract-type (v/enum-type name)))

(defn- process-bist-chain
  "The :bist-chain vector in the design describes the order the bist
  chain should be connected in. This returns a port list containing
  global signals to connect the bist chain."
  [chain ports]
  (when-let [dups (seq (filter #(> (val %) 1) (frequencies chain)))]
    (errors/add-error (str ":bist-chain contains duplicates: " (s/join ", " dups))))

  (let [port-map (->> ports
                      (map (fn [x] [((juxt :context :bist-chain) x) x]))
                      (into {}))
        chain
        (->> chain
             (mapv (fn [x]
                     (if-let [[_ t id] (re-matches #"([a-zA-Z0-9]+)\.([a-zA-Z0-9]+)" x)]
                       (let [ctx {:type (keyword t) :id id}]
                         (if (contains? port-map [ctx :in])
                           ctx
                           (errors/add-error (str "Unknown item in bist-chain: " x))))
                       (errors/add-error (str "Invalid item in bist-chain: " x)))))
             (remove nil?))]
    (when-let [missing (seq
                        (set/difference
                         (set (map :context (filter #(= :in (:bist-chain %)) ports)))
                         (set chain)))]
      (errors/add-error (str "Bist chain of "
                             (s/join ", " (map #(str (name (:type %)) "." (:id %)) missing))
                             " unconnected")))
    ;; connect bist ports with new signals
    (when (seq chain)
      (mapcat
       (fn [i [from to]]
         (let [sig (str "bist_chain_" i)]
           [(assoc (port-map [from :out]) :global-signal sig)
            (assoc (port-map [to :in]) :global-signal sig)]))
       (range)
       (partition 2 1 [(first chain)] chain)))))

(defn- gather-global-signals
  "gather the global ports for the ring devices into a single map of
signal-name to a map of info about the signal"
  [design]
  (let [
        ;; add a :context to each global_signal port to identify what it is a port of
        ;; and create a seq of all of them
        gather-ports (fn [ctx-type]
                       (fn [[name entity]]
                         (for [port (vals (:ports entity))
                               :when (:global-signal port)]
                           (assoc port :context {:type ctx-type :id name}))))

        top-ports (mapcat (gather-ports :top) (:top-entities design))
        device-ports (mapcat (gather-ports :device) (:devices design))
        padring-ports (mapcat (gather-ports :padring) (:padring-entities design))

        port->str
        (fn [port]
          (let [{:keys [type id]} (:context port)]
            (str (name type) "." id "[" (:id port) "]")))

        all-signal-ports
        (concat
         device-ports
         padring-ports
         top-ports
         ;; add some 'fake' ports that belong to the devices entity but
         ;; are not from any particular device
         (map
          #(assoc %
             :context {:type :device :id "_internal"}
             :global-signal (:id %))
          (concat
           [{:id "cpu0_periph_dbus_i"
             :dir :out
             :type (fake-record-type "cpu_data_i_t")}
            {:id "cpu0_periph_dbus_o"
             :dir :in
             :type (fake-record-type "cpu_data_o_t")}
            {:id "cpu1_periph_dbus_i"
             :dir :out
             :type (fake-record-type "cpu_data_i_t")}
            {:id "cpu1_periph_dbus_o"
             :dir :in
             :type (fake-record-type "cpu_data_o_t")}]
           ;; find the irqs port, if one exists, to determine it's bit
           ;; width
           (when-let [iq (first (filter #(and (= (:global-signal %) "irqs")
                                              (= (:dir %) :in)) top-ports))]
             (let [t (:type iq)]
               (if-let [from
                        (match [t]
                               [{:type :index-sub-type
                                 :base {:type :std, :id "std-logic-vector"}
                                 :ranges [{:dir :downto :to 0M :from from}]}]
                               from
                               :else nil)]
                 [(with-meta
                    {:id "irqs"
                     :dir :out
                     :type t}
                    {:num-irq (inc (long from))})]
                 (do (errors/add-error
                      (str "Found irqs port with unexpected type: "
                           (v/vstr (v/vobj t))
                           " should be std_logic_vector(N downto 0)"))
                     nil))))))
         ;; add fake port for pi signal in padring
         ;; TODO: remove this hack when pio is handled inside the
         ;; pio device properly
         (when-let [pi (first (filter #(and (= (:global-signal %) "pi")
                                            (= (:dir %) :in)) device-ports))]
           [{:id "pi"
             :global-signal "pi"
             :context {:type :padring :id "pi"}
             :dir :in
             :type (:type pi)}]))

        ;; add global signals to connect bist chain
        all-signal-ports
        (into (remove #(and (:bist-chain %) (nil? (:value %))) all-signal-ports)
              (process-bist-chain (:bist-chain design) (filter #(and (:bist-chain %) (nil? (:value %))) all-signal-ports)))

        all-signal-ports
        (->> all-signal-ports
             ;; add names to every port for easy printing later
             (map #(assoc % :name (port->str %)))
             (group-by :global-signal))

        ;; vmagic sometimes parses records as enum types with no literals
        ;; and other times as the full record. I'm unclear why, but here's
        ;; a hack to get around the issue. If there are multiple types for
        ;; ports for a signal, and one is an enum literal and another is a
        ;; record with the same id, make the enum literal the same as the record.
        all-signal-ports
        (->> all-signal-ports
             (map
              (fn [[sig-name ports]]
                (let [types (map :type ports)
                      records (->> types
                                   (filter #(= :record (:type %)))
                                   (map (fn [t] [(:id t) t]))
                                   (into {}))]
                  [sig-name
                   (mapv
                    (fn [port]
                      (update-in port [:type]
                                 #(match %
                                         {:type :enum-type
                                          :literals []
                                          :id type-id}
                                         (or (get records type-id) %)
                                         :else %)))
                    ports)])))
             (into {}))

        zero-signals (set (:zero-signals design))

        ;; add "ports" that zero out signals in top
        all-signal-ports
        (->> all-signal-ports
             (map
              (fn [[sig-name ports]]
                [sig-name
                 (if (contains? zero-signals sig-name)
                   (conj ports
                         {:id sig-name
                          :global-signal sig-name
                          :context {:type :top :id "_zero"}
                          :name (str "top._zero[" sig-name "]")
                          :dir :out
                          :type (:type (first ports))})
                   ports)]))
             (into {}))]

    (let [signals (->> all-signal-ports
                       (map (fn [[id ports]]
                              [id {:id id
                                   :type (:type (first ports))
                                   :pkgs (vec (distinct (mapcat :pkgs ports)))
                                   :ports ports}]))
                       (into {}))]
      ;;(println "Gen signals:" signals)
      (assoc design :global-signals signals))))

(defn- validate-global-signals [design]
    ;; verify some properties of the ports
  (doseq [[sig-name {ports :ports}] (:global-signals design)]
    ;; all ports with matching signal names should have the same
    ;; type

    (let [;; ignore pin ports that connect to a portion of the signal
          ;; because their type is always std-logic
          check-ports (filter (complement :sub-signal?) ports)
          types (distinct (map :type check-ports))]
      (if (not= (count types) 1)
        (let [mismatches (->> (group-by :type ports)
                              (map
                               (fn [[t ports]]
                                 (str \" (v/vstr (v/vobj t)) \" " in "
                                      (s/join " "
                                              (map :name ports)))))
                              (s/join ", "))]
          (errors/add-error (str "Type mismatch for signal " sig-name " " mismatches)))))
    ;; There must be a single source for each global signal. There
    ;; are two types of sources: a source port is a port with :dir
    ;; :out, and a source pin is a matching external pin that
    ;; supplies the signal.
    ;; Signals can have no source if all of the destinations have an
    ;; assigned value or are marked open.
    (let [out-ports (filter #(= (:dir %) :out) ports)
          in-ports (filter #(= (:dir %) :in) ports)
          connected-in-ports (filter #(not (or (:value %) (:open? %))) in-ports)]
      (when-not (or (< (count out-ports) 2)
                    ;; allow differential inputs where a signal comes from two
                    ;; pins
                    (and
                     (= (count out-ports) 2)
                     ;; all pins
                     (= #{:pin} (set (map (comp :type :context) out-ports)))
                     ;; matching positive and negative pair
                     (= #{:neg :pos} (set (map (comp :diff :info) out-ports))))
                    ;; allow a signal to come from multiple pins if
                    ;; each pin contributes to a different part
                    ;; TODO: Verify that the entire signal is covered,
                    ;; or zero out the rest of it?
                    (and
                     ;; all pins
                     (= #{:pin} (set (map (comp :type :context) out-ports)))
                     ;; all names of sub-signals are distinct
                     (let [info-names (mapcat (comp :name (apply juxt pin-info-sig-names) :info)
                                              out-ports)
                           info-names (filter identity info-names)]
                       (= (count info-names) (count (distinct info-names))))))
        (errors/add-error (str "Signal " sig-name " is output from multiple ports "
                               (s/join " " (map :name out-ports)))))
      (when (and (zero? (count out-ports)) (> (count connected-in-ports) 0))
        (errors/add-error (str "Nothing drives signal " sig-name " used by " (s/join " " (map :name in-ports))))))

    #_(println "SIG" sig-name
               "IN" (map :name (filter #(= (:dir %) :in) ports))
               "OUT" (map :name (filter #(= (:dir %) :out) ports))))
  design)

(defn- validate-devices
  [design]
  (let [devices (vals (:devices design))
        dev-classes (:device-classes design)]
    (doseq [[irq num]
            (->> devices
                 (map :irq)
                 (filter identity)
                 frequencies
                 (filter #(not= 1 (val %))))]
      (errors/add-error (str "Cannot share irq line " irq " for multiple devices")))

    ;; check base address
    (doseq [dev devices]
      (if-let [base-addr (:base-addr dev)]
        (if (not= (bit-and base-addr 0xF0000000) 0xA0000000)
          (errors/add-error (str "Device " (:name dev) " based address 0x"
                                 (s/upper-case (Long/toString base-addr 16))
                                 " is invalid. Bits 31-28 must be 0xA. This is a limitation of bus address decoding in hand-written VHDL around the CPU.")))
        (errors/add-error (str "Device " (:name dev) " must have a base register address"))))

    ;; Check registers of device classes used in design
    (doseq [[id devc] (select-keys dev-classes (set (map :class devices)))]
      ;;(println id ":" (:reg-range devc) (s/join ", " (map :name (:regs devc))))
      (when-let [regs (:regs devc)]
        ;; Check registers don't overlap
        (when-let [bad (seq (br/overlaps
                             (map (fn [{:keys [addr width] :as reg}]
                                    (with-meta [addr (+ addr width -1)]
                                      {:reg reg}))
                                  regs)))]
          (errors/add-error (str "Registers of device class \"" id "\" overlap: "
                                 (s/join ", " (map (comp :name :reg meta) bad)))))

        ;; Check that multiple registers don't map into the same aligned 32-bits
        (when-not (errors/error?)
          (when-let [bad (seq (br/overlaps
                               (map (fn [{:keys [addr width] :as reg}]
                                      ;; expand register width to be
                                      ;; 32-bit aligned
                                      (with-meta
                                        (br/expand [addr (+ addr width -1)] 4)
                                        {:reg reg}))
                                    regs)))]
            (errors/add-error (str "Registers of device class \"" id "\" overlap in the same aligned 32-bit: "
                                   (s/join ", " (map (comp :name :reg meta) bad))))))

        ;; Check that all register have a unique name
        (when-let [dups (seq (filter #(> (val %) 1) (frequencies (map :name regs))))]
          (errors/add-error (str "Registers of device class \"" id "\" with duplicate name: "
                                 (s/join ", " (map key dups)))))))

    ;; Check that different devices don't overlap
    #_(when-not (errors/error?)
      (doseq [dev devices]
        (let [dev-cls (get dev-classes (:class dev))
              base-addr (:base-addr dev)
              regs (:regs dev-cls)]
          (when regs
            ()
            ))))
    #_(when-not (errors/error?)
      (let [dev-classes
            ;; calculate total register space width of each device class
            (->> dev-classes
                 (map (fn [x] (prn (key x)) x))
                 (into {}))]
        (doseq [dev devices]
          (let [dev-cls (get dev-classes (:class dev))
                base-addr (:base-addr dev)
                regs (:regs dev-cls)]
            (println ))))))
  design)

(defn- validate-rings
  "ensure ring definitions is valid and that nodes on rings match devices"
  [design]
  design)

(defn combine-soc-description
  "Creates soc description by combining the design description provided by the
user and information parsed from the vhdl"
  [design vhdl-files vhdl-data]
  (errors/wrap-errors
   (let [vhdl-by-type (group-by :type vhdl-data)
         entities
         (->> (:entity vhdl-by-type)
              (map (fn [e] [(:id e) e]))
              (into {}))

         ;; add list of found configurations to each entity
         entities
         (reduce
          (fn [entities config]
            (if (contains? entities (:entity config))
              (update-in entities [(:entity config) :configs]
                         (fn [configs] (conj (or configs []) config)))
              (do
                (errors/add-warning
                 (str "Found configuration \"" (:id config)
                      "\" of unknown entitiy \"" (:entity config)) "\"")
                entities)))
          entities
          (:configuration vhdl-by-type))

         archs (:architecture vhdl-by-type)
         pkgs (->> (:package-declaration vhdl-by-type)
                   (map (fn [p] [(:id p) p]))
                   (into {}))
         design (assoc design
                  :vhdl-data vhdl-data)

         ;; reverse the merge-signals mapping so we can lookup renames
         design (update-in design [:merge-signals]
                           (fn [name-map]
                             (into {}
                                   (for [[sig renames] name-map
                                         rename renames]
                                     [rename sig]))))

         design
         (-> design
             (update-in [:device-classes]
                        (fn [devs]
                          ;; ignore device classes that aren't used
                          (let [devs (select-keys devs
                                                  (filter identity (map :class (:devices design))))]
                            (->> (choose-device-arch devs entities archs)
                                 (map
                                  (fn [[name dev]]
                                    [name
                                     (process-device-arch dev)]))
                                 (into {})))))
             (update-in [:top-entities] resolve-entities entities archs pkgs (:merge-signals design))
             (update-in [:padring-entities] resolve-entities entities archs pkgs (:merge-signals design))
             (update-in [:devices] assign-device-names)
             ;;(update-in [:rings] assign-ring-node-names)
             (assign-all-device-ports pkgs)
             ;;gather-device-ports
             gather-global-signals
             expose-signals
             process-pins
             match-pins-to-signals
             fixup-pi
             remove-write-only-signals
             validate-global-signals
             validate-devices
             validate-rings)]
     (when-not (errors/dump)
       design))))
