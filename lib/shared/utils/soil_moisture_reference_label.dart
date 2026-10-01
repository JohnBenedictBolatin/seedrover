/// Short farmer-facing diagnosis for the calibrated moisture scale.
String soilMoistureReferenceLabel(double? value) {
  if (value == null || !value.isFinite || value < 0 || value > 100) {
    return 'Unavailable';
  }
  if (value <= 10) return 'Good for planting';
  return 'Too wet';
}
