require 'pathname.rb'
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

def build_matrix commit_hash
  parents = `git rev-list --parents -n 1 #{commit_hash}`.split
  return if retrieve_matrix commit_hash
  if parents.size == 3
    build_matrix parents[1] if !retrieve_matrix parents[1]
    build_matrix parents[2] if !retrieve_matrix parents[2]
    make_merge_matrix commit_hash, parents[1..2]
  elsif parents.size == 2
    build_matrix parents[1] if !retrieve_matrix parents[1]
    make_hard_matrix commit_hash, $Commit_matrices[parents[1]]
  else
    make_hard_matrix commit_hash, nil
  end
end

def make_merge_matrix commit_hash, parents
  return if $Commit_matrices.has_key? commit_hash

  parent1 = $Commit_matrices[parents.first]
  parent2 = $Commit_matrices[parents.last]
  diff = `git diff-tree --no-commit-id -r -M -c --name-status --root #{parents.first} #{commit_hash}`
  cache_commit commit_hash, CommitMatrix.merge(parent1, parent2, diff, commit_hash)
end

def make_hard_matrix commit_hash, parent
  return if $Commit_matrices.has_key? commit_hash

  commit_matrix = CommitMatrix.new commit_hash, parent
  name_statuses = `git diff-tree --no-commit-id -r -M -c --name-status --root #{commit_hash}`
  name_statuses.split("\n").each do |name_status|
    commit_matrix.handle_file name_status
  end
  commit_matrix.next_commit
  cache_commit commit_hash, commit_matrix
end

def retrieve_matrix hash
  return $Commit_matrices[hash] if $Commit_matrices.has_key? hash
  filename = "#{GIT_ROOT}/#{FOLDER_NAME}/#{hash}"
  if Pathname.new(filename).exist?
    file = File.open(filename, 'rb')
    serialized_matrix = file.read
    commit_matrix = Marshal.load serialized_matrix
    $Commit_matrices[hash] = commit_matrix
    return commit_matrix
  else
    return nil
  end
end

def cache_commit hash, commit_matrix
  $Commit_matrices[hash] = commit_matrix
  write_to_cache_file commit_matrix
  print_and_flush '.'
end

def print_and_flush(str)
    print str
    $stdout.flush
end

FOLDER_NAME = '.ctrlp-similar'
GIT_ROOT = `git rev-parse --show-toplevel`.chomp
$Commit_matrices = {}

def write_to_cache_file commit_matrix
  filename = "#{GIT_ROOT}/#{FOLDER_NAME}/#{commit_matrix.commit_hash}"
  return if Pathname.new(filename).exist?
  serialized_matrix = Marshal.dump(commit_matrix)
  File.open(filename, 'w') { |f| f.write serialized_matrix}
end

def make_cache_folder_if_not_exists
  `mkdir -p #{GIT_ROOT}/#{FOLDER_NAME}`
end

def humanize secs
  if secs < 1
    return "#{secs} seconds"
  end
  [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map{ |count, name|
    if secs > 0
      secs, n = secs.divmod(count)
      "#{n.to_i} #{name}"
    end
  }.compact.reverse.join(' ')
end

if __FILE__ == $0
  make_cache_folder_if_not_exists
  start = Time.new
  commit = `git rev-parse HEAD`.chomp

  build_matrix commit

  total_time = Time.new - start
  puts ''
  utf8 = lambda { |s| s.gsub(/\\u[\da-f]{4}/i) { |m| [m[-4..-1].to_i(16)].pack('U') }}
  puts "Finished in #{humanize total_time} #{utf8.call("\xF0\x9F\x9A\xB4")}"
  puts ''
  puts "Matrices for #{$Commit_matrices.size} commits generated"
end

