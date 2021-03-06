require 'fileutils'
require 'audit'
require 'open3'

module UploadsHelper
  class Postprocessor
    private
    PROCS = {}
    public
    def self.create_handler(name)
      name = name.to_s
      # from http://blog.gsamokovarov.com/ruby-tips-tricks-1, this works despite the warning
      PROCS[name] = lambda
    end
    def self.alias_handler(new_name, old_name)
      new_name = new_name.to_s
      old_name = old_name.to_s
      PROCS[new_name] = PROCS[old_name]
    end

    def self.process(f)
      ext = File.extname(f)[1..-1]
      PROCS[ext]&.call(f)
    end

    create_handler :rkt do |f|
      output, err, status = Open3.capture3("xvfb-run", "-a", "--server-num", "1",
                                           "racket", Rails.root.join("lib/assets/render-racket.rkt").to_s,
                                           "-o", f + "ext",
                                           f)
      if status.success? || File.exists?(f + "ext")
        FileUtils.mv f + "ext", f
        Audit.log "Successfully processed #{f}"
        return true
      else
        FileUtils.rm f + "ext", force: true
        Audit.log <<ERROR
================================
Problem processing #{f}:
Status: #{status}
Error: #{err}
Output: #{output}
================================
ERROR
        return false
      end
    end
    alias_handler :ss, :rkt
  end
end
