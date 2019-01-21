version control feature for files
  - create
  - update
  - delete

what is used as unique identifier for every version?
  - timestamp

How to add(update) new version?
  - read from current file
  - encapsulate all versions into an object
  - CMSFile.new(filename, type, versions)
    - versions: { '2003-12-12 09:20:30' => "content abc", '2004-11-12 19:20:45' => "content xyz" ... }
  - add new params into this object
  - then write back into the file

so, separate actual file and file displaying

- get request for reading a file
  - extract info from actual file
  - create CMSFile object
  - render another erb template

- get for edit page
  - get current version, render edit page
- post for update file
  - write into file(append mode)
  - redirect reading page

- delete file/version
  - delete version
    - submit timestamp
    - create CMSFile object, inject file, delete given version
    - redirect to reading page

  - delete file
    - find file by name, delete


- format of a file

```
---
2003-12-12 09:20:30

This Code of Conduct helps us build a community that is rooted in kindness, collaboration, and mutual respect.

Whether you’ve come to ask questions or to generously share what you know, join us in building a community where all people feel welcome and can participate, regardless of expertise or identity.

---
2004-12-12 09:20:31

Whether you’ve come to ask questions or to generously share what you know, join us in building a community where all people feel welcome and can participate, regardless of expertise or identity.

---
```

- interfaces
  - create new file: CMSFile.new.create(name, type, content)
  - read existing file: CMSFile.new.read()
  - update file: cms.update(new_content)
  - delete version: cms.delete_version(timestamp)

```ruby
class CMSFile
  attr_accessor :contents

  def initialize
    @contents = {}
  end

  def create(content)
    timestamp = format_time(Time.new)
    @contents[timestamp] = content
    self
  end

  def read(string)
    content = string.split("---").map(&:strip)
    content.delete("")
    @contents = content.map do |paragraph|
      parts = paragraph.partition(/\d{4}-.+\:\d{2}\b/)
      parts.delete("")
      parts
    end.to_h
    self
  end

  def render_str(type=:plain)
    plain_text = @contents.map do |timestamp, content|
      "---\n#{timestamp}\n\n#{content}\n"
    end.join("\n")
    case type
    when :plain
      plain_text
    when :html
      plain_text.gsub!("\n", "</br>")
    end
  end

  def self.format_time(time)
    time.strftime("%F %H:%M:%S")
  end

  def self.format_input(content)
    timestamp = format_time(Time.new)
    "---\n#{timestamp}\n#{content}\n"
  end
end
```
