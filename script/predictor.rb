require 'matrix.rb'

class Predictor

  def initialize observation, commit_matrix, similarity_type=:time_inner_prod
    @similarity_type = similarity_type
    @file_size_cache = {}
    @time_weighted_mean_cache = {}
    @standard_deviation_cache = {}
    @observation = observation
    @commit_matrix = commit_matrix
  end

  def predict
    #For each 1 file, get the list of files similar to it, then get the 1 out of it.
    return_hash = {}
    observation_count = 0
    @observation.each do |observed_filename, v|
      observation_count += 1
      next unless @commit_matrix.filenames.include? observed_filename
      @commit_matrix.filenames.each do |repo_filename|
        return_hash[repo_filename] = 0 if !return_hash.has_key? repo_filename
        next if observed_filename == repo_filename

        return_hash[repo_filename] += file_similarity(observed_filename, repo_filename) / @observation.size
      end
    end
    #exlude the filenames that *are* in the obseration -- we know they are 1
    return_hash.reject { |k,v| @observation.has_key? k }
  end

  def file_similarity file1, file2

    case @similarity_type
    when :time_inner_prod
      return time_weight_inner_prod(file1, file2)
    when :time_cosine
      return time_weight_inner_prod(file1, file2) / (time_weight_size(file1) * time_weight_size(file2))
    when :time_pearson
      return time_weight_pearson_correlation(file1, file2)
    when :cosine
      return inner_prod(file1,file2) / (size(file1) * size(file2))
    when :pearson
      return pearson_correlation file1, file2
    when :inner
      return inner_prod(file1,file2)
    when :jaccard
      return jaccard_similarity file1, file2
    end
  end

  def jaccard_similarity file1, file2
    set1 = @commit_matrix.file(file1).dup
    set2 = @commit_matrix.file(file2).dup
    return (set1 & set2).size / (set1 | set2).size.to_f
  end

  def pearson_correlation file1, file2
    set1 = @commit_matrix.file(file1).dup
    set2 = @commit_matrix.file(file2).dup
    number_of_commits = @commit_matrix.ordered_rows.size.to_f
    mean1 = set1.size / number_of_commits
    mean2 = set2.size / number_of_commits

    partial_numerator = (set1 | set2).map do |s|
      if set1.include? s
        if set2.include? s
          (1 - mean1) * (1 - mean2)
        else
          #(1 - mean1) * (mean2*-1)
          (mean1 - 1) * mean2
        end
      else
        #(1 - mean2) * (mean1*-1)
        (mean2 - 1) * mean1
      end
    end
    numerator = partial_numerator.reduce(:+) + (number_of_commits * mean1 * mean2)

    dev1 = Math.sqrt((set1.size * ((1 - mean1)**2)) + ((number_of_commits-set1.size)*(mean1**2)))
    dev2 = Math.sqrt((set2.size * ((1 - mean2)**2)) + ((number_of_commits-set2.size)*(mean2**2)))

    denom = dev1 * dev2
    return (denom == 0) ? 0 : numerator / (dev1 * dev2)
  end

  def time_weight_pearson_correlation file1, file2
    set1 = @commit_matrix.file(file1).dup
    set2 = @commit_matrix.file(file2).dup
    mean1 = time_weighted_mean file1
    mean2 = time_weighted_mean file2

    partial_numerator = 0
    (set1 | set2).map do |s|
      weight = weighted_rows[s]
      if set1.include? s
        if set2.include? s
          partial_numerator += (weight - mean1) * (weight - mean2)
        else
          partial_numerator += (weight - mean1) * (mean2*-1)
        end
      else
        partial_numerator += mean1 * (weight - mean2)
      end
    end
    n = @commit_matrix.ordered_rows.size

    #Sum of all the weighted rows = (((n * (n+1))/2) + n) / n
    # => ((1 * (1 + 1/n))/2) + 1
    # => 1/2 + 1/2n + 1
    # => 1.5 + n/2
    both_zero_elements = (((1.5 + n/2)-(set1|set2).size) * mean1 * mean2)
    numerator = partial_numerator + both_zero_elements

    dev1 = time_weight_standard_deviation file1
    dev2 = time_weight_standard_deviation file2

    denom = dev1 * dev2
    return (denom == 0) ? 0 : (numerator / denom)
  end

  def time_weight_standard_deviation file
    return @standard_deviation_cache[file] if @standard_deviation_cache.has_key? file
    set = @commit_matrix.file file
    mean = time_weighted_mean file
    meansquared = mean ** 2
    partial = set.map {|r| (weighted_rows[r] - mean)**2 }.reduce(:+)
    zeros = meansquared * (@commit_matrix.ordered_rows.size - set.size)
    @standard_deviation_cache[file] = Math.sqrt(partial + zeros)
  end

  def time_weighted_mean file
    return @file_size_cache[file] if @file_size_cache.has_key? file
    set = @commit_matrix.file file
    @file_size_cache[file] = set.map { |h| weighted_rows[h] }.reduce(:+) / set.size
  end

  def inner_prod file1, file2
    vec1 = @commit_matrix.file file1
    vec2 = @commit_matrix.file file2
    (vec1 & vec2).size
  end

  #Linear time decay
  def time_weight_inner_prod file1, file2
    vec1 = @commit_matrix.file file1
    vec2 = @commit_matrix.file file2
    ((vec1 & vec2).map {|v| weighted_rows[v] ** 2}+[0]).reduce(:+)
  end

  def size file
    Math.sqrt(@commit_matrix.file(file).size)
  end

  def weighted_rows
    @_rows ||= {}.tap do |hash|
      size = @commit_matrix.ordered_rows.size.to_f
      @commit_matrix.ordered_rows.each_with_index do |row,index|
        hash[row] = (index+1) / size.to_f
        #hash[row] = 0.5 ** (((index+1)*4)/size.to_f)
      end
    end
  end

  def time_weight_size file
    return @file_size_cache[file] if @file_size_cache.has_key? file
    vec =  @commit_matrix.file(file)
    @file_size_cache[file] = Math.sqrt(vec.map {|v| weighted_rows[v]}.map{|v|v**2}.reduce(:+))
  end
end

