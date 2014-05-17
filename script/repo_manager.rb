require File.join(File.dirname(__FILE__), 'item_item.rb')

module RepoManager

  LIST_FILE_PATH = File.join(File.dirname(__FILE__), '../.repos')

  def repo_list
    `touch #{LIST_FILE_PATH}`
    File.open(LIST_FILE_PATH, "rb+").read.split "\n"
  end

  def add_repo_if_not_already path
    return unless !repo_is_initialized? path
    File.open(LIST_FILE_PATH, 'a+') do |f|
      f << path + "\n"
    end
  end

  def repo_is_initialized? path
    repo_list.include? path
  end

  def matrix_has_been_built?
    retrieve_matrix current_hash
  end

  def current_hash
    `git rev-parse HEAD`.chomp
  end

  extend self

end

#Methods that are available to be called from vim
def repo_name
  `git rev-parse --show-toplevel`.chomp
end

def add_repo
  RepoManager.add_repo_if_not_already repo_name
end

def determine_if_repo_is_initialized
  VIM::command("let s:repo_is_initialized = #{RepoManager.repo_is_initialized?(repo_name) ? 1 : 0}")
end

def determine_if_matrix_has_been_built
  VIM::command("let s:matrix_built = #{RepoManager.matrix_has_been_built? ? 1 : 0}")
end

def update_model_if_needed
  fork { build_matrix `git rev-parse HEAD`.chomp }
end

