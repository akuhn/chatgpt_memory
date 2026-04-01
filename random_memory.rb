#!/usr/bin/env ruby
require "json"

file_path = ARGV.first || "memories.json"
memories = JSON.parse(File.read(file_path, encoding: "UTF-8")).fetch("memories", [])
memory = memories.sample
n = memories.length

if memory
  puts memory["content"]
  puts "Printed 1 out of #{n}"
else
  puts "Printed 0 out of #{n}"
end
