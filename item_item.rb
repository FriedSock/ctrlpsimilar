require 'matrix.rb'
#require 'ruby-debug'

TEMP_FILENAME = '/tmp/commit_files'

def handle_type array
  return array.split.last
end

def main
  output = []
  `#{File.join(File.dirname(__FILE__), "get_commit_files.sh" )} > #{TEMP_FILENAME}`

  raw = File.open(TEMP_FILENAME).read
  `rm #{TEMP_FILENAME}`

  commits = raw.split('----SEPERATOR----')
  filehash = {}
  commits.each do |c|
    files = c.match(/files: (.*)/m)
    next unless files
    filenames = files[1].split("\n")
    filenames.map!{ |f| handle_type f }
    filenames.each do |filename|
      unless filehash.keys.include? filename
        filehash[filename] = { :id => filehash.length, :vector => [] }
      end
    end
  end


  commits.each do |c|
    files = c.match(/files: (.*)/m)
    next unless files
    filenames = files[1].split("\n")

    #TODO - rename detection
    filenames.map! { |f| handle_type f }

    vector = ('0'*(filehash.keys.length)).split('').map(&:to_i)
    filenames.each do |filename|
      vector[filehash[filename][:id]] = 1
    end
    filehash.each do |k,v|
      v[:vector] += [vector[v[:id]]]
    end
  end

  filehash.each do |k, v|
    v[:vector] = Vector.[] *v[:vector]
    output << v[:vector]
  end

  filehash.each do |key, value|
    out = []
    filehash.each do |k, v|
      name1 = key
      name2 = k
      v1 = value[:vector]
      v2 = v[:vector]
      cos = v1.inner_product(v2) / (v1.r * v2.r)
      out += [[name1, name2, cos]]
    end
    out.sort! { |x,y| y[2] <=> x[2]}
    out.each do |o|
      output << o.join(' ')
    end
    output << ""
  end

  #filehash.each do |k,v|
  #  puts  "file: k"
  #  puts "v"
  #end

  #`rm graph_file.html`
  #File.open('graph_file.html', 'w+') { |f| f.write html_file(filehash, links)}
  output.join "\n"

end

if __FILE__ == $0
  puts main
end

