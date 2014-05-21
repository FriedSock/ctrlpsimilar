LOG_PATH = $dir + '/../.logfile' unless defined? LOG_PATH

def untracked_files
  `git ls-files --others --exclude-standard | grep -v '.ctrlp-similar'`.split("\n")
end

def log_action str
  filename = str.chomp
  sim_files = Vim::evaluate('s:ctrlp_similar_files')
  index = sim_files.index { |item| item.split.first.chomp == str.chomp }
  similarity = sim_files[index].split.last
  size = sim_files.size
  untracked  = untracked_files.include? str
  `echo '"filename":"#{str}", "index": #{index}, "size": #{size}, "similarity": #{similarity}, "time":"#{Time.new}", "untracked":#{untracked}' >> #{LOG_PATH}`
end
