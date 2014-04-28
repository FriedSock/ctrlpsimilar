require File.join(File.dirname(__FILE__), 'commit_matrix.rb')

TEMP_FILENAME = '/tmp/commit_files'

def main
  output = []
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

def build_matrix commit_hash, level
  parents = `git rev-list --parents -n 1 #{commit_hash}`.split
  puts "level: #{level}   parents: #{parents[1..-1]}"
  if parents.size == 3
    build_matrix parents[1], "#{level} left" if !$Commit_matrices.has_key? parents[1]
    build_matrix parents[2], "#{level} right" if !$Commit_matrices.has_key? parents[2]
    debugger if commit_hash == '626cb86720702582f6c0cee3b226d2496518e5b3'
    make_merge_matrix commit_hash, parents[1..2]
  elsif parents.size == 2
    build_matrix parents[1], level if !$Commit_matrices.has_key? parents[1]
    make_hard_matrix commit_hash, $Commit_matrices[parents[1]] if !$Commit_matrices.has_key? commit_hash
  else
    make_hard_matrix commit_hash, nil
  end
end

def make_merge_matrix commit_hash, parents
  return if $Commit_matrices.has_key? commit_hash

  parent1 = $Commit_matrices[parents.first]
  parent2 = $Commit_matrices[parents.last]
  diff = `git diff -M --name-status #{parents.first} #{commit_hash}`
  $Commit_matrices[commit_hash] = CommitMatrix.merge parent1, parent2, diff, commit_hash
  puts "size #{commit_hash}"
end

def make_hard_matrix commit_hash, parent
  return if $Commit_matrices.has_key? commit_hash

  commit_matrix = CommitMatrix.new commit_hash, parent
  name_statuses = `git diff-tree --no-commit-id -r -M -c --name-status --root #{commit_hash}`
  name_statuses.split("\n").each do |name_status|
    commit_matrix.handle_file name_status
  end
  commit_matrix.next_commit
  $Commit_matrices[commit_hash] = commit_matrix
  puts "size: #{$Commit_matrices.keys.size}"
  if $Commit_matrices.size == 60
    (1..20).each do
      $Commit_matrices.delete $Commit_matrices.keys.first
    end
  end
end

if __FILE__ == $0
  $Commit_matrices = {}
  commit = `git rev-parse HEAD`
  puts build_matrix commit, ''
end

