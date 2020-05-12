(ns soc-gen.iobufs
  (:require
   [clojure.string :as s]
   [soc-gen
    [vmagic :as v]]))

(defn- result [internal-signals statements]
  {:internal-signals internal-signals
   :statements statements})

(defn- gen-attrs [attrs]
  (let [attrs (select-keys attrs [:iostandard :drive :diff_term :slew])]
    (for [[k v] (sort attrs)
          :when (not (or (nil? k) (nil? v)))]
      [(s/upper-case (name k)) (v/literal v)])))

(defprotocol IOBufs
  (create-ibuf-differential [iob internal-signals neg-pin pos-pin])
  (create-obuf-differential [iob internal-signals neg-pin pos-pin])
  (create-iobuf [iob internal-signals pin])
  (create-obuft [iob internal-signals pin])
  (create-obuf [iob internal-signals pin])
  (create-ibuf [iob internal-signals pin]))

(def ^{:private true} fpga-fns
  {:create-ibuf-differential
   (fn [iob internal-signals neg-pin pos-pin]
     (result
      internal-signals
      [(v/instantiate-component
        (str "ibufds_" (:net pos-pin) "_" (:net neg-pin))
        (v/component "IBUFDS")
        [["I" (:sig pos-pin)]
         ["IB" (:sig neg-pin)]
         ["O" (get-in pos-pin [:in :name :exp])]]
        (gen-attrs (:attrs pos-pin)))]))

   :create-obuf-differential
   (fn [iob internal-signals neg-pin pos-pin]
     (result
      internal-signals
      [(v/instantiate-component
        (str "obufds_" (:net pos-pin) "_" (:net neg-pin))
        (v/component "OBUFDS")
        [["I" (get-in pos-pin [:out :name :exp])]
         ["O" (:sig pos-pin)]
         ["OB" (:sig neg-pin)]]
        (gen-attrs (:attrs pos-pin)))]))

   :create-iobuf
   (fn [iob internal-signals pin]
     (result
      internal-signals
      [(v/instantiate-component
        (str "iobuf_" (:net pin))
        (v/component "IOBUF")
        [["I" (get-in pin [:out :name :exp])]
         ["T" (get-in pin [:out-en :name :exp])]
         ["O" (get-in pin [:in :name :exp])]
         ["IO" (:sig pin)]]
        (gen-attrs (:attrs pin)))]))

   :create-obuft
   (fn [iob internal-signals pin]
     (result
      internal-signals
      [(v/instantiate-component
        (str "obuft_" (:net pin))
        (v/component "OBUFT")
        [["I" (get-in pin [:out :name :exp])]
         ["T" (get-in pin [:out-en :name :exp])]
         ["O" (:sig pin)]]
        (gen-attrs (:attrs pin)))]))

   :create-obuf
   (fn [iob internal-signals pin]
     (result
      internal-signals
      [(v/instantiate-component
        (str "obuf_" (:net pin))
        (v/component "OBUF")
        [["I" (get-in pin [:out :name :exp])]
         ["O" (:sig pin)]]
        (gen-attrs (:attrs pin)))]))

   :create-ibuf
   (fn [iob internal-signals pin]
     (result
      internal-signals
      [(v/instantiate-component
        (str "ibuf_" (:net pin))
        (v/component "IBUF")
        [["I" (:sig pin)]
         ["O" (get-in pin [:in :name :exp])]]
        (gen-attrs (dissoc (:attrs pin) :drive :slew)))]))})

(defrecord Spartan6IOBufs [])
(extend Spartan6IOBufs
  IOBufs fpga-fns)
(defrecord Kintex7IOBufs [])
(extend Kintex7IOBufs
  IOBufs fpga-fns)

(defn- tsmc-io-cell
  "Return name of TSCM IO cell. Various options are encoded in the name."
  [& {:keys [drive pull schmitt-trigger slew-rate] :or {}}]
  (let [[drive-name drive-input]
        (case drive
          2 ["0204" 0]
          4 ["0204" 1]
          8 ["0408" 1]
          12 ["0812" 1]
          16 ["1216" 1])
        [pull-name pull-input]
        (case pull
          :up ["U" 1]
          :down ["D" 1]
          nil ["U" 0])]
    {:name
     (apply
      str
      "P"
      (filter
       identity
       [(if slew-rate "R" "D")
        pull-name
        "W"
        drive-name
        (when schmitt-trigger "S")
        "CDG"]))
     :inputs {"DS" drive-input
              "PE" pull-input}}))

(defn- tsmc-attrs [iob attrs]
  (merge
   {:drive 12}
   attrs))

(defn- tsmc-cell-ports [ports]
  (for [[n v] ports]
    [n (case v
         0 v/std-logic-0
         1 v/std-logic-1
         v)]))

(defrecord TsmcIOBufs []
  IOBufs
  (create-iobuf [iob internal-signals pin]
    (result
     internal-signals
     [(let [cell (apply tsmc-io-cell (flatten (seq (tsmc-attrs iob (:attrs pin)))))]
        (v/instantiate-component
         (str "iobuf_" (:net pin))
         (v/component (:name cell))
         (tsmc-cell-ports
          (into
           [["IE" 1]
            ["C" (get-in pin [:in :name :exp])]
            ["I" (get-in pin [:out :name :exp])]
            ["OEN" (v/v-not (get-in pin [:out-en :name :exp]))]
            ["PAD" (:sig pin)]]
           (:inputs cell)))))]))

  (create-obuft [iob internal-signals pin]
    (result
     internal-signals
     [(let [cell (apply tsmc-io-cell (flatten (seq (tsmc-attrs iob (:attrs pin)))))]
        (v/instantiate-component
         (str "obuft_" (:net pin))
         (v/component (:name cell))
         (tsmc-cell-ports
          (into
           [["IE" 0]
            ["C" nil]
            ["I" (get-in pin [:out :name :exp])]
            ["OEN" (v/v-not (get-in pin [:out-en :name :exp]))]
            ["PAD" (:sig pin)]]
           (:inputs cell)))))]))

  (create-obuf [iob internal-signals pin]
    (result
     internal-signals
     [(let [cell (apply tsmc-io-cell (flatten (seq (tsmc-attrs iob (:attrs pin)))))]
        (v/instantiate-component
         (str "obuf_" (:net pin))
         (v/component (:name cell))
         (tsmc-cell-ports
          (into
           [["IE" 0]
            ["C" nil]
            ["I" (get-in pin [:out :name :exp])]
            ["OEN" 0]
            ["PAD" (:sig pin)]]
           (:inputs cell)))))]))

  (create-ibuf [iob internal-signals pin]
    (result
     internal-signals
     [(let [cell (apply tsmc-io-cell (flatten (seq (tsmc-attrs iob (:attrs pin)))))]
        (v/instantiate-component
         (str "ibuf_" (:net pin))
         (v/component (:name cell))
         (tsmc-cell-ports
          (into
           [["IE" 1]
            ["C" (get-in pin [:in :name :exp])]
            ["I" 0]
            ["OEN" 1]
            ["PAD" (:sig pin)]]
           (:inputs cell)))))])))

(defn iobufs-factory [type]
  (case type
    :spartan6 (->Spartan6IOBufs)
    :kintex7 (->Kintex7IOBufs)
    :tsmc (->TsmcIOBufs)))
