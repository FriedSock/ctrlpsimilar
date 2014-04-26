require 'matrix.rb'
#require 'debugger'

class CommitMatrix

  attr_reader :filenames_to_columns, :number_of_files, :commit_hash
  attr_accessor :number_of_commits, :rows, :columns

  def initialize hash, parent
    @commit_hash = hash
    if parent
      @parent_hash = parent.commit_hash
      @columns = Marshal.load(Marshal.dump(parent.columns))
      @number_of_files = parent.number_of_files
      @number_of_commits = parent.number_of_commits + 1
      @filenames_to_columns = parent.filenames_to_columns.clone
      @rows = parent.rows.clone << hash
    else
      @columns = {}
      @number_of_files = 0
      @number_of_commits = 1
      @filenames_to_columns = {}
      @parent_hash = nil
      @rows = [] << hash
    end
    @modset = []
    @archived_files = {}
  end

  def add_one_value_to filename
    @columns[@filenames_to_columns[filename]] << 1
    @modset << filename
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
    @columns[@number_of_files] = Array.new(@number_of_commits-1).map(&:to_i)
    add_one_value_to filename
    @number_of_files += 1
  end

  def delete_file filename
    column = @filenames_to_columns.delete filename
    @archived_files[filename] = column
  end

  def next_commit
    @filenames_to_columns.keys.each do |key|
      add_zero_value_to key unless @modset.include? key
    end
    @modset = []
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
    elsif words.first =~ /R.*/
      rename_file words[-2], words.last
    elsif words.first =~ /D.*/
      delete_file words.last
    else
      puts "something has gone horribly wrong"
    end
  end

  #In the case of a merge, we just want to reinstate any additions (that were deleted on one branch)
  def handle_merge_file file
    words = file.split
    puts file
    if words.first =~ /A.*/
      #puts "weeee"
      #reinstate_file file
    else
      #puts "oh no"
    end
  end

  #Merge 2 commits
  def self.merge matrix1, matrix2, diff
    matrix1 = Marshal.load(Marshal.dump(matrix1))
    matrix2 = Marshal.load(Marshal.dump(matrix2))
    diff.split("\n").each do |file|
      #TODO: This method is a place for optimizations
      words = file.split
      if words.first =~ /R.*/
        matrix2.rename_file words[-2], words[-1]
        size = matrix2.columns[matrix2.filenames_to_columns[words[-1]]].size
        matrix2.columns[matrix2.filenames_to_columns[words[-1]]].delete_at size-1
      elsif words.first =~ /A.*/
        #Need to be careful here
        debugger
        hello = 1
      elsif words.first =~ /M.*/
        #Don't need to do anything
      elsif words.first =~ /D.*/
        #Need to be careful here
        debugger
        hello = 1
      end
    end

    most_recent_ancestor = `git merge-base #{[matrix1,matrix2].map{ |m| m.commit_hash }.join " "}`.chomp
    slice_index = matrix2.rows.index(most_recent_ancestor) + 1

    #Dollop rows from matrix2 ontop of matrix1
    matrix1.rows += matrix2.rows[slice_index..-1]
    matrix1.filenames_to_columns.each do |k,v|
      matrix1.columns[v] += matrix2.columns[matrix2.filenames_to_columns[k]][slice_index..-1]
    end
    matrix1.number_of_commits = matrix1.rows.size
  end

end
