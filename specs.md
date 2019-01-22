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
------
2003-12-12 09:20:30

This Code of Conduct helps us build a community that is rooted in kindness, collaboration, and mutual respect.

Whether you’ve come to ask questions or to generously share what you know, join us in building a community where all people feel welcome and can participate, regardless of expertise or identity.

------
2004-12-12 09:20:31

Whether you’ve come to ask questions or to generously share what you know, join us in building a community where all people feel welcome and can participate, regardless of expertise or identity.

------
```
