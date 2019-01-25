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


---


### Directory based version control

You have a robust versioning system based on the date the file was created. Another possible versioning scheme would be to use numbers. i.e history.txt/1. That way you could simply use the directory structure in the data directory to keep track of the versions. e.g

```
- data
    - history.txt
         - 1
         - 2
```

- the real file path
  - /data/history.txt/1/history.txt
  - /data/history.txt/2/history.txt
  - /data/history.txt/3/history.txt

- the path shown in url: /history.txt/1

- create
  - validate user
  - render new erb(add content input form)
  - give file_name
    - check duplication
  - create nested dir and file
    - write in plain txt

- read
  - get version = params[:file_version]
  - check if version exists and find it
  - read string
  - set content-type to plain, render a template

- edit
  - validate user
  - get version = params[:file_name]
  - check if file exists and find it
  - load the latest version
  - render edit form

  - if the submitted content is the same as the last version
    - flash user, make no additional file

- delete
  - validate user
  - delete the whole directory
    - path: /history.txt/delete
    - locate dir under /data, delete
  - delete specific version
    - path: /history.txt/1/delete
    - locate dir at /data/history/1, delete
  - delete old versions
    - path: history.txt/delete_olds
    - find the biggest version number
    - delete all versions except for the latest one

  - duplicate
    - duplicate the whole nested dir
    - `mkdir B && touch B/myfile.txt`
    - /data/history.txt/1/history.txt
      - two parts of the dirctory need to change
      - /data/history_dup.txt/1/history_dup.txt
