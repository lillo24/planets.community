/// Per-query successful pages: 7 initially, then 15, then 20 thereafter.
/// A failed request does not advance this sequence.
int discoveryPageSize(int successfulPages) => switch (successfulPages) {
  0 => 7,
  1 => 15,
  _ => 20,
};
