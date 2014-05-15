require File.join(File.dirname(__FILE__), 'commit_matrix.rb')
require File.join(File.dirname(__FILE__), 'item_item.rb')
require File.join(File.dirname(__FILE__), 'predictor.rb')
require File.join(File.dirname(__FILE__), '../third_party/Logistic-Regression/classifier.rb')
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

def print_and_flush(str)
  print str
  $stdout.flush
end
MAX_NUMBER_OF_IDENTICALISH_TRAINING_RESULTS = 40

def test_measure similarity_type, using_classifier
  commits = `git rev-list HEAD --topo-order --reverse -n 1000`.split("\n").map { |c| c[0..9] }
  evaluated_commits = 0
  mse_sum = 0
  pos_evaluated_commits = 0
  true_positives = 0
  false_positives = 0
  false_negatives = 0
  similarity_results = []
  last_prediction_hash = nil

  all_predictions = []
  classifier = nil

  commits.each do |commit_hash|
    commit_matrix = retrieve_matrix commit_hash
    next if !commit_matrix || is_merge_commit?(commit_hash)

    prediction_hash = {}
    observation = make_observation commit_hash
    observation.each do |k, v|
      left_one_out = observation.reject { |ok, ov| ok == k }
      next if left_one_out.empty?
      predictor = Predictor.new(left_one_out, commit_matrix, similarity_type)
      prediction_hash[k] = predictor.predict[k] if predictor.predict[k]
    end

    actual_value = lambda { |f| return observation[f] || 0 }
    prediction_hash = Predictor.new(observation, commit_matrix, similarity_type).predict.merge prediction_hash
    similarity_results += prediction_hash.map { |k,v| [v, actual_value.call(k)] }

    last_prediction_hash = prediction_hash.map { |k,v| [v, actual_value.call(k)] } if !prediction_hash.empty?

    if using_classifier && classifier && !prediction_hash.empty?
      observation_matrix = prediction_hash.values.map { |h| [1] << h }
      result = prediction_hash.keys.zip classifier.classify(observation_matrix).to_a
      prediction_hash = {}.tap { |new_hash| result.each { |r| new_hash[r[0]] = r[1] } }
    end


    if using_classifier && !prediction_hash.empty? && last_prediction_hash
      id = 0

                                  # [id,      yvalue, 1, xvalue]
      train_data = lambda { |point| [id+=1, point[1], 1, point[0]]}
      classifier = Classifier.new
      training_set = (similarity_results.reverse.select{|a| a[1] == 1 }.take(50) + similarity_results.reverse.select{|a| a[1] == 0 }.take(50)).shuffle
      #training_set = last_prediction_hash
      classifier.set_train_data training_set.map{ |p| train_data.call p }
      classifier.train
    end


    next if prediction_hash.empty? || (!classifier && using_classifier)

    mse = prediction_hash.map { |k,v| v - actual_value.call(k) }.map { |n| n ** 2 }.reduce(:+) / prediction_hash.size.to_f
    mse_sum += mse
    evaluated_commits +=1 if mse > 0

    all_predictions += prediction_hash.sort { |p1, p2| p2[1] <=> p1[1] }.map { |k,v| [v, actual_value.call(k)]}.select { |v,_| v > 0.5 }
    true_positives += prediction_hash.map { |k,v| [v, actual_value.call(k)] }.count {|k| k[0] > 0.5 && k[1] == 1}
    false_positives += prediction_hash.map { |k,v| [v, actual_value.call(k)] }.count {|k| k[0] > 0.5 && k[1] == 0}
    false_negatives += prediction_hash.map { |k,v| [v, actual_value.call(k)] }.count {|k| k[0] < 0.5 && k[1] == 1}

    #Let the user know the loop has finised
    print_and_flush '.'
  end


  all_predictions.sort! {|p1,p2| p2[0] <=> p1[0] }
  xcounter = 0
  ycounter = 0
  pos = lambda { |p| p[1] == 1 ? [xcounter, ycounter+=1] : [xcounter+=1, ycounter] }
  graph_points = all_predictions.map {|p| pos.call p }
  lastx, lasty = graph_points.last.map(&:to_f)
  normalize = lambda { |graph_point| [lastx == 0 ? 0 : graph_point.first / lastx, lasty == 0 ? 0 : graph_point.last / lasty] }
  normalized_points = graph_points.map { |gp| normalize.call gp }

  area_sum = 0
  normalized_points.each_cons(2) { |first, second| area_sum += ((second[0] - first[0]) * second[1]) }

  puts ""
  puts "mean MSE: #{mse_sum / evaluated_commits}"
  puts "Swets' a measure: #{area_sum}"

  precision = true_positives / (true_positives + false_positives).to_f
  recall = true_positives / (true_positives + false_negatives).to_f
  puts "Precision: #{precision}"
  puts "Recall: #{recall}"
end

if __FILE__ == $0
  measures = [:inner, :pearson, :cosine, :jaccard, :time_inner_prod, :time_pearson, :time_cosine]
  [false,true].each do |using_classifier|
    measures.each do |m|
      with_or_without = using_classifier ? "with" : "without"
      puts "Testing #{m} #{with_or_without} logisic regression"
      test_measure m, using_classifier
      puts ''
    end
  end
end

