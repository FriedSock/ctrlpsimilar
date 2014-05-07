require File.join(File.dirname(__FILE__), 'commit_matrix.rb')
require File.join(File.dirname(__FILE__), 'item_item.rb')
require File.join(File.dirname(__FILE__), 'predictor.rb')
require 'csv'

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
  positive_mse_sum = 0
  pos_evaluated_commits = 0


  all_predictions = []

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
    mae = prediction_hash.map { |k,v| v - actual_value.call(k) }.map(&:abs).reduce(:+) / prediction_hash.size.to_f
    mse = prediction_hash.map { |k,v| v - actual_value.call(k) }.map { |n| n ** 2 }.reduce(:+) / prediction_hash.size.to_f
    positive_mse = prediction_hash.map { |k,v| actual_value.call(k) == 1 ? v - 1 : nil}.compact

    if !positive_mse.empty?
      positive_mse.map! { |n| n**2 }
      positive_mse = positive_mse.reduce(:+) / positive_mse.size.to_f
      puts "Positive MSE #{positive_mse}"
      pos_evaluated_commits += 1
      positive_mse_sum += positive_mse
    end
    all_predictions += prediction_hash.map { |k,v| [v, actual_value.call(k)] }.select {|_,v| v > 0.5}

    evaluated_commits +=1 if mae > 0
    mae_sum += mae
    mse_sum += mse
    puts "MAE: #{mae}"
    puts "MSE: #{mse}"
    puts ""
  end
  all_predictions.sort! {|p1,p2| p2[0] <=> p1[0] }
  xcounter = 0
  ycounter = 0
  pos = lambda { |p| p[1] == 1 ? [xcounter, ycounter+=1] : [xcounter+=1, ycounter] }
  graph_points = all_predictions.map {|p| pos.call p }
  lastx, lasty = graph_points.last.map(&:to_f)
  normalize = lambda { |graph_point| [lastx == 0 ? 0 : graph_point.first / lastx, lasty == 0 ? 0 : graph_point.last / lasty] }
  normalized_points = graph_points.map { |gp| normalize.call gp }

  CSV.open('roc.csv', 'w') do |csv|
    normalized_points.each do |np|
      csv << np
    end
    csv << [1,1]
  end

   plotcommandpath = File.join(File.dirname(__FILE__), 'plotcommands.gp')
  `gnuplot #{plotcommandpath}`

  puts ""
  puts "mean MAE: #{mae_sum / evaluated_commits}"
  puts "mean MSE: #{mse_sum / evaluated_commits}"
  puts "mean Positive MSE: #{positive_mse_sum / pos_evaluated_commits}"
end

