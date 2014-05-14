require File.join(File.dirname(__FILE__), 'array.rb')
require File.join(File.dirname(__FILE__), 'item_item.rb')
require File.join(File.dirname(__FILE__), 'predictor.rb')

#def gen_similar_files
#  files = files_from_item_item filename
#  files = `git ls-files`.split("\n").map{ |file| [file, rand]}
#  files = files.sort {|f1,f2| f2[1] <=> f1[1] }.map {|f| f.map(&:to_s).join(' ')}
#  VIM::command("let s:ctrlp_similar_files = #{files.map { |f| stringify f} }")
#end
SIMILARITY_TYPE = :time_cosine

def gen_similar_files
  hash = `git rev-parse HEAD`.chomp
  commit_matrix = retrieve_matrix hash
  files = []
  puts 'p00'
  predictor = Predictor.new(observation, commit_matrix, SIMILARITY_TYPE)
  puts 'w00'
  all_files = `git ls-files --full-name`.split("\n")

  files = predictor.predict.to_a
  files = files.sort {|f1,f2| f2[1] <=> f1[1] }.map {|f| f.map(&:to_s).join(' ')}
  VIM::command("let s:ctrlp_similar_files = #{files.map { |f| stringify f} }")
end

def observation
  #all_files = `git ls-files --full-name`.split("\n")
  #hash = {}.tap do |h|
  #  all_files.each do |filename|
  #    h[filename] = 0
  #  end
  #end
  hash = {}
  modded_files = `git ls-files --full-name -m`.split("\n")
  modded_files.each do |m|
    hash[m] = 1
  end
  hash
end


def filename
  VIM::evaluate('s:buffer')
end

def files_from_item_item filename
  files = []
  raw = main
  lines = raw.split("\n")
  lines.each do |line|
    words = line.split
    if words.first == filename
      similarity = words.last.to_f
      files << [words[1], similarity]
    end
  end
  files.sort { |x,y| y.last <=> x.last}.map { |f| f.join ' ' }
end

def stringify string
  "'#{string}'"
end
