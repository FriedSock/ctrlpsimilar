require 'matrix.rb'
require 'debugger'

class CommitMatrix

  attr_reader :filenames_to_columns, :number_of_files
  attr_accessor :number_of_commits, :rows, :columns, :commit_hash

  def initialize hash, parent
    @commit_hash = hash
    if parent
      @parent_hash = parent.commit_hash
      @number_of_files = parent.number_of_files
      @number_of_commits = parent.number_of_commits
      @filenames_to_columns = Marshal.load(Marshal.dump(parent.filenames_to_columns))
      @rows = parent.rows.clone.tap { |rows| rows[hash] = [] }
    else
      @number_of_files = 0
      @number_of_commits = 0
      @filenames_to_columns = {}
      @parent_hash = nil
      @rows = {hash => []}
    end
    @archived_files = {}
  end

  def filenames
    @filenames_to_columns.keys
  end

  def add_one_value_to filename
    @rows[@commit_hash] << @filenames_to_columns[filename]
  end

  def rename_file oldfilename, newfilename
    @filenames_to_columns[newfilename] = @filenames_to_columns.delete oldfilename
    add_one_value_to newfilename
  end

  def create_new_file filename
    @filenames_to_columns[filename] = @number_of_files
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

  def file_vector filename
    arr = []
    @rows.each do |r|
      col = @filenames_to_columns[filename]
      arr << (r.last.include?(col) ? 1 : 0)
    end
    Vector.[] *arr
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
      exit(1)
    end
  end

  #Merge 2 commits
  def self.merge matrix1, matrix2, diff, commit_hash
    matrix1 = Marshal.load(Marshal.dump(matrix1))
    matrix2 = Marshal.load(Marshal.dump(matrix2))

    most_recent_ancestor = `git merge-base #{[matrix1,matrix2].map{ |m| m.commit_hash }.join " "}`.chomp

    size_of_matrix1_diff = `git rev-list #{most_recent_ancestor}..#{matrix1.commit_hash} --count`.to_i

    new_commits = matrix2.rows.select { |k,v| !matrix1.rows.keys.include? k }.keys
    matrix1.rows = matrix2.rows.merge matrix1.rows
    #for renames and additions we need to go through the whole set of 'new' commits and convert the old column values
    #to the new ones.
    renamed_files = []
    diff.split("\n").each do |file|
      words = file.split
      if words.first =~ /R.*/
        matrix1.rename_file words[-2], words[-1]
        #Not sure about this..
      elsif words.first =~ /A.*/
        matrix1.create_new_file_with_history words.last
        renamed_files << words.last
      elsif words.first =~ /M.*/
        #Don't need to do anything
      elsif words.first =~ /D.*/
        matrix1.delete_file words.last
      end
    end

    new_commits.each do |hash|
      new_list = []
      renamed_files.each do |filename|
        col = matrix1.filenames_to_columns[filename]
        old_col = matrix2.filenames_to_columns[filename]
        list = matrix1.rows[hash]
        if list.include? old_col
          list.delete old_col
          new_list << col
        end
        matrix1.rows[hash] = list + new_list
      end
    end

    matrix1.number_of_commits = matrix1.rows.size
    matrix1.rows[commit_hash] = []
    matrix1.commit_hash = commit_hash
    matrix1.next_commit
    matrix1
  end


end
