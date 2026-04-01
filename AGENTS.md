Use straightforward, compact code with minimal ceremony.
Prefer practical readability over abstraction.
Avoid defining constants for readable string literals.
Prefer smalltalky enumerations over C-style index access.
Use method names that start with a verb (as per Kent Beck's best practices).

Style constraints
- Use `ary.first`, never `ary[0]`
- Use single quotes for non-interpolated strings
- Do not use `each_with_object` to create a new object
- Avoid superfluous `to_s` and `strip` calls
- Inline one-off helpers when they do not improve clarity
- Format non-local imports as `require %(name)`
- Format local imports using single quotes
- Two empty lines after all imports
