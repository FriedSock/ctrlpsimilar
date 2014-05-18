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

  def remove_repo_if_exists path
    return unless repo_is_initialized? path
    list_without_repo = File.open(LIST_FILE_PATH, "rb+").read.gsub(path, '')
    File.open(LIST_FILE_PATH, 'w') do |f|
      f << list_without_repo
    end
  end

  def repo_is_initialized? path
    repo_list.include? path
  end

  def matrix_has_been_built?
    retrieve_matrix current_hash
  end

  def current_hash
    `git rev-parse HEAD`.chomp[0..9]
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

def remove_repo
  RepoManager.remove_repo_if_exists repo_name
  `rm -rf #{repo_name}/.ctrlp-similar`
end

def determine_if_repo_is_initialized
  VIM::command("let s:repo_is_initialized = #{RepoManager.repo_is_initialized?(repo_name) ? 1 : 0}")
end

def determine_if_matrix_has_been_built
  VIM::command("let s:matrix_built = #{RepoManager.matrix_has_been_built? ? 1 : 0}")
end

def update_model_if_needed
  `mkdir -p #{repo_name}/.ctrlp-similar`
  fork { build_matrix `git rev-parse HEAD`.chomp[0..9] }
end

