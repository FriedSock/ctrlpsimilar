require File.join(File.dirname(__FILE__), 'commit_matrix.rb')
require File.join(File.dirname(__FILE__), 'item_item.rb')
require File.join(File.dirname(__FILE__), 'predictor.rb')

def is_merge_commit? hash
  `git rev-list --parents -n 1 #{hash}`.split.count == 3
end

def make_observation hash
  observation_hash = {}
  name_statuses = `git diff-tree --no-commit-id -r -M -c --name-status --root #{hash}`
  name_statuses.split("\n").each do |name_status|
    if name_status =~ /M|A.*/
      observation_hash[name_status.split.last] = 1
    end
  end
  observation_hash
end

if __FILE__ == $0
  commits = `git rev-list --all --topo-order --reverse`.split("\n")
  evaluated_commits = 0
  mae_sum = 0
  mse_sum = 0
  commits.each do |commit_hash|
    commit_matrix = retrieve_matrix commit_hash
    next if !commit_matrix || is_merge_commit?(commit_hash)

    prediction_hash = {}
    observation = make_observation commit_hash
    observation.each do |k, v|
      left_one_out = observation.select { |ok, ov| ok != k }
      next if left_one_out.empty?
      predictor = Predictor.new(left_one_out, commit_matrix)
      prediction_hash[k] = predictor.predict[k] if predictor.predict[k]
    end
    prediction_hash = Predictor.new(observation, commit_matrix).predict.merge prediction_hash
    next if prediction_hash.empty?
    actual_value = lambda { |f| return observation[f] || 0 }
    puts "Hash: #{commit_hash}"
    mae = prediction_hash.map { |k,v| k - actual_value.call(k) }.map(&:abs).reduce(:+) / prediction_hash.size.to_f
    mse = prediction_hash.map { |k,v| k - actual_value.call(k) }.map { |n| n ** 2 }.reduce(:+) / prediction_hash.size.to_f
    evaluated_commits +=1 if mae > 0
    mae_sum += mae
    mse_sum += mse
    puts "MAE: #{mae}"
    puts "MSE: #{mse}"
    puts ""
  end
  puts ""
  puts "mean MAE: #{mae_sum / evaluated_commits}"
  puts "mean MSE: #{mse_sum / evaluated_commits}"
end

