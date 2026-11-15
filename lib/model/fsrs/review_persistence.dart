import 'package:almi3/model/db/user_db.dart';
import 'package:almi3/model/fsrs/card_mapper.dart';
import 'package:almi3/model/fsrs/grade_answer.dart';
import 'package:almi3/model/repository/user/card_fsrs_repository.dart';
import 'package:almi3/model/repository/user/fsrs_params_repository.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

/// Runs the single legal Scheduler.reviewCard call and persists the updated
/// card_fsrs row (§6.1/§14 invariant 1). Shared by every path that turns an
/// answer into a real FSRS review — scheduled reviews (§6.2) and gated
/// practice reviews (§6.3) alike.
Future<({CardFsrsTableCompanion companion, int paramsVersion})> reviewAndPersistCard({
  required fsrs.Scheduler scheduler,
  required CardFsrsRepository cardFsrsRepository,
  required FsrsParamsRepository fsrsParamsRepository,
  required CardFsrsTableData row,
  required int rating,
}) async {
  final paramsVersion = (await fsrsParamsRepository.getLatest())!.version;

  final beforeCard = cardFsrsRowToLibraryCard(row);
  final result = scheduler.reviewCard(beforeCard, fsrs.Rating.fromValue(rating));
  final afterCard = result.card;

  final wasReview = row.state == fsrs.State.review.value;
  final isLapse = wasReview && rating == ratingAgain;

  final updatedCompanion = libraryCardToCardFsrsCompanion(
    afterCard,
    cardType: row.cardType,
    id: row.id,
    reps: row.reps + 1,
    lapses: isLapse ? row.lapses + 1 : row.lapses,
    createdAt: row.createdAt,
  );
  await cardFsrsRepository.updateCard(updatedCompanion);

  return (companion: updatedCompanion, paramsVersion: paramsVersion);
}
