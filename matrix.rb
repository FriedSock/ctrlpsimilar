class Matrix
  #This won't work for all matrices, but at the
  #time of writing all rows are of length 1
  def to_a
    row_vectors.map(&:to_a).map(&:first)
  end
end
