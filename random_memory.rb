#!/usr/bin/env ruby
require "json"

def pick_random_memory(path)
  memories = JSON.parse(File.read(path, encoding: "UTF-8")).fetch("memories", [])
  [memories.sample, memories.length]
end

file_path = ARGV[0] || "memories.json"
memory, n = pick_random_memory(file_path)

if memory
  puts memory["content"]
  puts "Printed 1 out of #{n}"
else
  puts "Printed 0 out of #{n}"
end
