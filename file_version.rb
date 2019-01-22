class CMSFile
  attr_reader :timestamp
  attr_accessor :contents

  def initialize
    @contents = {}
  end

  def create(content)
    timestamp = CMSFile.format_time(Time.new)
    @contents[timestamp] = content
    self
  end

  def self.initialize_empty_file(file_path)
    File.open(file_path, 'w+') { |f| f.write(CMSFile.format_input('empty file'))}
    File.read(file_path)
  end

  def read(string, file_path)
    regexp_for_version = /\d{4}-.+\:\d{2}\b/
    if string.strip == ''
      CMSFile.initialize_empty_file(file_path)
    elsif !string.match(regexp_for_version) || !string.match(/------\n/)
      string = CMSFile.initialize_version!(string, file_path)
    end
    content = string.split("------").map(&:strip)
    content.delete("")
    @contents = content.map do |paragraph|
      parts = paragraph.partition(regexp_for_version)
      parts.delete("")
      parts
    end.sort.to_h
    self
  end

  def self.initialize_version!(string, path)
    new_str = format_input(string.strip)
    File.open(path, 'w') { |f| f.write(new_str) }
    File.read(path)
  end

  def self.format_time(time)
    time.strftime("%F %H:%M:%S")
  end

  def self.format_input(content)
    timestamp = format_time(Time.new)

    "------\n#{timestamp}\n\n#{content}\n"
  end

  def latest_content_pair
    @contents.to_a.last || []
  end
end
