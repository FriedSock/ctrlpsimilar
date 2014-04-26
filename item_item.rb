require File.join(File.dirname(__FILE__), 'commit_matrix.rb')

TEMP_FILENAME = '/tmp/commit_files'

def main
  output = []
  `#{File.join(File.dirname(__FILE__), "get_commit_files.sh" )} > #{TEMP_FILENAME}`

  raw = File.open(TEMP_FILENAME).read
  `rm #{TEMP_FILENAME}`

  commit_matrix = CommitMatrix.new

  commits = raw.split('----SEPERATOR----')
  commits.each do |c|
    files = c.match(/files: (.*)/m)
    revision = c.match(/revision: (.*)/)
    parents = `git rev-list --parents -n 1 #{revision[1]}`.split
    filenames = files[1].split("\n")
    puts revision
    if parents.length > 2
      #puts `git diff --name-status #{parents[2]} #{parents[1]}`
      #puts files
      #puts ''
      filenames.each { |f| commit_matrix.handle_merge_file f }
    else
      filenames.each { |f| commit_matrix.handle_file f }
    end
    commit_matrix.next_commit
  end


  filenames = commit_matrix.filenames_to_columns.keys
  filenames.each do |filename1|
    out = []
    filenames.each do |filename2|
      v1 = commit_matrix.file_vector filename1
      v2 = commit_matrix.file_vector filename2
      cos = v1.inner_product(v2) / (v1.r * v2.r)
      out += [[filename1, filename2, cos]]
    end
    out.sort! { |x,y| y[2] <=> x[2]}
    out.each do |o|
      output << o.join(' ')
    end
    output << ""
  end
  output.join "\n"

end

if __FILE__ == $0
  puts main
end

