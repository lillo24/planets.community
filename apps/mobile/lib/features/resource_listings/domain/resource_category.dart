/// Provisional organization, independent of listing mode and permitted-goods policy.
enum ResourceCategory {
  toolsDiy('tools_diy'),
  gardenOutdoors('garden_outdoors'),
  homeFurniture('home_furniture'),
  electronics('electronics'),
  clothingAccessories('clothing_accessories'),
  booksLearning('books_learning'),
  sportsHobbies('sports_hobbies'),
  materials('materials'),
  other('other');

  const ResourceCategory(this.wireValue);
  final String wireValue;

  static ResourceCategory fromWire(String value) => values.firstWhere(
    (category) => category.wireValue == value,
    orElse: () => throw const FormatException('Unsupported resource category.'),
  );
}
