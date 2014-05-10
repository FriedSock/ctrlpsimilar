require 'matrix.rb'
require 'set.rb'
require 'debugger'

class CommitMatrix

  attr_reader :filenames_to_columns, :number_of_files
  attr_accessor :number_of_commits, :rows, :columns, :commit_hash

  def initialize hash, parent
    @file_vector_cache = {}
    @commit_hash = hash
    if parent
      @parent_hash = parent.commit_hash
      @number_of_files = parent.number_of_files
      @number_of_commits = parent.number_of_commits
      @columns = Marshal.load(Marshal.dump(parent.columns))
      @filenames_to_columns = Marshal.load(Marshal.dump(parent.filenames_to_columns))
    else
      @number_of_files = 0
      @number_of_commits = 0
      @filenames_to_columns = {}
      @parent_hash = nil
      @columns = {}
    end
    @archived_files = {}
  end

  def filenames
    @filenames_to_columns.keys
  end

  def add_one_value_to filename
    @columns[@filenames_to_columns[filename]].add @commit_hash
  end

  def rename_file oldfilename, newfilename
    @filenames_to_columns[newfilename] = @filenames_to_columns.delete oldfilename
    add_one_value_to newfilename
  end

  def create_new_file filename
    @filenames_to_columns[filename] = @number_of_files
    @columns[@number_of_files] = Set.new
    add_one_value_to filename
    @number_of_files += 1
  end

  def create_new_file_with_history filename
    @filenames_to_columns[filename] = @number_of_files
    @number_of_files += 1
  end

  def delete_file filename
    #Todo, archive
    column = @filenames_to_columns.delete filename
  end

  def next_commit
    @number_of_commits += 1
  end

  def file filename
    @columns[@filenames_to_columns[filename]]
  end

  def handle_file file
    words = file.split
    if words.first =~ /M|T.*/
      add_one_value_to words.last
    elsif words.first =~ /A.*/
      create_new_file words.last
    elsif words.first =~ /R.*/
      rename_file words[-2], words.last
    elsif words.first =~ /D.*/
      delete_file words.last
    else
      puts "something has gone horribly wrong, please report this bug to jbtwentythree@gmail.com"
      exit(1)
    end
  end

  #Merge 2 commits
  def self.merge matrix1, matrix2, diff, commit_hash
    matrix1 = Marshal.load(Marshal.dump(matrix1))
    matrix2 = Marshal.load(Marshal.dump(matrix2))

    most_recent_ancestor = `git merge-base #{[matrix1,matrix2].map{ |m| m.commit_hash }.join " "}`.chomp

    size_of_matrix1_diff = `git rev-list #{most_recent_ancestor}..#{matrix1.commit_hash} --count`.to_i

    matrix1.commit_hash = commit_hash

    renamed_files = []
    diff.split("\n").each do |file|
      words = file.split
      if words.first =~ /R.*/
        matrix1.rename_file words[-2], words[-1]
        debugger if !matrix2.file(words[-1])
        matrix1.columns[matrix1.filenames_to_columns[words[-1]]] = matrix1.file(words[-1]) + matrix2.file(words[-1])
        #Not sure about this..
      elsif words.first =~ /A.*/
        matrix1.create_new_file_with_history words.last

        if matrix2.file(words.last)
          filename = words.last
        else
          #The file has been renamed as part of the resolution to a merge conflict, so we need to find its name from
          #the branch it was created on.
          little_diff = `git diff-tree --no-commit-id -r -M -c --name-status --root #{matrix2.commit_hash} #{commit_hash}`
          name_status_change = little_diff.split("\n").select{|f| f =~ /.*#{words.last}.*/}.first
          if name_status_change
            filename = name_status_change.split[1]
          else
            #For some reason, this is a new file since the merge..
            matrix1.create_new_file words.last
            next
          end
        end

        matrix1.columns[matrix1.filenames_to_columns[words.last]] = matrix2.file(filename)
        renamed_files << words.last
      elsif words.first =~ /M.*/
        #Don't need to do anything
      elsif words.first =~ /D.*/
        matrix1.delete_file words.last
      end
    end

    matrix1.number_of_commits = matrix1.ordered_rows.size
    matrix1.next_commit
    matrix1
  end

  def ordered_rows
    @_ordered_rows ||= `git rev-list --topo-order --reverse #{@commit_hash}`.split
  end


end
