# a reference to the current file (where the __FILE__ is being written) name
# only file name, not including anypath
p __FILE__
# "example.rb"

# return the absoluate path of current file
p File.expand_path(__FILE__)
# "/Users/xullnn/Programming/launchschool/c-170/lessons/3_file_based_cms/CMS/example.rb"

# find the absoluate path of current file, then go 1 level(../) up
p File.expand_path('../', __FILE__)
# "/Users/xullnn/Programming/launchschool/c-170/lessons/3_file_based_cms/CMS"

# find the absoluate path of current file, then go 2 levels(../../) up
p File.expand_path('../../', __FILE__)
# "/Users/xullnn/Programming/launchschool/c-170/lessons/3_file_based_cms"

# find the absoluate path of current file, then go 2 levels(../../) up
# then go down into /data/ directory
p File.expand_path('../../data/', __FILE__)
# "/Users/xullnn/Programming/launchschool/c-170/lessons/3_file_based_cms/data"

# Relative paths are referenced from the current working directory of the process
# unless dir_string is given, in which case it will be used as the starting point.

# File.expand_path will first take the second arg(if there's one) as the starting point
# if second arg is not given, the operation will based on current working directory
  # for example now I am in example.rb file, its working directory is full_path/CMS/
  # if I do:

p File.expand_path('sample.txt')

# "/Users/xullnn/Programming/launchschool/c-170/lessons/3_file_based_cms/CMS/sample.txt"

# this part is the working directory, means where the file containing this code is in
# /Users/xullnn/Programming/launchschool/c-170/lessons/3_file_based_cms/CMS/
