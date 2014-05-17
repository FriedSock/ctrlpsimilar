
LOG_PATH = '~/.vim/bundle/ctrlp-similar/.logfile'

def log_action str
  sim_files = Vim::evaluate('s:ctrlp_similar_files')
  index = sim_files.index { |item| item.split.first.chomp == str.chomp }
  similarity = sim_files[index].split.last
  size = sim_files.size
  puts `echo '{ "filename":"#{str}", "index": #{index}, "size": #{size}, "similarity": #{similarity}, "time":"#{Time.new}"},' >> #{LOG_PATH}`
end
