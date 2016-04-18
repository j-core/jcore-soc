(ns soc-gen.vmagic
  (:require [clojure.string :as s]
            [clojure.java.io :as jio])
  (:import
   clojure.lang.Keyword
   clojure.lang.Symbol
   [de.upb.hni.vmagic
    VhdlElement
    VhdlFile
    AssociationElement
    DiscreteRange
    Range
    Range$Direction
    Choice
    Choices
    WaveformElement
    NamedEntity]
   [de.upb.hni.vmagic.util
    VhdlCollections
    Comments]
   [de.upb.hni.vmagic.statement
    AssertionStatement
    CaseStatement
    CaseStatement$Alternative
    ExitStatement
    ForStatement
    IfStatement
    LoopStatement
    NextStatement
    NullStatement
    ProcedureCall
    ReportStatement
    ReturnStatement
    SequentialStatement
    SequentialStatementVisitor
    SignalAssignment
    VariableAssignment
    WaitStatement
    WhileStatement]
   [de.upb.hni.vmagic.expression
    Abs
    Add
    AddingExpression
    Aggregate
    Aggregate$ElementAssociation
    And
    BinaryExpression
    Concatenate
    Divide
    Equals
    Expression
    Expressions
    ExpressionVisitor
    FunctionCall
    GreaterEquals
    GreaterThan
    LessEquals
    LessThan
    Literal
    LogicalExpression
    Minus
    Mod
    Multiply
    MultiplyingExpression
    Name
    Nand
    Nor
    Not
    NotEquals
    Or
    Parentheses
    Plus
    Pow
    Primary
    QualifiedExpression
    QualifiedExpressionAllocator
    RelationalExpression
    Rem
    Rol
    Ror
    ShiftExpression
    Sla
    Sll
    Sra
    Srl
    Subtract
    SubtypeIndicationAllocator
    TypeConversion
    UnaryExpression
    Xnor
    Xor]
   [de.upb.hni.vmagic.libraryunit
    Architecture
    Configuration
    Entity
    LibraryClause
    LibraryUnit
    LibraryUnitVisitor
    PackageBody
    PackageDeclaration
    UseClause]
   [de.upb.hni.vmagic.declaration
    SubprogramBody
    FunctionBody
    FunctionDeclaration
    SignalDeclaration
    ConstantDeclaration
    VariableDeclaration
    Component
    Subtype
    Attribute
    AttributeSpecification
    AttributeSpecification$EntityNameList
    AttributeSpecification$EntityNameList$EntityDesignator
    EntityClass]
   [de.upb.hni.vmagic.builtin
    Libraries
    NumericStd
    SignalAttributes
    Standard
    StdLogic1164
    StdLogicArith
    StdLogicSigned
    StdLogicUnsigned]
   [de.upb.hni.vmagic.literal
    AbstractLiteral
    BasedLiteral
    BinaryLiteral
    CharacterLiteral
    DecimalLiteral
    EnumerationLiteral
    HexLiteral
    Literals
    OctalLiteral
    PhysicalLiteral
    StringLiteral]
   [de.upb.hni.vmagic.type
    Type
    ConstrainedArray
    UnconstrainedArray
    IntegerType
    SubtypeIndication
    IndexSubtypeIndication
    RangeSubtypeIndication
    RecordType
    RecordType$ElementDeclaration
    EnumerationType]
   [de.upb.hni.vmagic.object
    Constant
    Slice
    VhdlObject
    VhdlObject$Mode
    VhdlObjectProvider
    Signal
    ArrayElement
    RecordElement
    Variable
    SignalAssignmentTarget
    VariableAssignmentTarget
    AttributeExpression]
   [de.upb.hni.vmagic.output
    VhdlOutput]
   [de.upb.hni.vmagic.concurrent
    ProcessStatement
    ConditionalSignalAssignment
    ConditionalSignalAssignment$ConditionalWaveformElement
    SelectedSignalAssignment
    SelectedSignalAssignment$SelectedWaveform
    SelectedSignalAssignment
    AbstractComponentInstantiation
    ComponentInstantiation
    EntityInstantiation
    ArchitectureInstantiation
    ConfigurationInstantiation
    AbstractGenerateStatement
    ForGenerateStatement
    IfGenerateStatement]))


(defn vobj [x]
  (:vobj (meta x)))

(defn set-vobj [x v]
  (when x
    (with-meta
      x
      (if v
        (assoc (meta x) :vobj v)
        (dissoc (meta x) :vobj)))))

(defn set-comments [entity & comments]
  (let [all-entities (filter identity (flatten [entity]))
        comments (filter identity comments)]
    (when (and (seq all-entities) (seq comments))
      (Comments/setComments (first all-entities) (into-array (map #(str " " %) comments)))))
  entity)

(defn vrange [a dir b]
  (Range. a (case dir :downto Range$Direction/DOWNTO :to Range$Direction/TO) b))

(defn range-to [a b] (vrange a :to b))
(defn range-downto [a b] (vrange a :downto b))

(def others-choice Choices/OTHERS)
(defn choices [& r]
  (into-array Choice r))

(def std-logic StdLogic1164/STD_LOGIC)
(def std-logic-0 StdLogic1164/STD_LOGIC_0)
(def std-logic-1 StdLogic1164/STD_LOGIC_1)
(defn std-logic-literal [x]
  ({0 std-logic-0
    "0" std-logic-0
    false std-logic-0
    1 std-logic-1
    "1" std-logic-1
    true std-logic-1} x))

(defn std-logic-vector
  ([n] (StdLogic1164/STD_LOGIC_VECTOR n))
  ([l r] (std-logic-vector l :downto r))
  ([l dir r] (StdLogic1164/STD_LOGIC_VECTOR (vrange l dir r))))

(defn func-dec [name return-type & args]
  (FunctionDeclaration. name return-type
                        (into-array VhdlObjectProvider
                                    (for [[name type] args]
                                      (Constant. name type)))))

(defn func-body
  ([func-dec]
     (FunctionBody. func-dec))
  ([name return-type & args]
     (func-body (apply func-dec name return-type args))))

(defn func-call [fn & args]
  (let [call (FunctionCall. fn)
        params (.getParameters call)]
    (doseq [arg args]
      (.add params arg))
    call))

(defn assoc-elem
  ([n] (AssociationElement. n))
  ([n v] (AssociationElement. n v)))

(defn func-call-pos [fn & args]
  (apply func-call fn (map assoc-elem args)))

(defn clj-name [name]
  (s/lower-case
   (s/replace
    (if-let [[m _ n]
             (re-matches
              #"(id_|ex_|wb_|)(.*)" name)]
      n
      name)
    #"_" "-")))

(defn vhdl-name ^String [n]
  (s/replace (if (keyword? n) (name n) n)  #"-" "_"))

(def std-match
  (func-dec "std_match" Standard/BOOLEAN
            ["L" StdLogic1164/STD_LOGIC_VECTOR]
            ["R" StdLogic1164/STD_LOGIC_VECTOR]))

(defprotocol ListInside
  (declarations ^java.util.List [e])
  (statements ^java.util.List [e])
  (else-statements ^java.util.List [e])
  (elements ^java.util.List [e])
  (sensitivities ^java.util.List [e])
  (generics ^java.util.List [e])
  (ports ^java.util.List [e])
  (port-map ^java.util.List [e])
  (generic-map ^java.util.List [e]))

(defprotocol ValueOf
  (zero-val ^Expression [e])
  (num-val ^Expression [e v]))

(defprotocol VHDLType
  (type-of [e]))

(defprotocol Copyable
  (copy [e]))

(defprotocol Assignable
  (assign [e v])
  (varassign [e v]))

(extend-type Architecture
  ListInside
  (declarations [e] (.getDeclarations e))
  (statements [e] (.getStatements e)))

(extend-type Entity
  ListInside
  (declarations [e] (.getDeclarations e))
  (statements [e] (.getStatements e))
  (generics [e] (.getGeneric e))
  (ports [e] (.getPort e)))

(extend-type Component
  ListInside
  (generics [e] (.getGeneric e))
  (ports [e] (.getPort e)))

(extend-type ProcessStatement
  ListInside
  (declarations [e] (.getDeclarations e))
  (statements [e] (.getStatements e))
  (sensitivities [e] (.getSensitivityList e)))

(extend-type PackageDeclaration
  ListInside
  (declarations [e] (.getDeclarations e)))

(extend-type PackageBody
  ListInside
  (declarations [e] (.getDeclarations e)))

(extend-type VhdlFile
  ListInside
  (elements [e] (.getElements e)))

(extend-type de.upb.hni.vmagic.statement.IfStatement
  ListInside
  (statements [e] (.getStatements e))
  (else-statements [e] (.getElseStatements e)))

(extend-type de.upb.hni.vmagic.statement.IfStatement$ElsifPart
  ListInside
  (statements [e] (.getStatements e)))

(extend-type SubprogramBody
  ListInside
  (declarations [e] (.getDeclarations e))
  (statements [e] (.getStatements e)))

(extend-type AbstractGenerateStatement
  ListInside
  (declarations [e] (.getDeclarations e))
  (statements [e] (.getStatements e)))

(defn get-id [#^NamedEntity e] (s/lower-case (.getIdentifier e)))

(defn id [#^NamedEntity e] (s/lower-case (.getIdentifier e)))

(defn add-all [entity list-fn & args]
  (let [args (filter identity (flatten args))]
    (if (seq args)
      (.addAll ^java.util.List (list-fn entity) args)))
  entity)

(defn signal
  ([name type default]
   (let [type (cond
                (instance? Signal type) (.getType type)
                :else type)]
       (Signal. name type default)))
  ([name type]
     (let [type (cond
                 (instance? Signal type) (.getType type)
                 :else type)]
       (Signal. name type))))

(defn variable
  ([name type default]
     (Variable. name type default))
  ([name type]
     (Variable. name type)))

(defn signal-decl
  ([sig]
     (SignalDeclaration. (into-array [sig])))
  ([name type]
     (signal-decl (signal name type))))

(defn add-declarations [entity & args]
  (apply add-all entity declarations
           (->> (flatten args)
                (filter identity)
                (map (fn [d]
                       (let [r
                             (cond
                              (instance? Constant d)
                              (ConstantDeclaration. (into-array [d]))
                              (instance? Signal d)
                              (signal-decl d)
                              (instance? Variable d)
                              (VariableDeclaration. (into-array [d])))]
                         ;; transfer comments to the declaration
                         (if (and r (seq (Comments/getComments d)))
                           (Comments/setComments r (Comments/getComments d)))
                         (or r d)))))))

(defn assign-zero [s]
  (assign s (zero-val s)))

(defn varassign-zero [s]
  (varassign s (zero-val s)))

(defn- bad-zero [e]
  (throw (UnsupportedOperationException. (str "Cannot zero " e))))

(defn- bad-value [e v]
  (throw (UnsupportedOperationException. (str "Cannot assign " v " to " e))))

(extend-type Subtype
  ValueOf
  (zero-val [e]
    (cond
     (= std-logic e) StdLogic1164/STD_LOGIC_0
     :else (zero-val (.getSubtypeIndication e))))
  (num-val [e v]
    (cond
     (= std-logic e)
     (case v
       0 StdLogic1164/STD_LOGIC_0
       1 StdLogic1164/STD_LOGIC_1)
     :else (num-val (.getSubtypeIndication e) v)))
  VHDLType
  (type-of [e]
    (cond
     (= std-logic e) std-logic
     :else (bad-zero e))))

(extend-type IntegerType
  ValueOf
  (zero-val [e] (DecimalLiteral. 0))
  (num-val [e v] (DecimalLiteral. (str v))))

(extend-type RangeSubtypeIndication
  ValueOf
  (zero-val [e] (zero-val (.getBaseType e)))
  (num-val [e v] (num-val (.getBaseType e) v)))

(defn abs [x]
  (if (< x 0) (- x) x))

(defn- zero-pad [s width]
  (if (> (count s) width)
    (.substring s (- (count s) width))
    (str (apply str (repeat (max 0 (- width (count s))) "0")) s)))

(defn- num-literal [width val]
  (if (zero? (mod width 4))
    ;; output hex string
    (HexLiteral. (zero-pad (Long/toHexString val) (quot width 4)))
    (StringLiteral. (zero-pad (Long/toBinaryString val) width))))

(extend-type IndexSubtypeIndication
  ValueOf
  (zero-val [e]
    (cond
     (and #_(= StdLogic1164/STD_LOGIC (.getBaseType e))
          (= 1 (count (.getRanges e))))
     (Aggregate/OTHERS StdLogic1164/STD_LOGIC_0)
     :else (bad-zero e)))
  (num-val [e v]
    (cond
     (and #_(= StdLogic1164/STD_LOGIC (.getBaseType e))
          (= 1 (count (.getRanges e))))
     (let [r (first (.getRanges e))
           f (.getFrom r)
           t (.getTo r)]
       (if (and (instance? DecimalLiteral f)
                (instance? DecimalLiteral t))
         (let [n (inc (abs (- (Integer/parseInt (.getValue f))
                              (Integer/parseInt (.getValue t)))))]
           (num-literal n v))
         (bad-value e v)))
     :else (bad-value e v))))

(extend-type RecordType
  ListInside
  (elements [e] (.getElements e))
  ValueOf
  (zero-val [e]
    (let [agg (Aggregate.)]
      (doseq [elem (.getElements e)
              ident (.getIdentifiers elem)]
        (.createAssociation agg (zero-val (.getType elem)) (choices (Constant. ident (.getType elem)) )))
      agg)))

(extend-type EnumerationType
  ValueOf
  (zero-val [e]
    (first (.getLiterals e))))

(extend-type AbstractComponentInstantiation
  ListInside
  (port-map [e] (.getPortMap e))
  (generic-map [e] (.getGenericMap e)))

(extend-type Signal
  ValueOf
  (zero-val [e]
    (zero-val (.getType e)))
  (num-val [e v]
    (num-val (.getType e) v))
  VHDLType
  (type-of [e]
    (.getType e))
  Copyable
  (copy [e]
    (Signal. (.getIdentifier e) (.getMode e) (.getType e) (.getDefaultValue e))))

(extend-type Variable
  ValueOf
  (zero-val [e]
    (zero-val (.getType e)))
  (num-val [e v]
    (num-val (.getType e) v))
  VHDLType
  (type-of [e]
    (.getType e))
  Copyable
  (copy [e]
    (Variable. (.getIdentifier e) (.getType e) (.getDefaultValue e))))

(extend-type ConstrainedArray
  ValueOf
  (zero-val [e]
    (if (not= 1 (count (.getIndexRanges e)))
      (bad-zero e)
      (let [r (first (.getIndexRanges e))]
        (if (and (= std-logic (.getElementType e))
                 (instance? Range r)
                 (instance? DecimalLiteral (.getFrom r))
                 (instance? DecimalLiteral (.getTo r)))
          (num-literal (inc (Math/abs (- (Long/parseLong (.getValue (.getFrom r)))
                                         (Long/parseLong (.getValue (.getTo r))))))
                       0)
          (Aggregate/OTHERS (zero-val (.getElementType e)))))))
  (num-val [e v]
    (if (and (= std-logic (.getElementType e))
             (= 1 (count (.getIndexRanges e))))
      (let [r (first (.getIndexRanges e))
            from (.getFrom r)
            to (.getTo r)]
        (if (and
             (instance? DecimalLiteral from)
             (instance? DecimalLiteral to))
          (num-literal (inc (Math/abs (- (Long/parseLong (.getValue from))
                                         (Long/parseLong (.getValue to)))))
                       v)
          (bad-value e v)))     
      (bad-value e v))))

(defn- assign-fn [s v]
  (SignalAssignment. s (if (number? v) (num-val s v) v)))
(defn- varassign-fn [s v]
  (VariableAssignment. s (if (number? v) (num-val s v) v)))

(extend Signal
  Assignable
  {:assign assign-fn})

(extend Variable
  Assignable
  {:varassign varassign-fn})

(doseq [cls [Aggregate ArrayElement Slice RecordElement]]
  (extend cls
    Assignable
    {:assign assign-fn
     :varassign varassign-fn}))

(defn record-element-type
  "Return the type of a RecordType element. The getType method in
  RecordType doesn't work."
  [^RecordElement elem]
  (let [name (.getElement elem)]
    (some (fn [^RecordType$ElementDeclaration e]
            (when (some #(= name %) (.getIdentifiers e))
              (.getType e)))
          (elements (.getType (.getPrefix elem))))))

(extend-type RecordElement
  ValueOf
  (zero-val [e]
    (zero-val (record-element-type e)))
  (num-val [e v]
    (num-val (record-element-type e) v))
  VHDLType
  (type-of [e]
    (record-element-type e)))

(extend-type IndexSubtypeIndication
  VHDLType
  (type-of [e]
    (.getBaseType e)))

#_(defn array-element-type
  "Return the type of an ArrayElement element. The getType method in
  ArrayElement doesn't work."
  [^ArrayElement elem]
  (println elem (.getPrefix elem) (type-of (type-of (.getPrefix elem))))
  (.getElementType (.getPrefix elem))
  #_(let [array (.getPrefix elem)
        array-type (.getType array)]
    (if (and (instance? IndexSubtypeIndication array-type)
             (= (count (.getRanges array-type))
                (count (.getIndices elem))))
      (.getBaseType array-type)
      (throw (IllegalStateException. (str "Unable to determine type of array" elem array))))))

#_(extend-type ArrayElement
  ValueOf
  (zero-val [e]
    (zero-val (array-element-type e)))
  (num-val [e v]
    (num-val (array-element-type e) v))
  VHDLType
  (type-of [e]
    (array-element-type e)))

(extend-type LoopStatement
  ListInside
  (statements [e] (.getStatements e)))

(extend-type CaseStatement$Alternative
  ListInside
  (statements [e] (.getStatements e)))

(defn if-stmt [& cond-body]
  (when (< (count cond-body) 2)
    (throw (Exception. "if-stmt must take more than 1 argument")))
  (let [[c1 b1 & cond-body] cond-body
        stmt (add-all (IfStatement. c1) statements b1)]
    (doseq [[c b] (partition 2 cond-body)]
      (add-all (.createElsifPart stmt c) statements b))
    (when (not (even? (count cond-body)))
      (add-all stmt else-statements (last cond-body)))
    stmt))

(defn cond-assign [sig & val-conds]
  (ConditionalSignalAssignment.
   sig
   (->> val-conds
        (map #(if (number? %) (num-val sig %) %))
        (partition 2 2 [nil])
        (map (fn [[val cond]]
               (ConditionalSignalAssignment$ConditionalWaveformElement.
                [(WaveformElement. (if (number? val) (num-val sig val) val))]
                cond))))))

(defn select-assign [target expr & val-cmpvals]
  (let [stmt (SelectedSignalAssignment.
              expr target)]
    (.addAll (.getSelectedWaveforms stmt)
      (->> val-cmpvals
           ;; convert numbers to proper values
           (partition 2 2 [Choices/OTHERS])
           (map (fn [[a b]] [(if (number? a) (num-val target a) a)
                            (map #(if (number? %) (num-val expr %) %) (if (vector? b) b [b]))]))
           (map (fn [[a bs]]
                  (SelectedSignalAssignment$SelectedWaveform. a (into-array bs))))))
    stmt))

(defn rec-elem [record & names]
  (case (count names)
    0 (throw (IllegalArgumentException. "rec elem needs at least one name"))
    1 (RecordElement. record (first names))
    (apply rec-elem (RecordElement. record (first names)) (rest names))))

(defn binary-exp [f]
  (fn [a & bs]
    (if-let [r (reduce
                (fn [a b]
                  (cond
                   (and a b) (f a b)
                   a a
                   b b))
                a bs)]
      r
      (throw (NullPointerException. "All arguments nil")))))

(defn binary-exp-paren [f]
  (let [fr (binary-exp f)]
    (fn [a & args]
      (let [r (apply fr a args)]
        (if (= a r)
          r
          (Parentheses. r))))))

(def v-or (binary-exp-paren #(Or. %1 %2)))
(def v-and (binary-exp-paren #(And. %1 %2)))
(def v-xor (binary-exp-paren #(Xor. %1 %2)))
(def v-nor (binary-exp-paren #(Nor. %1 %2)))
(def v-nand (binary-exp-paren #(Nand. %1 %2)))
(def v-xnor (binary-exp-paren #(Xnor. %1 %2)))
(def v-+ (binary-exp-paren #(Add. %1 %2)))

(def v-cat (binary-exp #(Concatenate. %1 %2)))
(defn v-not [exp] (Not. exp))

(defn- unify-nums [a b]
  [(if (number? a) (num-val b a) a)
   (if (number? b) (num-val a b) b)])

(defn v= [a b]
  (let [[a b] (unify-nums a b)]
    (Equals. a b)))
(defn vnot= [a b]
  (let [[a b] (unify-nums a b)]
    (NotEquals. a b)))

(defn- set-mode [mode sigs]
  (doseq [^Signal s (flatten sigs)]
    (.setMode s mode))
  sigs)

(defn add-in-ports [entity args]
  (add-all entity ports
           (set-mode VhdlObject$Mode/IN (map copy args))))

(defn add-out-ports [entity args]
  (add-all entity ports
           (set-mode VhdlObject$Mode/OUT (map copy args))))

(defn add-inout-ports [entity args]
  (add-all entity ports
           (set-mode VhdlObject$Mode/INOUT (map copy args))))

(defn literal [x]
  (cond
   (string? x) (StringLiteral. x)
   (integer? x) (DecimalLiteral. x)
   (instance? Double x) (DecimalLiteral. (str x))
   (true? x) (Standard/BOOLEAN_TRUE)
   (false? x) (Standard/BOOLEAN_FALSE)
   (symbol? x) (Constant. (name x) std-logic)
   :else x))

(defn attr
  ([exp attr]
     ;; hack to allow attributes of Types
     (let [exp (if (instance? Type exp)
                 (signal (get-id exp) nil)
                 exp)]
       (AttributeExpression. exp (Attribute. attr Standard/STRING))))
  ([exp attr param]
     (let [exp (if (instance? Type exp)
                 (signal (get-id exp) nil)
                 exp)]
       (AttributeExpression. exp (Attribute. attr Standard/STRING) (literal param)))))

(defn attr-dec [name type]
  (Attribute. name type))

(defn attr-spec [attr entities value]
  (let [name-list (cond
                   (= entities :all) AttributeSpecification$EntityNameList/ALL
                   (= entities :others) AttributeSpecification$EntityNameList/OTHERS
                   :else (AttributeSpecification$EntityNameList.
                          (mapv #(AttributeSpecification$EntityNameList$EntityDesignator. %) entities)))]
    (AttributeSpecification. (Attribute. attr Standard/STRING)
                             name-list
                             EntityClass/SIGNAL
                             (literal value))))

(defn attr-event [exp]
  (attr exp "event"))

(defn attr-pos [exp param]
  (attr exp "pos" param))

(defn attr-val [exp param]
  (attr exp "val" param))

(defn attr-loc [exp param]
  (attr exp "loc" param))

(defn gen-const
  ([name record]
     (gen-const name record {}))
  ([name record vals]
     (Constant. name record
                (let [agg (Aggregate.)]
                  (doseq [elem (.getElements record)
                          ident (.getIdentifiers elem)]
                    (.createAssociation
                     agg (or (get vals ident)
                             (zero-val (.getType elem)))
                     (into-array [(Signal. ident (.getType elem))]))) agg))))

(defn ranges [& r]
  (into-array DiscreteRange r))

(defprotocol ToSignal
  (create-signal [v type]))

(extend-protocol ToSignal
  Keyword
  (create-signal [k type]
    [k (Signal. (vhdl-name k) type)])
  String
  (create-signal [s type]
    [(keyword s) (Signal. (vhdl-name s) type)])
  Symbol
  (create-signal [s type]
    (let [key (or (:key (meta s)) (keyword (name s)))]
      [key (Signal. (vhdl-name (name s)) type)])))

(defrecord KeySig [key name]
  ToSignal
  (create-signal [r type]
    [key (Signal. name type)]))

(defn create-signals [& descs]
  (into {} (for [[type & sigs] descs
                 s (flatten sigs)]
             (create-signal s type))))

(defn record-type [name & elements]
  (let [record (RecordType. name)
        sigs (for [[type & keys] elements
                   k (flatten keys)]
               (create-signal k type))]
    (doseq [[_ sig] sigs]
      (.createElement record (.getType sig) (into-array [(get-id sig)])))
    record))

(defn slice-to [exp a b]
  (Slice. exp (range-to a b)))

(defn slice-downto [exp a b]
  (Slice. exp (range-downto a b)))

(defn v-equals [a b]
  (cond
   (and
    (instance? StringLiteral a)
    (instance? StringLiteral b))
   (= (.getString a) (.getString b))
   (and
    (instance? HexLiteral a)
    (instance? HexLiteral b))
   (= (str a) (str b))
   :else (= a b)))

(defn qual-exp [type op]
  (QualifiedExpression. type op))

(defn pos-agg [& exps]
  (let [agg (Aggregate.)]
    (doseq [exp exps]
      (.createAssociation agg exp))
    agg))

(defn named-agg [& exp-choice-pairs]
  (let [agg (Aggregate.)]
    (if (some nil? exp-choice-pairs)
      (throw (IllegalArgumentException. "no arg can be nil")))
    (if (zero? (count exp-choice-pairs))
      (throw (IllegalArgumentException. "aggregate cannot contin zero arg associations")))

    (doseq [[exp choice] (partition 2 2 [nil] exp-choice-pairs)]
      (.createAssociation agg
                          exp
                          (cond
                           (nil? choice) [Choices/OTHERS]
                           ;; Create a fake signal just to pass the
                           ;; name. Is there a better way?
                           (string? choice) [(Signal. choice std-logic)]
                           (vector? choice) (into-array choice)
                           :else (into-array [choice]))))
    agg))

(defn instantiate-component
  ([name comp-or-entity ports]
     (instantiate-component name comp-or-entity ports nil))
  ([name comp-or-entity ports generics]
     (-> (ComponentInstantiation. name
                                  (if (instance? Entity comp-or-entity)
                                                (Component. comp-or-entity)
                                                comp-or-entity))
         (add-all
          port-map (map #(apply assoc-elem %) ports))
         (add-all
          generic-map (map #(apply assoc-elem %) generics)))))

(defn instantiate-entity
  ([name entity ports]
     (instantiate-entity name entity ports nil))
  ([name entity ports generics]
     (-> (EntityInstantiation. name entity)
         (add-all
          port-map (map #(apply assoc-elem %) ports))
         (add-all
          generic-map (map #(apply assoc-elem %) generics)))))

(defn instantiate-arch
  ([name arch ports]
     (instantiate-arch name arch ports nil))
  ([name arch ports generics]
     (-> (ArchitectureInstantiation. name arch)
         (add-all
          port-map (map #(apply assoc-elem %) ports))
         (add-all
          generic-map (map #(apply assoc-elem %) generics)))))

(defn instantiate-config
  ([name config ports]
     (instantiate-config name config ports nil))
  ([name config ports generics]
     (-> (ConfigurationInstantiation. name config)
         (add-all
          port-map (map #(apply assoc-elem %) ports))
         (add-all
          generic-map (map #(apply assoc-elem %) generics)))))

(defn case-statement [input & cases]
  (when-not (zero? (mod (count cases) 2))
    (throw (IllegalArgumentException. "requires even number of cases")))
  (let [cs (CaseStatement. input)]
    (doseq [[c stmts] (partition 2 cases)]
      (let [alt (.createAlternative cs (apply choices (if (seq? c) c [c])))]
        (add-all alt statements stmts)))
    cs))

(defn return-stmt [x]
  (ReturnStatement. x))

(defn ^VhdlFile vhdl-file [] (VhdlFile.))

(defn ^LibraryClause lib-clause [& libs]
  (LibraryClause. (into-array libs)))
(defn ^UseClause use-clause [& libs]
  (UseClause. (into-array libs)))
(defn ^ConstantDeclaration constant-decl [& libs]
  (ConstantDeclaration. (into-array libs)))

(defn ^PackageBody pkg-body [decl]
  (PackageBody. decl))
(defn ^PackageDeclaration pkg-decl [name]
  (PackageDeclaration. name))

(defn ^Architecture architecture [name entity]
  (Architecture. name entity))

(defn ^Entity entity [name]
  (Entity. name))

(defn ^ProcessStatement process-stmt []
  (ProcessStatement.))

(defn ^Constant constant
  ([id type] (Constant. id type))
  ([id type val] (Constant. id type val)))

(defn ^EnumerationType enum-type [id & literals]
  (if (seq literals)
    (EnumerationType. id (into-array literals))
    (EnumerationType. id)))

#_(defn create-enum-type [id literal-fn literals]
  (let [enum (apply enum-type id (map literal-fn literals))]
    {:type enum
     :map
     (zipmap literals (.getLiterals enum))}))

#_(defn ^EntityInstantiation instantiate-entity [label entity]
  (EntityInstantiation. label entity))

#_(defn ^ComponentInstantiation instantiate-component [label comp]
  (ComponentInstantiation. label comp))

(defn ^Component component [entity-or-id]
  (Component. entity-or-id))

(defn ^Subtype sub-type [name type]
  (Subtype. name type))

(defn ^UnconstrainedArray unconstrained-array [id type index-types]
  (UnconstrainedArray. id type index-types))

(defn ^ConstrainedArray constrained-array [id type r]
  (ConstrainedArray. id type (apply ranges r)))

(defn ^RangeSubtypeIndication range-subtype-indication [base-type range]
  (RangeSubtypeIndication. base-type range))

(defn ^IndexSubtypeIndication index-subtype-indication [base-type range]
  (IndexSubtypeIndication. base-type range))

(defn ^ArrayElement array-elem [array index]
  (ArrayElement. array index))

(defn libify-entity
  "hack to add 'work.' to entity name so it appears in output"
  [^Entity entity lib]
  (Entity. (str lib "." (get-id entity))))

(defn libify-arch
  "hack to add 'work.' to entity name so it appears in output"
  [^Architecture arch lib]
  (Architecture. (get-id arch) (libify-entity (.getEntity arch) lib)))

(defn libify-config
  "hack to add 'work.' to entity name so it appears in output"
  [^Configuration config lib]
  (Configuration. (str lib "." (get-id config)) (.getEntity config) (.getBlockConfiguration config)))

(defn extract-expression-variables
  [^Expression e]
  (cond
   (instance? BinaryExpression e) (concat (extract-expression-variables (.getLeft e))
                                          (extract-expression-variables (.getRight e)))
   (instance? UnaryExpression e) (extract-expression-variables (.getExpression e))
   (instance? Constant e) [(get-id e)]
   :else nil))

(defn extract-range-variables
  "Returns a sequence of variable name strings contained in a vhdl range"
  [^Range r]
  (seq
   (into #{} (map s/lower-case (concat (extract-expression-variables (.getFrom r))
                                       (extract-expression-variables (.getTo r)))))))

(defn- simplify-binary-exp [^BinaryExpression bin]
  (let [left (.getLeft bin)
        right (.getRight bin)]
    (if (and (instance? DecimalLiteral left)
             (instance? DecimalLiteral right)
             (not (.contains (.getValue left) "."))
             (not (.contains (.getValue right) ".")))
      (let [left (Long/parseLong (.getValue left))
            right (Long/parseLong (.getValue right))
            op (cond
                (instance? Add bin) +
                (instance? Subtract bin) -
                (instance? Multiply bin) *)]
        (if op
          (DecimalLiteral. (int (op left right)))
          bin))
      bin)))

(defn- simplify-unary-exp [^UnaryExpression uni]
  (let [exp (.getExpression uni)]
    (if (and (instance? DecimalLiteral exp)
             (not (.contains (.getValue exp) ".")))
      (let [exp (Long/parseLong (.getValue exp))
            op (cond
                (instance? Minus uni) -
                (instance? Plus uni) +
                (instance? Abs uni) #(Math/abs %))]
        (if op
          (DecimalLiteral. (int (op exp)))
          uni))
      uni)))

(defn resolve-expression [e vals]
  (cond
   (instance? BinaryExpression e)
   (simplify-binary-exp
    (doto (.copy e)
      (.setLeft (resolve-expression (.getLeft e) vals))
      (.setRight (resolve-expression (.getRight e) vals))))
   (instance? UnaryExpression e)
   (simplify-unary-exp
    (doto (.copy e)
      (.setExpression (resolve-expression (.getExpression e) vals))))
   (instance? Parentheses e)
   (let [val (resolve-expression (.getExpression e) vals)]
     ;;(prn "PAREN val" val "E" e (.getExpression e) (.getLeft val) (.getRight val))
     (if (or (instance? UnaryExpression val)
             (instance? Literal val))
       val
       (doto (.copy e)
         (.setExpression val))))
   (instance? Constant e)
   (or
    (get vals (get-id e))
    (.getDefaultValue e)
    e)
   :else e))

(defn resolve-range
  [^Range r vals]
  (let [c (.copy r)]
    (doto c
      (.setFrom (resolve-expression (.getFrom c) vals))
      (.setTo (resolve-expression (.getTo c) vals)))))

(defn resolve-type [type vals]
  (cond
   (instance? IndexSubtypeIndication type)
   (IndexSubtypeIndication. (type-of type)
                            (java.util.ArrayList.
                             (mapv #(resolve-range % vals) (.getRanges type))))

   :else
   type))

(defn for-gen [^String label loop-var range]
  (let [loop-var (if (instance? NamedEntity loop-var)
                   (get-id loop-var)
                   loop-var)]
    (ForGenerateStatement. label loop-var range)))

(defn if-gen [^String label cond]
  (IfGenerateStatement. label cond))

(defn ^String vstr [e]
  (cond
   (nil? e) "(nil)"
   ;; support printing types by making a dummy signal and taking
   ;; substring of the output        
   (instance? SubtypeIndication e)
   (let [s (vstr (signal-decl "dummy" e))
         i (.indexOf s ":")]
     (if (= -1 i)
       (throw (Exception. (str "Cannot create string for vmagic type " e " " s)))
       (let [s (s/trim (.substring s (inc i)))]
         ;; remove trailing ;
         (if (= (.charAt s (dec (.length s))) \;)
           (.substring s 0 (dec (.length s)))
           s))))
   :else (VhdlOutput/toVhdlString e)))

(defn spit-vhdl [f content]
  (with-open [w (jio/writer f)]
    (VhdlOutput/toWriter content w)))

(defn agg-others [x]
  (Aggregate/OTHERS x))
