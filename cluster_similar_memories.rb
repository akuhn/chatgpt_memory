#!/usr/bin/env ruby
require 'json'
require 'set'

def stopwords
  @stopwords ||= %w[
    a an and are as at be because been being but by can could did do does doing for from had has have having
    he her here hers herself him himself his how i if in into is it its itself just like may me might more most
    my myself no nor not of on once only or other our ours ourselves out over own same she should so some such
    than that the their theirs them themselves then there these they this those through to too under until up very
    was we were what when where which while who whom why will with would you your yours yourself yourselves
  ].to_set
end

def stem(word)
  w = word.downcase
  return w if w.length < 4

  if w.end_with?('ies') && w.length > 4
    w = w[0..-4] + 'y'
  elsif w.end_with?('ing') && w.length > 5
    w = w[0..-4]
  elsif w.end_with?('ed') && w.length > 4
    w = w[0..-3]
  elsif w.end_with?('ly') && w.length > 4
    w = w[0..-3]
  elsif w.end_with?('es') && w.length > 4
    w = w[0..-3]
  elsif w.end_with?('s') && w.length > 4
    w = w[0..-2]
  end

  w = w[0..-2] if w.length > 4 && w[-1] == w[-2]
  w
end

def words(text)
  text.downcase.scan(/[a-z]+/).map { |word| stem(word) }.reject { |word| stopwords.include?(word) }
end

def vector(tokens)
  counts = Hash.new(0)
  tokens.each { |token| counts[token] += 1 }
  counts
end

def build_matrix(vectors)
  doc_count = vectors.length
  doc_freq = Hash.new(0)
  vectors.each { |row| row.each_key { |word| doc_freq[word] += 1 } }
  vocab = {}
  vectors.each { |row| row.each_key { |word| vocab[word] ||= vocab.length } }

  vectors.map do |row|
    dense = Array.new(vocab.length, 0.0)
    row.each do |word, count|
      tf = 1.0 + Math.log(count)
      idf = Math.log((doc_count + 1.0) / (doc_freq[word] + 1.0)) + 1.0
      dense[vocab[word]] = tf * idf
    end
    dense
  end
end

def dot(a, b)
  a.zip(b).sum { |x, y| x * y }
end

def cosine_similarity(a, b)
  numerator = dot(a, b)
  mag_a = Math.sqrt(dot(a, a))
  mag_b = Math.sqrt(dot(b, b))
  return 0.0 if mag_a.zero? || mag_b.zero?

  numerator / (mag_a * mag_b)
end

def build_gram(matrix)
  n = matrix.length
  gram = Array.new(n) { Array.new(n, 0.0) }
  (0...n).each do |i|
    (i...n).each do |j|
      score = dot(matrix[i], matrix[j])
      gram[i][j] = score
      gram[j][i] = score
    end
  end
  gram
end

def multiply_matrix_vector(matrix, vector)
  matrix.map { |row| dot(row, vector) }
end

def normalize(vector)
  mag = Math.sqrt(dot(vector, vector))
  return vector if mag.zero?
  vector.map { |x| x / mag }
end

def project_away(vector, bases)
  out = vector.dup
  bases.each do |base|
    scale = dot(out, base)
    out = out.zip(base).map { |x, b| x - (scale * b) }
  end
  out
end

def decompose_svd(gram, dimensions, iterations)
  eigenvectors = []
  eigenvalues = []

  dimensions.times do
    candidate = Array.new(gram.length) { rand - 0.5 }
    candidate = normalize(project_away(candidate, eigenvectors))
    iterations.times do
      candidate = multiply_matrix_vector(gram, candidate)
      candidate = normalize(project_away(candidate, eigenvectors))
      break if dot(candidate, candidate).zero?
    end

    break if dot(candidate, candidate).zero?
    value = dot(candidate, multiply_matrix_vector(gram, candidate))
    next if value <= 1e-10

    eigenvectors << candidate
    eigenvalues << value
  end

  [eigenvectors, eigenvalues]
end

def embed_with_svd(matrix, dimensions, iterations)
  gram = build_gram(matrix)
  vectors, values = decompose_svd(gram, dimensions, iterations)
  return matrix if vectors.empty?

  if vectors.length > 1
    vectors = vectors[1..]
    values = values[1..]
  end

  matrix.each_index.map do |doc_idx|
    vectors.each_with_index.map do |vec, i|
      Math.sqrt(values[i]) * vec[doc_idx]
    end
  end
end

def normalize_embeddings(vectors)
  return vectors if vectors.empty?

  dimensions = vectors.first.length
  means = (0...dimensions).map do |i|
    vectors.sum { |vector| vector[i] } / vectors.length.to_f
  end

  vectors.map do |vector|
    centered = vector.each_with_index.map { |value, i| value - means[i] }
    mag = Math.sqrt(dot(centered, centered))
    mag.zero? ? centered : centered.map { |x| x / mag }
  end
end

def build_clusters(memories, vectors, threshold, gate_vectors, gate_threshold, top_k)
  similarities = Array.new(memories.length) { Array.new(memories.length, 0.0) }
  gate_similarities = Array.new(memories.length) { Array.new(memories.length, 0.0) }

  memories.each_with_index do |_mem, i|
    (i + 1...memories.length).each do |j|
      score = cosine_similarity(vectors[i], vectors[j])
      similarities[i][j] = score
      similarities[j][i] = score
      gate_score = cosine_similarity(gate_vectors[i], gate_vectors[j])
      gate_similarities[i][j] = gate_score
      gate_similarities[j][i] = gate_score
    end
  end

  top_neighbors = similarities.each_index.map do |i|
    similarities[i]
      .each_with_index
      .reject { |_score, j| i == j }
      .sort_by { |score, _j| -score }
      .first(top_k)
      .map { |_score, j| j }
      .to_set
  end

  neighbors = Hash.new { |h, k| h[k] = [] }
  memories.each_with_index do |_mem, i|
    (i + 1...memories.length).each do |j|
      score = similarities[i][j]
      gate_score = gate_similarities[i][j]
      next if score < threshold
      next if gate_score < gate_threshold
      next unless top_neighbors[i].include?(j) && top_neighbors[j].include?(i)

      neighbors[i] << [j, score]
      neighbors[j] << [i, score]
    end
  end

  visited = Set.new
  clusters = []

  memories.each_index do |i|
    next if visited.include?(i)
    next if neighbors[i].empty?

    queue = [i]
    component = []
    visited << i

    until queue.empty?
      node = queue.shift
      component << node
      neighbors[node].each do |neighbor, _score|
        next if visited.include?(neighbor)
        visited << neighbor
        queue << neighbor
      end
    end

    clusters << component
  end

  clusters
end

def best_pairs(cluster, vectors)
  pairs = []
  cluster.each_with_index do |i, idx|
    cluster[(idx + 1)..].to_a.each do |j|
      pairs << [[i, j], cosine_similarity(vectors[i], vectors[j])]
    end
  end
  pairs.sort_by { |_pair, score| -score }.first(3)
end

path = 'memories.json'
threshold = 0.74
preview_length = 120
svd_dimensions = 12
svd_iterations = 80
gate_threshold = 0.2
top_k = 3

json_text = File.binread(path).force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
payload = JSON.parse(json_text)
memories = payload.fetch('memories')
bow_vectors = memories.map { |m| vector(words(m['content'])) }
dense_matrix = build_matrix(bow_vectors)
vectors = normalize_embeddings(embed_with_svd(dense_matrix, svd_dimensions, svd_iterations))
gate_vectors = normalize_embeddings(dense_matrix)
clusters = build_clusters(memories, vectors, threshold, gate_vectors, gate_threshold, top_k)

if clusters.empty?
  puts "No clusters found at threshold #{threshold}."
  exit 0
end

puts "Found #{clusters.length} cluster(s) at threshold #{threshold} using SVD(#{svd_dimensions}) with TF-IDF gate #{gate_threshold} and top_k #{top_k}."
puts

clusters.sort_by { |cluster| -cluster.length }.each_with_index do |cluster, cluster_idx|
  puts "Cluster #{cluster_idx + 1} (#{cluster.length} memories)"
  puts '-' * 72

  best_pairs(cluster, vectors).each do |(a, b), score|
    puts format("  Similarity %.3f between %s and %s", score, memories[a]['id'], memories[b]['id'])
  end

  puts

  cluster.each do |idx|
    memory = memories[idx]
    snippet = memory['content'].gsub(/\s+/, ' ')
    snippet = snippet[0, preview_length] + '...' if snippet.length > preview_length
    puts "- #{memory['id']} | #{snippet}"
  end

  puts
end
