#!/usr/bin/env ruby
require 'json'
require 'set'

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
  text.downcase.scan(/[a-z]+/).map { |word| stem(word) }
end

def vector(tokens)
  tokens.each_with_object(Hash.new(0)) { |token, counts| counts[token] += 1 }
end

def cosine_similarity(a, b)
  shared = a.keys & b.keys
  numerator = shared.sum { |term| a[term] * b[term] }.to_f
  mag_a = Math.sqrt(a.values.sum { |v| v * v })
  mag_b = Math.sqrt(b.values.sum { |v| v * v })
  return 0.0 if mag_a.zero? || mag_b.zero?

  numerator / (mag_a * mag_b)
end

def build_clusters(memories, vectors, threshold)
  neighbors = Hash.new { |h, k| h[k] = [] }

  memories.each_with_index do |_mem, i|
    (i + 1...memories.length).each do |j|
      score = cosine_similarity(vectors[i], vectors[j])
      next if score < threshold

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
threshold = 0.5
preview_length = 120

json_text = File.binread(path).force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
payload = JSON.parse(json_text)
memories = payload.fetch('memories')
vectors = memories.map { |m| vector(words(m['content'])) }
clusters = build_clusters(memories, vectors, threshold)

if clusters.empty?
  puts "No clusters found at threshold #{threshold}."
  exit 0
end

puts "Found #{clusters.length} cluster(s) at threshold #{threshold}."
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
    snippet = memory['content'].to_s.gsub(/\s+/, ' ').strip
    snippet = snippet[0, preview_length] + '...' if snippet.length > preview_length
    puts "- #{memory['id']} | #{snippet}"
  end

  puts
end
