/// A historical portion cannot be converted without inventing its weight.
class RecordedMealConversionUnavailable extends StateError {
  RecordedMealConversionUnavailable()
    : super('The recorded meal portion conversion is unavailable');
}
