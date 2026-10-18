class FarmerFriendlyCopy {
  const FarmerFriendlyCopy._();

  static const Map<String, String> _growthStages = {
    'seeded': 'Seeds planted',
    'seedbed': 'Seeds in nursery',
    'germinating': 'Seeds sprouting',
    'nursery seedling': 'Seedlings growing in nursery',
    'transplant review': 'Check seedlings before moving',
    'establishing': 'Settling in after moving',
    'juvenile': 'Young tree growing',
    'vegetative': 'Leaves and stems growing',
    'trellising': 'Vines growing on support',
    'flowering': 'Flowers opening',
    'pod formation': 'Pods starting to form',
    'pegging': 'Peanut stems reaching into the soil',
    'pod development': 'Pods growing',
    'maturity check': 'Check if the crop is ready to harvest',
    'first bearing': 'First fruits appearing',
    'fruiting': 'Fruits growing',
    'first harvest': 'Ready to harvest',
    'harvest ready': 'Ready to harvest',
    'repeated harvest': 'More harvests',
    'completed': 'Harvested',
    'review recorded stage': 'Check recorded growth stage',
  };

  static const Map<String, String> _careTasks = {
    'monitor establishment': 'Check that the young plants are growing well',
    'germination and nursery review': 'Check for sprouts and healthy seedlings',
    'germination': 'Check for sprouts',
    'seeds planted': 'Check for new sprouts',
    'partial planting - inspect row':
        'Some seeds may not have dropped. Check the row.',
    'monitor growth': 'Check how the plants are growing',
    'review crop condition': 'Check how the crop is growing',
    'check crop health': 'Check that the crop looks healthy',
    'water crop': 'Water the crop',
    'fertilize crop': 'Add fertilizer to the crop',
  };

  static const Map<String, String> _cropStatuses = {
    'needs attention': 'Needs care',
    'harvest ready': 'Ready to harvest',
    'cancelled': 'Ended without a harvest',
    'completed': 'Harvested',
  };

  static String _key(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static String growthStage(String value) =>
      _growthStages[_key(value)] ?? value;

  static String careTask(String value) => _careTasks[_key(value)] ?? value;

  static String cropStatus(String value) => _cropStatuses[_key(value)] ?? value;

  static String sensorLabel(String value) {
    switch (_key(value)) {
      case 'soil moisture':
      case 'soil moisture (%)':
        return 'Water in soil';
      case 'raw soil probe (adc)':
        return 'Sensor reading before setup';
      default:
        return value;
    }
  }
}
