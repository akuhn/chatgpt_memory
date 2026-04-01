Small Ruby command-line tools for exploring `memories.json`.

This repo includes scripts to print a random memory, sort memories by content length, and cluster similar memories with a lightweight TF-IDF + SVD approach.

Install dependencies:

```bash
bundle install
```

Run:

```bash
ruby random_memory.rb [path]
ruby sort_memories_by_length.rb [path]
ruby cluster_similar_memories.rb [path]
```
