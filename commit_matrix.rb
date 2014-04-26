require 'matrix.rb'
#require 'debugger'

class CommitMatrix

  attr_reader :filenames_to_columns

  def initialize
    @columns = {}
    @number_of_files = 0
    @number_of_commits = 0
    @filenames_to_columns = {}
    @modset = []
    @archived_files = {}
  end

  def add_one_value_to filename
    if not @columns[@filenames_to_columns[filename]]
      puts filename
    end
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
    if words.last == 'surrogatemodel.py'
      puts file
    end
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

end
