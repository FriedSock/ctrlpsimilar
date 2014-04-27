require 'matrix.rb'
require 'debugger'
require File.join(File.dirname(__FILE__), 'object.rb')

class CommitMatrix

  attr_reader :filenames_to_columns, :number_of_files, :commit_hash
  attr_accessor :number_of_commits, :rows, :columns

  def initialize hash, parent
    @commit_hash = hash
    if parent
      @parent_hash = parent.commit_hash
      puts 'prof'
      @columns = parent.columns.deep_clone
      puts 'profddd'
      @number_of_files = parent.number_of_files
      @number_of_commits = parent.number_of_commits
      @filenames_to_columns = parent.filenames_to_columns.clone
      @rows = parent.rows.clone << hash
    else
      @columns = {}
      @number_of_files = 0
      @number_of_commits = 0
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
    @columns[@number_of_files] = Array.new(@number_of_commits).map(&:to_i)
    add_one_value_to filename
    @number_of_files += 1
  end

  #Insert a bunch of zeros into the recieved column for each of the differing commits
  def create_new_file_with_history filename, column, zero_insert_range
    @filenames_to_columns[filename] = @number_of_files
    start, finish = *zero_insert_range
    @columns[@number_of_files] = column[0..start-1] +
                                 Array.new(finish-start+1).map(&:to_i) +
                                 column[start..-1]
    @number_of_files += 1
  end

  def delete_file filename
    column = @filenames_to_columns.delete filename
    columns.delete column
    #@archived_files[filename] = column
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
  def self.merge matrix1, matrix2, diff, commit_hash
    matrix1 = matrix1.deep_clone
    matrix2 = matrix2.deep_clone

    most_recent_ancestor = `git merge-base #{[matrix1,matrix2].map{ |m| m.commit_hash }.join " "}`.chomp
    debugger if !matrix2.rows.index(most_recent_ancestor)

    slice_index = matrix2.rows.index(most_recent_ancestor) + 1

    size_of_matrix1_diff = `git rev-list #{most_recent_ancestor}..#{matrix1.commit_hash} --count`.to_i

    puts 'boooo'

    diff.split("\n").each do |file|
      #TODO: This method is a place for optimizations
      words = file.split
      if words.first =~ /R.*/
        matrix2.rename_file words[-2], words[-1]
        size = matrix2.columns[matrix2.filenames_to_columns[words[-1]]].size
        matrix2.columns[matrix2.filenames_to_columns[words[-1]]].delete_at size-1
      elsif words.first =~ /A.*/
        new_file_columns = matrix2.columns[matrix2.filenames_to_columns[words.last]]
        matrix1.create_new_file_with_history words.last, new_file_columns, [slice_index, slice_index+size_of_matrix1_diff-1]
      elsif words.first =~ /M.*/
        #Don't need to do anything
      elsif words.first =~ /D.*/
        #Need to be careful here
        matrix1.delete_file words.last
      end
    end

    #WHOLE THING A MESS
    debugger
    if matrix1.rows.index(most_recent_ancestor) != matrix2.rows.index(most_recent_ancestor)
      #The history is differing, and the 2 lists of rows need merging
      mash_lists matrix1, matrix2, :end_at => most_recent_ancestor
    end
    puts commit_hash

    #Dollop rows from matrix2 ontop of matrix1
    matrix1.rows += matrix2.rows[slice_index..-1]
    matrix1.filenames_to_columns.each do |k,v|
      if matrix2.filenames_to_columns.has_key? k
        if v.size < matrix1.rows.size
          debugger
        end
        thing = matrix2.columns[matrix2.filenames_to_columns[k]]
        slicething = thing[slice_index..-1]
        matrix1.columns[v].concat slicething
      else
        matrix1.columns[v].concat Array.new(matrix2.number_of_commits-slice_index).map(&:to_i)
      end
    end
    matrix1.number_of_commits = matrix1.rows.size
    matrix1.rows << commit_hash
    matrix1.next_commit

    matrix1.columns.each do |k,v|
      puts v.size
      debugger if v.size != matrix1.rows.size
      hello = 1
    end

    matrix1
  end

  #precondition, the lists will have the same base and the same end
  def self.mash_lists matrix1, matrix2, opts={}
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
      i2 += 0
      return list1 if opts[:end_at] && opts[:end_at] == item
    end
    list1
  end

end
