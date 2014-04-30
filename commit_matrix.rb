require 'matrix.rb'
require 'debugger'

class CommitMatrix

  attr_reader :filenames_to_columns, :number_of_files
  attr_accessor :number_of_commits, :rows, :columns, :commit_hash

  def initialize hash, parent
    @commit_hash = hash
    if parent
      @parent_hash = parent.commit_hash
      @columns = Marshal.load(Marshal.dump(parent.columns))
      @number_of_files = parent.number_of_files
      @number_of_commits = parent.number_of_commits
      @filenames_to_columns = Marshal.load(Marshal.dump(parent.filenames_to_columns))
      @rows = parent.rows.clone << hash
    else
      @columns = {}
      @number_of_files = 0
      @number_of_commits = 0
      @filenames_to_columns = {}
      @parent_hash = nil
      @rows = [] << hash
    end
    @archived_files = {}
  end

  def filenames
    @filenames_to_columns.keys
  end

  def add_one_value_to filename
    @columns[@filenames_to_columns[filename]] << 1
  end

  def add_zero_value_to filename
    @columns[@filenames_to_columns[filename]] << 0
  end

  def rename_file oldfilename, newfilename
    @filenames_to_columns[newfilename] = @filenames_to_columns.delete oldfilename
    add_one_value_to newfilename
  end

  def create_new_file filename
    @filenames_to_columns[filename] = @number_of_files
    @columns[@number_of_files] = Array.new(@number_of_commits).map(&:to_i)
    add_one_value_to filename
    @number_of_files += 1
  end

  def create_new_file_with_history filename
    @filenames_to_columns[filename] = @number_of_files
    @columns[@number_of_files] = Array.new(rows.size).map(&:to_i)
    @number_of_files += 1
  end

  def delete_file filename
    column = @filenames_to_columns.delete filename
    columns.delete column
  end

  def next_commit
    @filenames_to_columns.keys.each do |key|
      add_zero_value_to key if columns[filenames_to_columns[key]].size < rows.size
    end
    @number_of_commits += 1
  end

  def file_vector filename
    Vector.[] *@columns[@filenames_to_columns[filename]]
  end

  def handle_file file
    words = file.split
    if words.first =~ /M.*/
      add_one_value_to words.last
    elsif words.first =~ /A.*/
      create_new_file words.last
      @columns[@filenames_to_columns[words.last]].pop
      add_one_value_to words.last
    elsif words.first =~ /R.*/
      rename_file words[-2], words.last
    elsif words.first =~ /D.*/
      delete_file words.last
    else
      puts "something has gone horribly wrong"
      exit(1)
    end
  end

  #Merge 2 commits
  def self.merge matrix1, matrix2, diff, commit_hash
    matrix1 = Marshal.load(Marshal.dump(matrix1))
    matrix2 = Marshal.load(Marshal.dump(matrix2))

    most_recent_ancestor = `git merge-base #{[matrix1,matrix2].map{ |m| m.commit_hash }.join " "}`.chomp
    slice_index = matrix2.rows.index(most_recent_ancestor) + 1

    size_of_matrix1_diff = `git rev-list #{most_recent_ancestor}..#{matrix1.commit_hash} --count`.to_i

    diff.split("\n").each do |file|
      words = file.split
      if words.first =~ /R.*/
        matrix1.rename_file words[-2], words[-1]
        size = matrix1.columns[matrix1.filenames_to_columns[words[-1]]].size
        matrix1.columns[matrix1.filenames_to_columns[words[-1]]].delete_at size-1
      elsif words.first =~ /A.*/
        matrix1.create_new_file_with_history words.last
      elsif words.first =~ /M.*/
        #Don't need to do anything
      elsif words.first =~ /D.*/
        matrix1.delete_file words.last
      end
    end

    mash_lists matrix1, matrix2, :end_at => most_recent_ancestor

    #Dollop rows from matrix2 ontop of matrix1
    matrix1.rows += matrix2.rows[slice_index..-1]
    matrix1.filenames_to_columns.each do |k,v|
      if matrix2.filenames_to_columns.has_key? k
        thing = matrix2.columns[matrix2.filenames_to_columns[k]]
        slicething = thing[slice_index..-1]
        matrix1.columns[v].concat slicething
      else
        matrix1.columns[v].concat Array.new(matrix2.number_of_commits-slice_index).map(&:to_i)
      end
    end
    matrix1.number_of_commits = matrix1.rows.size
    matrix1.rows << commit_hash
    matrix1.commit_hash = commit_hash
    matrix1.next_commit
    matrix1
  end

  #precondition, the lists will have the same base and the same end
  #Essentially, take everything in matrix2 that is not in matrix1, and
  #shove it in. (before the specified point -- the most recent common
  #ancestor)
  def self.mash_lists matrix1, matrix2, opts={}
    return if opts[:end_at] == matrix1.rows.first
    i1 = 0
    i2 = 0
    list1 = matrix1.rows
    list2 = matrix2.rows

    list2.each do |item|
      while (item != list1[i1]) do
        if list1.include? item
          i1 = list1.index item
        else
          list1.insert i1, item
          matrix1.filenames_to_columns.each do |k,v|
            if !matrix2.filenames_to_columns[k]
              matrix1.columns[v].insert i1, 0
            else
              matrix1.columns[v].insert i1, matrix2.columns[matrix2.filenames_to_columns[k]][i2]
            end
          end
        end
      end
      i1 += 1
      i2 += 1
      return list1 if opts[:end_at] && opts[:end_at] == item
    end
    list1
  end

end
