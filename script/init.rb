require File.join(File.dirname(__FILE__), 'array.rb')
require File.join(File.dirname(__FILE__), 'item_item.rb')

def gen_similar_files
  files = files_from_item_item filename
  files = `git ls-files`.split("\n").map{ |file| [file, rand]}
  files = files.sort {|f1,f2| f2[1] <=> f1[1] }.map {|f| f.map(&:to_s).join(' ')}
  VIM::command("let s:ctrlp_similar_files = #{files.map { |f| stringify f} }")
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
