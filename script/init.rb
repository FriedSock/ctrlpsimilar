require File.join(File.dirname(__FILE__), 'array.rb')
require File.join(File.dirname(__FILE__), 'item_item.rb')
require File.join(File.dirname(__FILE__), 'predictor.rb')

SIMILARITY_TYPE = :time_cosine

def modded_files
  `cd "$(git rev-parse --show-toplevel)"; git ls-files --full-name -m`.split("\n")
end

def gen_similar_files
  hash = `git rev-parse HEAD`.chomp[0..9]
  commit_matrix = retrieve_matrix hash

  files = []
  predictor = Predictor.new(observation, commit_matrix, SIMILARITY_TYPE)
  full_names = `git ls-files --full-name`.split("\n")
  short_names = `git ls-files`.split("\n")
  full_names_to_short_names = Hash[full_names.zip short_names]

  files = predictor.predict.to_a
  files += modded_files.map { |f| [f,1]}
  files.reject! { |file,v| !full_names.include?(file) }
  files.map! { |file,v| [full_names_to_short_names[file], v]}
  files.sort! {|f1,f2| f2[1] <=> f1[1] }.map! {|f| f.map(&:to_s).join("\t")}

  VIM::command("let s:ctrlp_similar_files = #{files.map { |f| stringify f} }")
end

def observation
  hash = {}
  modded_files.each do |m|
    hash[m] = 1
  end
  hash[focussed_file] = 1
  hash
end

def focussed_file
  file = Vim::evaluate("s:focussed_file")
  if file != ''
    full_file = Vim::evaluate("s:full_name")
    root_repo = `git rev-parse --show-toplevel`.chomp + '/'
    full_file.slice! root_repo
    return full_file
  end
end

def stringify string
  "'#{string}'"
end
