(ns soc-gen.plugins)

(defprotocol SocGenPlugin
  #_(on-design [plugin design]
    "Called at the end of soc-gen.core/create-design after plugins are
  instantiated. Returns [new-plugin new-design]")
  (on-pregen [plugin design]
    "Called after soc-gen.generate/preprocess-design is
    called. Returns [new-plugin new-design]")

  (file-list [plugin]
    "Returns list of file descriptions. Each will be the initial
    gen-opts of a file to be generated. The on-generate function of
    all plugins will be called with the gen-opts before finally
    file-contents of this plugin is called.")
  (on-generate [plugin design file-id file-desc]
    "Called when each output file is being
    generated. Returns new-file-desc. The content of file-desc
    depends on the file-id.")

  (file-contents [plugin design file-id file-desc]
    "Returns the file contents."))
