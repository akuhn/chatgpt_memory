#!/usr/bin/env ruby
require "json"

def load_memories(path)
  JSON.parse(File.read(path, encoding: "UTF-8")).fetch("memories", [])
end

file_path = ARGV.first || "memories.json"
memories = load_memories(file_path)

memories
  .sort_by { |memory| memory["content"].length }
  .each_with_index do |memory, index|
    text = memory["content"].gsub(/\s+/, " ")
    puts "#{index + 1}. [#{memory["id"]}] (#{text.length}) #{text}"
  end

puts "Printed #{memories.length} memories"
