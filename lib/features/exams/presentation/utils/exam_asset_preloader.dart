import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../question_bank/presentation/widgets/question_display_widgets.dart';
import '../../domain/entities/exam_entity.dart';

/// Production-grade intelligent background asset preloader for online exams.
///
/// Features:
/// 1. Prioritized concurrency queue (Worker pool with maxConcurrency parallel workers).
/// 2. Dynamically re-orders remaining downloads when the student jumps/navigates.
/// 3. Memory deduplication: Never downloads or resolves the same URL twice across the session.
/// 4. Background non-blocking execution: Warms up 100% of the exam's diagram and option assets
///    into RAM/HTTP cache while the student is solving early questions, eliminating any wait
///    times for subsequent questions.
class ExamAssetPreloader {
  /// Session-wide cache tracking to prevent duplicate network hits.
  static final Set<String> _sessionCachedUrls = <String>{};

  final int maxConcurrency;
  final List<ExamQuestionEntity> _questions = [];
  final List<String> _pendingQueue = [];
  final Set<String> _inFlightUrls = <String>{};

  BuildContext? _context;
  bool _isDisposed = false;
  int _activeWorkers = 0;

  ExamAssetPreloader({this.maxConcurrency = 3});

  /// Starts or updates the background preloading pipeline for [questions].
  /// [currentIndex] specifies where the student currently is to prioritize nearby questions.
  void startOrUpdate({
    required BuildContext context,
    required List<ExamQuestionEntity> questions,
    int currentIndex = 0,
  }) {
    if (_isDisposed) return;
    _context = context;
    _questions.clear();
    _questions.addAll(questions);

    _buildPrioritizedQueue(currentIndex);
    _drainQueue();
  }

  /// Dynamically reorganizes queue priority when the student moves to [newIndex].
  void updatePriority(int newIndex) {
    if (_isDisposed || _questions.isEmpty) return;
    _buildPrioritizedQueue(newIndex);
    _drainQueue();
  }

  /// Builds the prioritized list of pending image URLs based on student's current position.
  void _buildPrioritizedQueue(int centerIndex) {
    final total = _questions.length;
    if (total == 0) return;

    final safeCenter = centerIndex.clamp(0, total - 1);
    final orderedQuestions = <ExamQuestionEntity>[];

    // Priority 1: Current question and immediate next 3 questions (N, N+1, N+2, N+3)
    final immediateEnd = (safeCenter + 4).clamp(0, total);
    for (int i = safeCenter; i < immediateEnd; i++) {
      orderedQuestions.add(_questions[i]);
    }

    // Priority 2: All subsequent questions till the end (N+4 .. total-1)
    for (int i = immediateEnd; i < total; i++) {
      orderedQuestions.add(_questions[i]);
    }

    // Priority 3: Prior questions (safeCenter-1 down to 0) in reverse proximity
    for (int i = safeCenter - 1; i >= 0; i--) {
      orderedQuestions.add(_questions[i]);
    }

    final newQueue = <String>[];
    for (final q in orderedQuestions) {
      final urls = _extractUrlsFromQuestion(q);
      for (final url in urls) {
        if (!_sessionCachedUrls.contains(url) &&
            !_inFlightUrls.contains(url) &&
            !newQueue.contains(url)) {
          newQueue.add(url);
        }
      }
    }

    _pendingQueue.clear();
    _pendingQueue.addAll(newQueue);
  }

  List<String> _extractUrlsFromQuestion(ExamQuestionEntity q) {
    final list = <String>[];

    // Main question image or stem image
    if (q.imageUrl != null && q.imageUrl!.trim().isNotEmpty) {
      list.add(q.imageUrl!.trim());
    } else if (QuestionStemView.isImageUrl(q.questionText.trim())) {
      list.add(q.questionText.trim());
    }

    // Options images
    for (final opt in q.options) {
      if (opt.imageUrl != null && opt.imageUrl!.trim().isNotEmpty) {
        list.add(opt.imageUrl!.trim());
      }
    }

    return list;
  }

  void _drainQueue() {
    if (_isDisposed || _context == null || !(_context!.mounted)) return;

    while (_activeWorkers < maxConcurrency && _pendingQueue.isNotEmpty) {
      final nextUrl = _pendingQueue.removeAt(0);
      _inFlightUrls.add(nextUrl);
      _activeWorkers++;

      _preloadSingleAsset(nextUrl).whenComplete(() {
        _inFlightUrls.remove(nextUrl);
        _activeWorkers--;
        _drainQueue();
      });
    }
  }

  Future<void> _preloadSingleAsset(String url) async {
    if (_isDisposed || _context == null || !(_context!.mounted)) return;

    try {
      final imageProvider = NetworkImage(url);
      await precacheImage(imageProvider, _context!);
      _sessionCachedUrls.add(url);
      AppLogger.d(
        'ExamPreloader',
        '⚡ Preloaded & cached asset: ${url.split('?').first}',
      );
    } catch (e) {
      // Graceful tolerance: if a single asset times out in the background,
      // continue warming up the rest without crashing or interrupting the student.
      AppLogger.w('ExamPreloader', '⚠️ Background warmup skipped failed url: $e');
    }
  }

  /// Cancels in-flight work and releases context reference.
  void dispose() {
    _isDisposed = true;
    _pendingQueue.clear();
    _inFlightUrls.clear();
    _context = null;
  }
}
