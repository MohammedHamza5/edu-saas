import 'dart:convert';
import 'package:edu_saas/core/config/tenant_resolver.dart';
import 'package:edu_saas/core/network/supabase_service.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';
import 'package:edu_saas/core/utils/secure_storage_helper.dart';
import '../../domain/entities/saved_question_entity.dart';
import 'saved_questions_demo_seed.dart';

abstract class SavedQuestionsLocalDataSource {
  Future<List<SavedQuestionEntity>> getSavedQuestions();
  Future<SavedQuestionEntity> saveQuestion(SavedQuestionEntity question);
  Future<bool> removeSavedQuestion(String questionId);
  Future<bool> isQuestionSaved(String questionId);
  Future<SavedQuestionEntity> updatePersonalNote(String questionId, String? note);
  Future<SavedQuestionEntity> updateDifficultyRating(
    String questionId,
    QuestionDifficultyRating rating, {
    bool? isMastered,
  });
  Future<SavedQuestionEntity> markMastered(String questionId, bool isMastered);
}

class SavedQuestionsLocalDataSourceImpl implements SavedQuestionsLocalDataSource {
  String _storageKey() {
    final uid = SupabaseService.client.auth.currentUser?.id ?? AppCache.currentUserId ?? 'guest';
    return 'student_vault_questions_$uid';
  }

  @override
  Future<List<SavedQuestionEntity>> getSavedQuestions() async {
    final key = _storageKey();
    final cached = AppCache.exams.get(key) as List<SavedQuestionEntity>?;
    if (cached != null) return cached;

    try {
      final raw = await SecureStorageHelper.read(key: key);
      if (raw == null || raw.isEmpty) {
        if (TenantResolver.isDemoMode()) {
          final seeds = SavedQuestionsDemoSeed.getSeedQuestions();
          AppCache.exams.put(key, seeds);
          return seeds;
        }
        AppCache.exams.put(key, <SavedQuestionEntity>[]);
        return [];
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .map((item) => SavedQuestionEntity.fromJson(item as Map<String, dynamic>))
          .toList();
      AppCache.exams.put(key, list);
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(List<SavedQuestionEntity> list) async {
    final key = _storageKey();
    AppCache.exams.put(key, list);
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await SecureStorageHelper.write(key: key, value: encoded);
  }

  @override
  Future<SavedQuestionEntity> saveQuestion(SavedQuestionEntity question) async {
    final list = await getSavedQuestions();
    final index = list.indexWhere((q) => q.questionId == question.questionId);
    if (index >= 0) {
      list[index] = question;
    } else {
      list.insert(0, question);
    }
    await _persist(list);
    return question;
  }

  @override
  Future<bool> removeSavedQuestion(String questionId) async {
    final list = await getSavedQuestions();
    final initialCount = list.length;
    list.removeWhere((q) => q.questionId == questionId);
    if (list.length != initialCount) {
      await _persist(list);
      return true;
    }
    return false;
  }

  @override
  Future<bool> isQuestionSaved(String questionId) async {
    final list = await getSavedQuestions();
    return list.any((q) => q.questionId == questionId);
  }

  @override
  Future<SavedQuestionEntity> updatePersonalNote(String questionId, String? note) async {
    final list = await getSavedQuestions();
    final index = list.indexWhere((q) => q.questionId == questionId);
    if (index < 0) throw Exception('Question not found in vault');
    final updated = list[index].copyWith(personalNote: note);
    list[index] = updated;
    await _persist(list);
    return updated;
  }

  @override
  Future<SavedQuestionEntity> updateDifficultyRating(
    String questionId,
    QuestionDifficultyRating rating, {
    bool? isMastered,
  }) async {
    final list = await getSavedQuestions();
    final index = list.indexWhere((q) => q.questionId == questionId);
    if (index < 0) throw Exception('Question not found in vault');
    final current = list[index];
    final now = DateTime.now();
    final interval = rating.intervalDays;
    final masteredValue = isMastered ?? current.isMastered;

    final updated = current.copyWith(
      difficultyRating: rating,
      reviewCount: current.reviewCount + 1,
      lastReviewedAt: now,
      intervalDays: interval,
      isMastered: masteredValue,
      nextReviewAt: masteredValue ? null : now.add(Duration(days: interval)),
      clearNextReviewAt: masteredValue,
    );
    list[index] = updated;
    await _persist(list);
    return updated;
  }

  @override
  Future<SavedQuestionEntity> markMastered(String questionId, bool isMastered) async {
    final list = await getSavedQuestions();
    final index = list.indexWhere((q) => q.questionId == questionId);
    if (index < 0) throw Exception('Question not found in vault');
    final current = list[index];
    final updated = current.copyWith(
      isMastered: isMastered,
      clearNextReviewAt: isMastered,
      nextReviewAt: isMastered ? null : (current.nextReviewAt ?? DateTime.now()),
      difficultyRating: isMastered ? QuestionDifficultyRating.easy : current.difficultyRating,
    );
    list[index] = updated;
    await _persist(list);
    return updated;
  }
}
