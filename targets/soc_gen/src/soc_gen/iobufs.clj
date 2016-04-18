(ns soc-gen.iobufs
  (:require
   [clojure.string :as s]
   [soc-gen
    [vmagic :as v]]))

(defn- result [internal-signals statements]
  {:internal-signals internal-signals
   :statements statements})

(defn- gen-attrs [pin]
  (let [attrs (select-keys (:attrs pin) [:iostandard :drive :diff_term :slew])]
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
        (gen-attrs pos-pin))]))

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
        (gen-attrs pos-pin))]))

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
        (gen-attrs pin))]))

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
        (gen-attrs pin))]))

   :create-obuf
   (fn [iob internal-signals pin]
     (result
      internal-signals
      [(v/instantiate-component
        (str "obuf_" (:net pin))
        (v/component "OBUF")
        [["I" (get-in pin [:out :name :exp])]
         ["O" (:sig pin)]]
        (gen-attrs pin))]))

   :create-ibuf
   (fn [iob internal-signals pin]
     (result
      internal-signals
      [(v/instantiate-component
        (str "ibuf_" (:net pin))
        (v/component "IBUF")
        [["I" (:sig pin)]
         ["O" (get-in pin [:in :name :exp])]]
        (gen-attrs pin))]))})

(defrecord Spartan6IOBufs [])
(extend Spartan6IOBufs
  IOBufs fpga-fns)
(defrecord Kintex7IOBufs [])
(extend Kintex7IOBufs
  IOBufs fpga-fns)

(defn iobufs-factory [type]
  (case type
    :spartan6 (->Spartan6IOBufs)
    :kintex7 (->Kintex7IOBufs)))
