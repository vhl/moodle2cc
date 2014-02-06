class Moodle2CC::CommonCartridge::CartridgeCreator

  IMS_MANIFEST = 'imsmanifest.xml'

  def initialize(course)
    @course = course
  end

  def create(out_dir)
    out_file = File.join(out_dir, filename)
    Dir.mktmpdir do |dir|
      tmp_file = File.join(dir, filename)
      xml = Moodle2CC::CommonCartridge::ImsManifestGenerator.new(@course).generate
      File.open(File.join(dir, 'imsmanifest.xml'), 'w'){|f| f.write(xml)}
      Zip::File.open(tmp_file, Zip::File::CREATE) do |zipfile|
        Dir["#{dir}/**/*"].each do |file|
          zipfile.add(file.sub(dir + '/', ''), file)
        end
      end
      FileUtils.mv(tmp_file, out_file)
    end
    out_file
  end

  def filename
    title = @course.title.gsub(/::/, '/').
      gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
      gsub(/([a-z\d])([A-Z])/, '\1_\2').
      tr("- ", "_").downcase
    "#{title}.imscc"
  end

end