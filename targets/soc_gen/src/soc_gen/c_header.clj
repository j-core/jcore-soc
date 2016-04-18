(ns soc-gen.c-header
  "Generates C header files from hardware description"
  (:require
   [clojure.string :as s]
   [soc-gen.plugins]))

(defn- device-struct-name [dev-name]
  (str (s/lower-case dev-name) "_regs"))

(defn- device-base [dev-name]
  (str "DEVICE_" (s/upper-case dev-name) "_ADDR"))

(defn- class-reg-struct [dev-name dev-class]
  (let [
        regs
        (->> (concat [nil] (:regs dev-class) [nil])
             (partition 3 1)
             (map (fn [[before reg after]]
                    ;; expand registers that are less than 4-bytes to
                    ;; an aligned 4 byte word if possible
                    (let [[left right] (:byte-range reg)
                          left-boundary (or (second (:byte-range before))
                                            -1)
                          right-boundary (or (first (:byte-range after))
                                             0xffffffff)

                          left-space (mod left 4)
                          right-space (- 3 (mod right 4))
                          orig-reg reg
                          reg
                          (if (and (< (:width reg) 4) (> left-space 0)
                                   (<= left-space (dec (- left left-boundary))))
                            (assoc reg
                                   :byte-range [(- left left-space) right]
                                   :addr (- left left-space)
                                   :width (+ (:width reg) left-space)
                                   :expanded-from orig-reg)
                            reg)
                          reg
                          (if (and (< (:width reg) 4) (> right-space 0)
                                   (<= right-space (dec (- right-boundary right))))
                            (assoc reg
                                   :byte-range [left (+ right right-space)]
                                   :width (+ (:width reg) right-space)
                                   :expanded-from orig-reg)
                            reg)]
                      reg))))


        make-ignore
        (fn [a b]
          (when (<= a b)
            {:byte-range [a b]
             :type :ignore
             :width (inc (- b a))
             :addr a}))
        ;; insert ignore address ranges in the gaps between registers
        ;; so that struct field offsets will match reg addresses
        ignores
        (->> regs
             (partition 2 1)
             (map (fn [[a b]]
                    (make-ignore (inc (second (:byte-range a)))
                                 (dec (first (:byte-range b))))))
             (filter identity))
        regs (sort-by :addr
                      (filter identity
                              (concat [(make-ignore 0 (dec (:addr (first regs))))] regs ignores)))
        ;; assign names to ignore fields
        regs
        (->> regs
             (reductions
              (fn [[i _] reg]
                (if (= :ignore (:type reg))
                  [(inc i) (assoc reg :name (str "ignore" i))]
                  [i reg]))
              [0 nil])
             (filter second)
             (mapv second))]

    (if (every?
         (fn [reg]
           ;; check that all registers are aligned
           (let [[a b] (:byte-range reg)]
             (and (= (mod a 4) 0)
                  (= (mod b 4) 3))))
         regs)
      (str
       "struct " (device-struct-name dev-name) " {\n"
       (s/join
        (interleave
         (repeat "  ")
         (map
          (fn [r]
            (str "uint32_t "
                 (:name r)
                 (let [array-len (quot (:width r) 4)]
                   (when (> array-len 1)
                     (str "[" array-len "]")))))
          regs)
         (repeat ";")
         (map
          (fn [r]
            (let [comment
                  (str
                   (when (= :read (:mode r)) " read-only")
                   (when-let [from (:expanded-from r)]
                     (let [[ol or] (:byte-range from)
                           start (first (:byte-range r))
                           ol (- ol start)
                           or (- or start)]
                       (if (= ol or)
                         (str " only byte " ol)
                         (str " only bytes " ol "-" or)))))]
              (when-not (s/blank? comment)
                (str " //" comment))))
          regs)
         (repeat "\n")))
       "};"))))

(defn gen-bootloader-header [devices device-classes]
  (let [data-bus-devices
        (->> (vals devices)
             (filter :base-addr)
             (sort-by #(s/upper-case (:name %))))
        reg-device-classes
        (->> device-classes
             (filter (comp seq :regs val))
             (sort-by key))]
    (str
     "#ifndef BOARD_H\n"
     "#define BOARD_H\n"
     "#include <inttypes.h>\n"

     ;; TODO: Should dram address come from edn? It's hardcoded in the
     ;; cpu_core decoder as well.
     "\n#define DRAM_BASE 0x10000000\n"

     "\n// Memory mapped peripherals\n"
     (let [max-name-len (apply max (map #(.length (:name %)) data-bus-devices))]
       (s/join
        (for [dev (sort-by #(s/upper-case (:name %)) data-bus-devices)]
          (str "#define " (device-base (:name dev)) " "
               (s/join (repeat (- max-name-len (.length (:name dev))) " "))
               (format "0x%08x" (:base-addr dev)) "\n"))))
     "\n"
     (s/join
      (map
       (fn [[cls-name cls]]
         (let [struct (class-reg-struct cls-name cls)]
           (if struct
             (str struct "\n"
                  (s/join
                   (map
                    (fn [dev]
                      (str "#define DEVICE_"(s/upper-case (:name dev))
                           " ((volatile struct " (device-struct-name cls-name)
                           " *) " (device-base (:name dev)) ")\n"))
                    (filter
                     #(= (:class %) cls-name)
                     data-bus-devices)))
                  "\n")
             (str "// " cls-name " contains unaligned registers\n\n"))))
       reg-device-classes))

     "\n#endif\n")))

(deftype CHeaderPlugin []
    soc-gen.plugins/SocGenPlugin
    (on-pregen [plugin design]
      [plugin design])
    (file-list [plugin]
      [{:id ::boardh
        :name "board.h"}])
    (on-generate [plugin design file-id file-desc]
      file-desc)
    (file-contents [plugin design file-id file-desc]
      (when (= file-id ::boardh)
        (str
         "// This file is generated by soc_gen and will be overwritten next time\n"
         "// the tool is run. See soc_top/README for information on running soc_gen.\n\n"
         (gen-bootloader-header
          (:devices design) (:device-classes design))))))
