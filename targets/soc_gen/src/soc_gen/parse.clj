(ns soc-gen.parse
  (:require
   [clojure.string :as s]
   [clojure.java.io :as jio]
   [soc-gen
    [vmagic :as v]
    [errors :as errors]]
   [com.stuartsierra.dependency :as dep]
   clojure.stacktrace)
  (:import
   [de.upb.hni.vmagic.parser
    VhdlParser
    VhdlParserSettings]
   [de.upb.hni.vmagic.parser.annotation
    PositionInformation]
   [de.upb.hni.vmagic.libraryunit
    PackageDeclaration
    PackageBody
    Entity
    Architecture
    LibraryClause
    UseClause
    Configuration]
   [de.upb.hni.vmagic.type
    SubtypeIndication
    RecordType
    EnumerationType
    ConstrainedArray
    UnconstrainedArray
    ArrayType
    IndexSubtypeIndication
    RangeSubtypeIndication
    IntegerType
    PhysicalType
    UnresolvedType]
   [de.upb.hni.vmagic.declaration
    Component
    Subtype
    Attribute
    AttributeSpecification
    AttributeSpecification$EntityNameList
    Group
    GroupTemplate
    EntityClass
    ConstantDeclaration]
   [de.upb.hni.vmagic.object
    VhdlObject$Mode
    Constant]
   [de.upb.hni.vmagic.builtin
    StdLogic1164]
   [de.upb.hni.vmagic.literal
    DecimalLiteral
    PhysicalLiteral
    EnumerationLiteral
    CharacterLiteral
    StringLiteral]
   [de.upb.hni.vmagic
    Annotations
    LibraryDeclarativeRegion
    RootDeclarativeRegion
    NamedEntity
    Range
    Range$Direction]
   [de.upb.hni.vmagic.expression
    AddingExpression
    Add
    Subtract]
   [de.upb.hni.vmagic.configuration
    ArchitectureConfiguration]))

(defn parse-files [file-names common]
  (let [settings (VhdlParserSettings.)
        ;; getting ArrayIndexOutOfBoundsException when parsing
        ;; lib/fixed_dsm_pkg/ieee/fixed_pkg_c.vhd with position
        ;; info enabled
        ;;_ (.setAddPositionInformation settings true)

        ;; create scopes shared by different parseFile calls to
        ;; resolve across packages
        root-scope (RootDeclarativeRegion.)
        work-scope (LibraryDeclarativeRegion. "work")]
    (.add (.getLibraries root-scope) work-scope)
    (->> file-names
         (map
          (fn [name]
            (try
              (println "Parsing" (.substring name (inc (.length common))))
              [name
               (VhdlParser/parseFile
                name
                settings
                root-scope work-scope)]
              (catch Exception e
                (do
                  (println "Failed to parse" name)
                  (errors/add-error (str "Cannot parse " name))
                  (clojure.stacktrace/print-stack-trace e)
                  nil)))))
         (filter identity)
         (into {}))))

(defn enum->key-fn [vals]
  #_(println "vals" vals)
  (let [m
        (->>
         vals
         (map
          (fn [x] [x (keyword (s/lower-case (str x)))]))
         (into {}))]
    (fn [x]
      (get m x))))

(def mode->key (enum->key-fn (VhdlObject$Mode/values)))
(def direction->key (enum->key-fn (Range$Direction/values)))
(def entityclass->key (enum->key-fn (EntityClass/values)))

#_(defn mode->key [mode]
  (get
   {VhdlObject$Mode/IN :in
    VhdlObject$Mode/OUT :out
    VhdlObject$Mode/INOUT :inout}
   mode))

#_(defn direction->key [dir]
  (get
   {Range$Direction/DOWNTO :downto
    Range$Direction/TO :to}
   dir))


(defprotocol ExtractVhdl
  (extract-impl [e] "Returns list of data items extracted from vmagic object"))

(defprotocol ExtractVhdlType
  (extract-type-impl [e] "Returns an object representing a vmagic type"))

(defprotocol ExtractVhdlRange
  (extract-range-impl [r] "Returns an object representing a vmagic range"))

(defprotocol ExtractVhdlExpression
  (extract-expression-impl [e] "Returns an object representing a vmagic expression"))

(extend-type Object
  ExtractVhdl
  (extract-impl [e]
    #_(println "Ignoring" (class e))
    nil)
  ExtractVhdlType
  (extract-type-impl [e] nil))

(defn- extract [e]
  (let [r (extract-impl e)]
    ;; attach the element to the metadata if it generated a single
    ;; value
    (if (= 1 (count r))
      (let [r (first r)
            r (when r
                (if (instance? NamedEntity e)
                  (assoc r :id (v/id e))
                  r))]
        [(with-meta r {:vobj e})])
      r)))

(defn- extract-one [e]
  (let [r (extract e)]
    (if (= (count r) 1)
      (first r)
      (throw (Exception. (str "Expected a single object when extracting " e " But got " (count r)))))))

(defn extract-type [t]
  (let [r
        (if-let [;; avoid extracting standard types. Return a keyword instead
                 std
                 (get
                  {StdLogic1164/STD_LOGIC "std-logic"
                   StdLogic1164/STD_LOGIC_VECTOR "std-logic-vector"
                   StdLogic1164/STD_ULOGIC "std-ulogic"
                   StdLogic1164/STD_ULOGIC_VECTOR "std-ulogic-vector"} t)]
          {:type :std
           :id std}
          (let [r (extract-type-impl t)
                r (when r
                    (if (instance? NamedEntity t)
                      (assoc r :id (v/id t))
                      r))]
            r))]
    (when r
      (with-meta r {:vobj t}))))

(defn- extract-range [range]
  (let [r (extract-range-impl range)]
    (when r
      (with-meta r {:vobj range}))))

(defn- extract-expression [e]
  (let [r (extract-expression-impl e)]
    r
    ;; some types extract-expression returns, like BigDecimal, can't
    ;; have metadata
    #_(when r
      (with-meta r {:vobj e}))))

(defn- extract-ports [e generics]
  (->> (.getPort e)
       (mapcat
        (fn [p]
          (for [sig (.getVhdlObjects p)]
            (let [id (s/lower-case (v/id sig))]
              [id
               {:id id
                :type (extract-type (.getType sig))
                :dir (mode->key (.getMode sig))}]))))
       (into {})))

(defn- extract-generics [e]
  (->> (.getGeneric e)
       (mapcat
        (fn [g]
          (for [^Constant c (.getVhdlObjects g)]
            [(v/id c)
             {:type (extract-type (.getType c))
              :default-value (.getDefaultValue c)}])))
       (into {})))

(defrecord EnumLiteral [^String name])
(defn enum-literal [name literal]
  (with-meta (->EnumLiteral name) {:vobj literal}))

(def ^:dynamic ^{:private true} *extract-file* nil)

(defn- add-error [msg & args]
  (errors/add-error (str *extract-file* ": " msg))
  nil)

(defn- add-warning [msg & args]
  (errors/add-warning (str *extract-file* ": " msg))
  nil)

(def ^:dynamic ^{:private true} *sei-attributes* nil)

(def ^{:private true} pin-attr-prefix "sei_pin_")
(def ^{:private true} sig-attr-prefix "sei_sig_")

(defn- sei-attr-id? [^String id]
  (.startsWith id pin-attr-prefix))

(defn- sig-attr-id? [^String id]
  (.startsWith id sig-attr-prefix))

(defn- pin-attr-base-name [^String id]
  (keyword
   (s/replace (.substring id (.length pin-attr-prefix)) #"_" "-")))

(defn- pin-attr-value-fn [attr]
  (let [sub-type (:sub-type attr)]
    (case (:type sub-type)
      :enum-type
      (let [literals (:literals sub-type)]
        (fn [x]
          (if-let [x-val
                   (cond
                    (instance? EnumerationLiteral x)
                    (s/upper-case (str x))
                    (instance? CharacterLiteral x)
                    (s/upper-case (str \' (.getCharacter x) \'))
                    :else
                    nil)]
            (if-let [match (some (fn [y]
                                   (when (= x-val
                                            (:name y)) y)) literals)]
              (let [r (:name match)]
                (case (s/lower-case (:id sub-type))
                  "boolean" (Boolean/parseBoolean r)
                  "bit" (Long/parseLong (str (.charAt r 1)))
                  (keyword (s/lower-case r))))
              (add-error (str "Unrecognized enum value \"" x
                              "\" for attribute " (:id attr))))
            (add-error (str "Invalid value \"" x
                            "\" for attribute " (:id attr))))))
      :physical
      (let [decimal-value (fn [x]
                            (when (instance? DecimalLiteral x)
                              (Long/parseLong (.getValue x))))
            {:keys [range primary-unit units]} sub-type
            {:keys [from to dir]} range
            from (decimal-value from)
            to (decimal-value to)
            [from to] (if (= dir :to) [from to] [to from])]
        (when (and from to)
          (fn [x]
            (if (instance? PhysicalLiteral x)
              (let [val (Long/parseLong (.getValue x))
                    unit (s/upper-case (.getUnit x))]

                (when-let [val
                           (cond
                            (= (s/upper-case primary-unit) unit) val
                            (contains? units unit) (long (* val (get units unit)))
                            :else
                            (add-error (str "Invalid units \"" unit
                                            "\" for attribute " (:id attr))))]
                  (if (and (<= from val) (<= val to))
                    val
                    (add-error (str "Invalid value " val
                                    " outside range [" from "-" to "] " primary-unit)))))
              (add-error (str "Invalid value \"" x
                              "\" for attribute " (:id attr)))))))
      :array-type
      (case (s/lower-case (:id sub-type))
        "string"
        (fn [x]
          (if (instance? StringLiteral x)
            (.getString x)
            (add-error (str "Invalid value \"" x
                              "\" for attribute " (:id attr)))))))))

(defn- update-entity
  "Extracts useful declarations from an entity and updates the entity description map."
  [x desc]
  (let [
        decls (doall (mapcat extract
                             ;; only care about certain declaration types
                             (filter (comp #{Group
                                             AttributeSpecification} class)
                                     (.getDeclarations x))))
        group-decls (filter (comp #{:group} :type) decls)
        ;;bus-ports
        #_(->> group-decls
             (filter (comp #{"bus_ports"} :id :template))
             (mapcat :items)
             vec)

        ;;port-groups
        #_(->> group-decls
             (filter (comp #{"local_ports" "global_ports"} :id :template))
             (map
              (fn [grp]
                [(:id grp) (:items grp)]))
             (into {}))

        ;;all-pin-names
        #_(->> (vals port-groups)
             (apply concat)
             (into #{}))
        ;;pins
        #_(->> decls
             (filter #(and (= :attr-spec (:type %))
                           (:attribute %)
                           (pin-attr-id? (:id (:attribute %)))))
             (map
              (fn [attr]
                ;; An attribute can apply to one or more groups of
                ;; signals or one or more signals directly. Determine
                ;; the list of signals that this attribute applies to.
                (let [entities (:entities attr)
                      entities
                      (case entities
                        :all
                        all-pin-names
                        :others
                        (add-error (str "Cannot apply " (:id (:attribute attr))
                                        " to 'others'"))
                        (case (:entity-class attr)
                          :group
                          (mapcat
                           (fn [grp]
                             (get port-groups grp))
                           entities)
                          :signal entities))

                      unknowns (filter (comp not all-pin-names) entities)
                      entities (filter all-pin-names entities)]
                  (doseq [sig unknowns]
                    (add-warning (str "Cannot apply " (:id (:attribute attr))
                                      " to non external port '" sig "'")))
                  [entities [(pin-attr-base-name (:id (:attribute attr)))
                             (:value attr)]])))
             (mapcat (fn [[entities attr]] (for [ent entities] [ent attr])))
             (reduce
              (fn [r [ent [k v]]]
                (assoc-in r [ent k] v))
              (into {} (for [p all-pin-names] [p {}]))))

        ports (:ports desc)

        ;; update ports with pin information
        ;;ports
        #_(reduce
         (fn [ports [name pin-vals]]
           (assoc-in ports [name :pin] pin-vals))
         ports pins)


        update-port-group
        (fn [ports group-name port-key]
          (reduce
           (fn [ports sig]
             (let [sig (s/lower-case sig)]
               (if (contains? ports sig)
                 (assoc-in ports [sig port-key] sig)
                 (do (errors/add-error (str "Unknown port \"" sig
                                            "\" for entity \"" (v/id x) "\""))
                     ports))))
           ports
           (->> group-decls
                (filter (comp #{group-name} :id :template))
                (mapcat :items))))
        
        ports (-> ports
                  ;; update global-signal name for ports in global_ports groups
                  (update-port-group "global_ports" :global-signal)
                  ;; update local-signal name for ports in local_ports groups
                  (update-port-group "local_ports" :local-signal))

        ;; update ports map with information gathered from attributes
        ports (->> decls
                   (filter #(and (= :attr-spec (:type %))
                                 (:attribute %)
                                 (.startsWith (:id (:attribute %)) "sei_port_")))
                   (mapcat
                    (fn [attr]
                      (if (= :signal (:entity-class attr))
                        (map vector
                             (:entities attr)
                             (repeat attr))
                        (add-warning (str "Can only apply sei_port attribute to signal")))))
                   (reduce
                    (fn [ports [port attr]]
                      ;;(println "ATTR" port attr)
                      (if (contains? ports port)
                        (condp = (:id (:attribute attr))
                          "sei_port_global_name"
                          (assoc-in ports [port :global-signal] (s/lower-case (:value attr)))
                          "sei_port_local_name"
                          (assoc-in ports [port :local-signal] (s/lower-case (:value attr)))
                          "sei_port_irq"
                          (assoc-in ports [port :irq?] (:value attr))
                          "sei_port_clock"
                          (assoc-in ports [port :clock?] (:value attr))
                          ports)
                        (do
                          (errors/add-error
                           (str "Unknown port \"" port
                                "\" for entity \"" (v/id x) "\""))
                          ports)))
                    ports))

        ;; find and tag cpu data bus ports based on type and direction
        [desc
         ports]
        (let [db-out (filter #(and (= "cpu_data_i_t" (:id (:type %)))
                                   (= :out (:dir %))) (vals ports))
              db-in (filter #(and (= "cpu_data_o_t" (:id (:type %)))
                                  (= :in (:dir %))) (vals ports))]
          (if (and (= 1 (count db-out))
                   (= 1 (count db-in)))
            [(assoc desc :data-bus true)
             (-> ports
                 (assoc-in [(:id (first db-out)) :data-bus] :out)
                 (assoc-in [(:id (first db-in)) :data-bus] :in))]
            [desc ports]))

        ;; find and tag ring bus ports based on type and direction
        ports
        (reduce
         (fn [ports [n p]]
           (if (#{"rbus_8b" "rbus_9b"} (:id (:type p)))
             (assoc-in ports [n :ring-bus] (:dir p))
             ports))
         ports
         ports)

        ;; find and tag bist ports based on type and direction
        ports
        (let [bist-ports (filter #(= "bist_scan_t" (:id (:type %))) (vals ports))
              bist-out (filter #(= :out (:dir %)) bist-ports)
              bist-in  (filter #(= :in (:dir %)) bist-ports)]
          (if (and (= 1 (count bist-out))
                   (= 1 (count bist-in)))
            (-> ports
                (assoc-in [(:id (first bist-out)) :bist-chain] :out)
                (assoc-in [(:id (first bist-in)) :bist-chain] :in))
            ports))

        find-sig-ports
        (fn [ports sig-name port-names]
          (let [port-options (select-keys ports port-names)
                port-name (when (= 1 (count port-options))
                            (key (first port-options)))]
            (if (and port-name
                     ;; avoid mapping a port to signal that another
                     ;; port connects to
                     (not (some #{sig-name} (map :global-signal (vals ports))))
                     ;; avoid changing an existing global signal
                     (nil? (get-in ports [port-name :global-signal])))
              (assoc-in ports [port-name :global-signal] sig-name)
              ports)))

        ;; try to guess global signals by port name if they weren't
        ;; specified
        ;; TODO: Should this also take into account the port type?
        ports
        (-> ports
            (find-sig-ports "reset" ["rst" "reset"])
            (find-sig-ports "clk_sys" ["clk" "clk_bus"]))

        peripheral-bus
        (when-let [periphs (seq (filter (comp #{"peripheral_bus"} :id :template) group-decls))]
          (into {} (map (fn [p] [(:id p) (:items p)]) periphs)))

        ;; override global signal names of peripheral bus ports
        ports
        (reduce
         (fn [ports [bus-name port-name]]
           (if-let [dir (get-in ports [port-name :dir])]
             (assoc-in ports [port-name :global-signal]
                       (s/join "_" [bus-name "periph_dbus" (first (name dir))]))
             ports))
         ports
         (mapcat
          (fn [[a b]] (map vector (repeat a) b))
          peripheral-bus))]

    ;; validate info. Check that described ports actually exist
    #_(let [port-names (into #{} (keys ports))]
      (doseq [p (keys pins)]
        (when (not (contains? port-names p))
          (errors/add-error (str "Unknown local port \"" p
                                 "\" for entity \"" (v/id x) "\""))))
      #_(doseq [p bus-ports]
        (when (not (contains? port-names p))
          (errors/add-error (str "Unknown bus port \"" p
                                 "\" for entity \"" (v/id x) "\"")))))
    (when peripheral-bus
      (doseq [[n ps] peripheral-bus]
        (if-not (and (= (count ps) 2)
                     (= #{["cpu_data_o_t" :out]
                          ["cpu_data_i_t" :in]}
                        (set (map (juxt #(get-in % [:type :id]) :dir)
                                  (vals (select-keys ports ps))))))
          (errors/add-error (str "Invalid peripheral_bus \"" n
                                 "\" for entity \"" (v/id x) "\"")))))
    (assoc
     desc
     :ports ports
     :peripheral-bus peripheral-bus
     ;;:decls decls
     ;;:bus-ports bus-ports
     )))

(extend-protocol ExtractVhdl
  Component
  (extract-impl [c]
    (let [generics (extract-generics c)]
      [{:type :component
        :generics generics
        :ports (extract-ports c generics)}]))
  AttributeSpecification
  (extract-impl [a]
    [(let [r (extract-one (.getAttribute a))
           attr (get @*sei-attributes* (:id r))
           foo
           {:type :attr-spec
            :attribute attr
            :entity-class (entityclass->key (.getEntityClass a))
            :entities
            (let [ents (.getEntities a)]
              (cond
               (= ents AttributeSpecification$EntityNameList/ALL) :all
               (= ents AttributeSpecification$EntityNameList/OTHERS) :others
               :else
               (mapv (fn [x] (.getEntityTag x))
                     ;; There is (.getSignature x) but what is the signature?
                     (.getDesignators ents))))
            :value
            ((or (:value-fn (meta attr)) identity)
             (.getValue a))}]
       foo)])
  Attribute
  (extract-impl [a]
    [{:type :attr
      :sub-type (extract-type (.getType a))}])
  Group
  (extract-impl [g]
    [{:type :group
      :template (extract-one (.getTemplate g))
      :items
      ;; Seems a bug in vmagic returns constituents containing commas.
      (vec
       (->> (.getConstituents g)
            (mapcat #(s/split % #","))
            (map s/trim)))}])
  GroupTemplate
  (extract-impl [g]
    [{:type :group-template
      :entity-classes (mapv entityclass->key (.getEntityClasses g))
      :repeat-last (.isRepeatLast g)}])
  PackageDeclaration
  (extract-impl [pkg]
    (let [decls (doall (mapcat extract (v/declarations pkg)))]
      ;; store pin attribute declarations in an atom for later use
      (doseq [d decls
              :when (and (= (:type d) :attr)
                         (or (.startsWith (:id d) "sei_")))]
        (swap! *sei-attributes* assoc (:id d)
               (with-meta d
                 (assoc (meta d)
                   :value-fn (pin-attr-value-fn d)))))
      ;; TODO: this is the only extract-impl that returns multiple
      ;; things. Should the extract declarations instead be inside the
      ;; package declaration map?
      (conj decls
            {:type :package-declaration
             :id (v/id pkg)
             :decls (->> (v/declarations pkg)
                         (map #(cond (instance? NamedEntity %) (v/id %)) )
                         (filter identity)
                         vec)})))
  ConstantDeclaration
  (extract-impl [cd]
    (mapv
     (fn [c]
       {:type :constant
        :id (v/id c)
        :subtype (extract-type (.getType c))
        :value (.getDefaultValue c)})
     (.getObjects cd)))
  Entity
  (extract-impl [entity]
    (let [generics (extract-generics entity)
          entity (update-entity entity
                    {:type :entity
                     :generics generics
                     :ports (extract-ports entity generics)})]
      [entity]))
  Architecture
  (extract-impl [arch]
    [(merge
      {:type :architecture
       ;;:entity (extract-one (.getEntity arch))
       :entity (v/id (.getEntity arch))})])
  SubtypeIndication
  (extract-impl [x]
    [(extract-type x)])
  LibraryClause
  (extract-impl [x]
    [{:type :library-clause
      :libs (vec (.getLibraries x))}])
  UseClause
  (extract-impl [x]
    [{:type :use-clause
      :libs (vec (.getDeclarations x))}])
  Configuration
  (extract-impl [x]
    (let [bc (.getBlockConfiguration x)]
      (when (instance? ArchitectureConfiguration bc)
        [{:type :configuration
          :entity (v/get-id (.getEntity x))
          :architecture (v/get-id (.getArchitecture bc))}]))))

(extend-protocol ExtractVhdlType
  RecordType
  (extract-type-impl [e]
    {:type :record
     :fields
     (into
      {}
      (mapcat
       (fn [elem]
         (map (fn [id]
                [id
                 (extract-type (.getType elem))])
              (.getIdentifiers elem)))
       (v/elements e)))})
  ArrayType
  (extract-type-impl [x]
    {:type :array-type})
  EnumerationType
  (extract-type-impl [x]
    {:type :enum-type
     :literals
     (mapv
      (fn [l]
        (let [s (s/upper-case (str l))
              ;;s (if-let [[_ c] (re-matches #"^'(.*)'$" s)] c s)
              ]
          (enum-literal s l)))
      (.getLiterals x))})
  Subtype
  (extract-type-impl [x]
    {:type :sub-type
     :sub-type (extract-type (.getSubtypeIndication x))})
  IndexSubtypeIndication
  (extract-type-impl [x]
    {:type :index-sub-type
     :base (extract-type (.getBaseType x))
     :ranges (mapv extract-range (.getRanges x))})
  RangeSubtypeIndication
  (extract-type-impl [x]
    {:type :range-sub-type
     :base (extract-type (.getBaseType x))
     :range (extract-range (.getRange x))})
  IntegerType
  (extract-type-impl [x]
    {:type :integer
     :range (extract-range (.getRange x))})
  PhysicalType
  (extract-type-impl [x]
    (let [r
          {:type :physical
           :range (extract-range (.getRange x))
           :primary-unit (.getPrimaryUnit x)
           :units (->> (.getUnits x)
                       (map (fn [u] [(s/upper-case (v/id u))
                                    ;; assume factor is a DecimalLiteral
                                    (Double/parseDouble (.getValue (.getFactor u)))]))
                       (into {}))}]
      ;;(println "physical" r)
      r))
  UnresolvedType
  (extract-type-impl [x]
    {:type :unresolved}))

(extend-protocol ExtractVhdlRange
  Range
  (extract-range-impl [r]
    {:from (extract-expression (.getFrom r))
     :to (extract-expression (.getTo r))
     :dir (direction->key (.getDirection r))}))

(extend-protocol ExtractVhdlExpression
  DecimalLiteral
  (extract-expression-impl [e]
    (bigdec (.getValue e)))
  AddingExpression
  (extract-expression-impl [e]
    [(cond (instance? Add e) '+
           (instance? Subtract e) '-
           :else e)
     (extract-expression (.getLeft e))
     (extract-expression (.getRight e))])
  Constant
  (extract-expression-impl [e]
    (v/id e))
  Object
  (extract-expression-impl [e]
    e))

(defn- extract-file
  "Pull components, entities, types and attributes out of files"
  [name file]
  (binding [*extract-file* name]
    (when (some nil? (v/elements file))
      (println "NIL FOUND IN" name (vec (v/elements file)))
      (add-error (str *extract-file* ": Null in file elements returned by parser")))

    (->> (v/elements file)
         (mapcat extract)
         (filter identity)
         ;; preserve the relationship between library and use
         ;; clauses and the things that follow them, chiefly
         ;; entities.
         (concat [nil]) ;; add initial nil to left first real elem
         ;; be the second in a pair after partition below
         (partition-by
          (fn [e]
            (if (#{:library-clause :use-clause} (:type e))
              true
              e)))
         (partition 2 1) ;; pair up each element with each of it's neighbours
         (map
          ;; combine entities with previous lib and use clauses
          (fn [[lib-uses entity]]
            (let [entity (first entity)]
              ;; check if a lib/use followed by entity
              (if (and (= :entity (:type entity))
                       (#{:library-clause :use-clause} (:type (first lib-uses))))
                ;; add used lib names to each entity
                (assoc entity
                  :uses (vec (mapcat :libs (filter #(= :use-clause (:type %)) lib-uses))))
                entity))))
         (filter identity)
         vec)))

(defn- pre-parse-file [f]
  (with-open [rdr (jio/reader f)]
    (let [lines (line-seq rdr)

          ;; ignore lines wrapped in -- synopsys translate_off --
          ;; synopsys translate_on comments
          [_ lines]
          (reduce
           (fn [[ignore lines] line]
             (if ignore
               ;; ignore line and look for translate_on
               [(not (boolean (re-matches #"\s*--\s*synopsys\s+translate_on\s*" line))) lines]
               ;; collect line and look for translate_off
               [(boolean (re-matches #"\s*--\s*synopsys\s+translate_off\s*" line)) (conj lines line)]))
           [false []]
           lines)

          [lines _]
          (reduce
           (fn [[r uses] line]
             (let [line (s/lower-case line)]
               (or
                (when-let [[_ pkg] (re-matches #"\s*package\s+(\S+)(?:\s*|\s+.*)" line)]
                  [(conj r {:type :package :name pkg :uses uses}) []])
                (when-let [[_ entity] (re-matches #"\s*entity\s+(\S+)(?:\s*|\s+.*)" line)]
                  [(conj r {:type :entity :name entity :uses uses}) []])
                (when-let [[_ pkg] (re-matches #"\s*use\s+work\.([^.]+)\..*" line)]
                  [r (conj uses pkg)])
                (when-let [[_ arch entity]
                           (re-matches #"\s*architecture\s+(\S+)\s+of\s+(\S+)(?:|\s+.*)" line)]
                  [(conj r {:type :architecture :name arch :entity entity :uses uses}) []])
                (when-let [[_ config entity]
                           (re-matches #"\s*configuration\s+(\S+)\s+of\s+(\S+)(?:|\s+.*)" line)]
                  [(conj r {:type :configuration :name config :entity entity :uses uses}) []])
                [r uses])))
           [[] []]
           lines)]
      lines)))

(defn- dependency-order
  "Pre-parse the vhdl files to find packages, entities, architectures,
  and use statements to determine which files to parse in what order.
  The order is important so that vmagic will resolve things referenced
  from other packages."
  [file-names & {ents-to-find :entities}]
  (let [info-list
        (->> file-names
             (mapcat
              (fn [path]
                (let [f (jio/file path)]
                  (if (.canRead f)
                    (try
                      (map
                       (fn [info]
                         (assoc info :path path))
                       (pre-parse-file f))
                      (catch Exception e
                        (clojure.stacktrace/e)
                        (errors/add-error (str "Cannot preparse " path))))
                    (errors/add-error (str "Cannot read " path)))))))

        packages (into {} (for [i (filter (comp #{:package} :type) info-list)] [(:name i) i]))
        entities (into {} (for [i (filter (comp #{:entity} :type) info-list)] [(:name i) i]))

        ;; check for references to missing packages and entities
        info-list
        (map
         (fn [info]
           (let [uses (:uses info)
                 entity (:entity info)
                 info (assoc info :uses (vec (filter #(contains? packages %) uses)))
                 info (if (or (nil? entity) (get entities entity))
                        info
                        (do
                          (errors/add-error
                           (str "Cannot find entity " entity " referenced by " (:path info)))
                          (dissoc info :entity)))]
             (when-let [missing (seq (filter #(not (contains? packages %)) uses))]
               (errors/add-error
                (str "Cannot find packages "
                     (s/join ", " (map #(str "work." %) missing))
                     " referenced by " (:path info))))
             info))
         info-list)

        graph-depends
        (fn [g from tos]
          (if (seq tos)
            (reduce
             (fn [g to]
               (dep/depend g from to))
             g tos)
            ;; depend on nil when there are no tos
            (dep/depend g from nil)))

        build-graph
        (fn [objs]
          (reduce
           (fn [g info]
             (graph-depends
              g
              info
              (concat
               ;; depend on each package used
               (map packages (:uses info))
               ;; depend on entity used if referenced
               (when-let [ent (get entities (:entity info))]
                 (conj
                  ;; also depend on the uses of the entity
                  (map packages (:uses ent))
                  ent)))))
           (dep/graph)
           objs))

        ;; build dependency graph of everything
        graph (build-graph info-list)

        ;; find transitive dependencies from entities we are
        ;; interested in
        ents-to-find (set (map s/lower-case ents-to-find))

        ;; create a new, smaller graph that doesn't contain entities
        ;; we're not interested in. The smaller graph uses file paths
        ;; for nodes.
        limited-graph
        (->> (dep/nodes graph)
             (remove nil?)

             ;; select subset of nodes related to certain entities
             (mapcat
              (fn [node]
                (when-let [entity-name
                         (if (= :entity (:type node))
                           (:name node)
                           (:entity node))]
                  (if (contains? ents-to-find entity-name)
                    (conj (remove nil? (dep/transitive-dependencies graph node))
                          node)))))
             (into #{})
             ;; build new smaller graph of paths
             (reduce
              (fn [g node]
                (graph-depends g (:path node)
                               (filter #(not= (:path node) %)
                                       (map :path (dep/immediate-dependencies graph node)))))
              (dep/graph)))

        files (remove nil? (dep/topo-sort limited-graph))]
    (println "Parsing" (count files) "files related to entities:" (s/join ", " (sort ents-to-find)))
    files))

(defn- common-directory
  "return the common directory that the given file paths are in"
  [paths]
  (->> paths
       (map #(-> (jio/file %)
                 (.getCanonicalFile)
                 (.getParent)
                 (s/split (re-pattern java.io.File/separator))))
       (apply map (comp set vector))
       (take-while #(= 1 (count %)))
       (map first)
       (s/join java.io.File/separator)))

(defn extract-all [file-names & opts]
  (errors/wrap-errors
   (binding [*sei-attributes* (atom {})]
     (let [common (common-directory file-names)
           file-names (apply dependency-order file-names opts)
           parsed-files (parse-files file-names common)
           ;; Extract all useful information from the parsed-files.
           ;; Move it out of vmagic classes and into clj data structures

           ;; We're assuming a global namespace for components and type
           ;; names (including enumerations, record types, subtypes,
           ;; arrays). Our VHDL doesn't overload names in different
           ;; packages. However, we do find which packages are needed
           ;; to be used to use an entity and its ports.
           all-data (doall
                     (->> file-names
                          (mapcat #(when-let [f (get parsed-files %)]
                                     (extract-file % f)))
                          (filter identity)))]
       (if (errors/dump)
         nil
         {:files parsed-files
          :data all-data})))))
