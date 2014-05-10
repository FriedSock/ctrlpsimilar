require File.join(File.dirname(__FILE__), 'commit_matrix.rb')
require File.join(File.dirname(__FILE__), 'item_item.rb')
require File.join(File.dirname(__FILE__), 'predictor.rb')
require File.join(File.dirname(__FILE__), 'third_party/Logistic-Regression/classifier.rb')
require File.join(File.dirname(__FILE__), 'matrix.rb')

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

def humanize secs
  [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map{ |count, name|
    if secs > 0
      secs, n = secs.divmod(count)
      "#{n.to_i} #{name}"
    end
  }.compact.reverse.join(' ')
end

MAX_NUMBER_OF_IDENTICALISH_TRAINING_RESULTS = 40

if __FILE__ == $0
  commits = `git rev-list --all --topo-order --reverse`.split("\n")
  evaluated_commits = 0
  mae_sum = 0
  mse_sum = 0
  positive_mse_sum = 0
  pos_evaluated_commits = 0
  true_positives = 0
  false_positives = 0
  false_negatives = 0
  similarity_results = []
  scatter_plot = []

  all_predictions = []
  classifier = nil

  retrain_classifier = true
  old_theta = []
  same_counter = 0

  commits.each do |commit_hash|
    commit_matrix = retrieve_matrix commit_hash
    next if !commit_matrix || is_merge_commit?(commit_hash)

    prediction_hash = {}
    observation = make_observation commit_hash
    observation.each do |k, v|
      left_one_out = observation.reject { |ok, ov| ok == k }
      next if left_one_out.empty?
      predictor = Predictor.new(left_one_out, commit_matrix)
      prediction_hash[k] = predictor.predict[k] if predictor.predict[k]
    end

    actual_value = lambda { |f| return observation[f] || 0 }
    prediction_hash = Predictor.new(observation, commit_matrix).predict.merge prediction_hash
    similarity_results += prediction_hash.map { |k,v| [v, actual_value.call(k)] }

    if classifier && !prediction_hash.empty?

      if (old_theta.length == classifier.thetaMatrix.to_a.length) && retrain_classifier
        if old_theta.zip(classifier.thetaMatrix.to_a).map{|a| a.flatten.reduce(:-)}.map{|v| v.abs < 0.2}.reduce(:&)
          same_counter += 1
          retrain_classifier = false if same_counter == MAX_NUMBER_OF_IDENTICALISH_TRAINING_RESULTS
        else
          old_theta = classifier.thetaMatrix.to_a
          same_counter = 0
        end
      else
        old_theta = classifier.thetaMatrix.to_a
      end

      things = prediction_hash.map { |k,v| [v,actual_value.call(k)]}
      vals = things.map {|h| [] << h.first}
      result = prediction_hash.keys.zip classifier.classify(vals)
      prediction_hash = {}.tap { |new_hash| result.each { |r| new_hash[r[0]] = r[1] } }
    end
    scatter_plot += prediction_hash.map { |k,v| [v, actual_value.call(k)] }

    next if prediction_hash.empty?
    #puts "Hash: #{commit_hash}"
    mae = prediction_hash.map { |k,v| v - actual_value.call(k) }.map(&:abs).reduce(:+) / prediction_hash.size.to_f
    mse = prediction_hash.map { |k,v| v - actual_value.call(k) }.map { |n| n ** 2 }.reduce(:+) / prediction_hash.size.to_f
    positive_mse = prediction_hash.map { |k,v| actual_value.call(k) == 1 ? v - 1 : nil}.compact

    if !positive_mse.empty?
      positive_mse.map! { |n| n**2 }
      positive_mse = positive_mse.reduce(:+) / positive_mse.size.to_f
      #puts "Positive MSE #{positive_mse}"
      pos_evaluated_commits += 1
      positive_mse_sum += positive_mse
    end
    all_predictions += prediction_hash.sort { |p1, p2| p2[1] <=> p1[1] }.map { |k,v| [v, actual_value.call(k)]}.select { |v,_| v > 0.5 }

    true_positives += prediction_hash.map { |k,v| [v, actual_value.call(k)] }.count {|k| k[0] > 0.5 && k[1] == 1}
    false_positives += prediction_hash.map { |k,v| [v, actual_value.call(k)] }.count {|k| k[0] > 0.5 && k[1] == 0}
    false_negatives += prediction_hash.map { |k,v| [v, actual_value.call(k)] }.count {|k| k[0] < 0.5 && k[1] == 1}

    evaluated_commits +=1 if mae > 0
    mae_sum += mae
    mse_sum += mse
    #puts "MAE: #{mae}"
    #puts "MSE: #{mse}"
    #puts "theta #{[classifier.thetaMatrix]}" if classifier
    #puts ""
    puts '.'


    if retrain_classifier
      #puts "same_counter: #{same_counter}"
      id = 0
      train_data = lambda { |point| [id+=1, point[1], point[0]]}
      classifier = Classifier.new(maxSample=500)
      training_set = (similarity_results.reverse.select{|a| a[1] == 1 }.take(50) + similarity_results.reverse.select{|a| a[1] == 0 }.take(50)).shuffle
      classifier.set_train_data training_set.map{ |p| train_data.call p }
      classifier.train
    end

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
  end

  CSV.open('scatter.csv', 'w') do |csv|
    scatter_plot.each do |np|
      csv << np
    end
  end

  #found = Set.new
  #remove_dups = lambda do |p|
  #  if found.include? p[0]
  #    return nil
  #  else
  #    found.add p[0]
  #    return p
  #  end
  #end
  #normalized_points = normalized_points.reverse.map { |p| remove_dups.call p }.compact.reverse

  area_sum = 0
  normalized_points.each_cons(2) { |first, second| area_sum += ((second[0] - first[0]) * second[1]) }

   plotcommandpath = File.join(File.dirname(__FILE__), 'plotcommands.gp')
   scatterplotcommandpath = File.join(File.dirname(__FILE__), 'scatterplotcommands.gp')
  `gnuplot #{plotcommandpath}`
  `gnuplot #{scatterplotcommandpath}`

  puts ""
  puts "mean MAE: #{mae_sum / evaluated_commits}"
  puts "mean MSE: #{mse_sum / evaluated_commits}"
  puts "mean Positive MSE: #{positive_mse_sum / pos_evaluated_commits}"
  puts "Swets' a measure: #{area_sum}"

  precision = true_positives / (true_positives + false_positives).to_f
  recall = true_positives / (true_positives + false_negatives).to_f
  puts "Precision: #{precision}"
  puts "Recall: #{recall}"
end

