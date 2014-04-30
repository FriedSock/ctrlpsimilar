require 'matrix.rb'

class Predictor

  def initialize observation, commit_matrix
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
    return_hash.select { |k,v| !@observation.has_key? k }
  end

  def file_similarity file1, file2
    v1 = @commit_matrix.file_vector file1
    v2 = @commit_matrix.file_vector file2
    debugger if v1.size != v2.size
    debugger if @commit_matrix.commit_hash == "751f48f634e015b4e4c0580fdd0e70356cfe88bc" && file2 =~ /fitnessTemp.*/
    return v1.inner_product(v2) / (v1.r * v2.r)
  end

end

