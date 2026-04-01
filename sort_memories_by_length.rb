#!/usr/bin/env ruby
require %(json)
require %(options_by_example)


def load_memories(path)

end

options = OptionsByExample.read(DATA).parse(ARGV)
path = options.fetch(:argument, 'memories.json')
keyword = options.if_present(:keyword, &:downcase)

memories = JSON.parse(File.read path, encoding: %{UTF-8})['memories']
memories_full_length = memories.length
memories = memories.select { it['content'].downcase.include? keyword } if keyword

memories
  .sort_by { |memory| memory['content'].length }
  .each_with_index do |memory, index|
    text = memory['content'].gsub(/\s+/, " ")
    puts "#{index + 1}. [#{memory["id"]}] (#{text.length}) #{text}"
  end

puts "Printed #{memories.length} of #{memories_full_length} memories"

__END__
Sort memories by content length.

Usage: $0 [options] [path]

Options:
  -k, --keyword WORD          Keep only memories whose content includes WORD

Arguments:
  [path]                      JSON file path (default memories.json)
