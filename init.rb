require File.join(File.dirname(__FILE__), 'array.rb')

def gen_sample_files
  files = ['file1', 'file2', 'file3'].map { |s| stringify s }
  VIM::command("let s:ctrlp_similar_files = #{files}")
end

def stringify string
  "'#{string}'"
end
