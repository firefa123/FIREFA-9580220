/// FIREFA Conflict Detail View Model
///
/// Provides local and server comparison data for owner review.
class ConflictDetailViewModel {
  final String conflictId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;

  const ConflictDetailViewModel({
    required this.conflictId,
    required this.localData,
    required this.serverData,
  });

  bool get hasDifference => localData.toString() != serverData.toString();
}
