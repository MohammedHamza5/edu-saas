import 'package:edu_saas/features/exams/data/models/exam_folder_model.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_folder_entity.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExamFolderModel and ExamFolderEntity Tests', () {
    test('fromJson and toJson deserialize and serialize properly', () {
      final json = {
        'id': 'folder-1',
        'tenant_id': 'tenant-123',
        'name': 'Algebra Unit 1',
        'description': 'Introductory algebra exams',
        'color': '#5B4FE0',
        'icon': 'folder',
        'sort_order': 1,
        'exam_count': 5,
        'created_at': '2026-10-10T12:00:00.000Z',
        'updated_at': '2026-10-10T12:00:00.000Z',
      };

      final model = ExamFolderModel.fromJson(json);

      expect(model.id, 'folder-1');
      expect(model.name, 'Algebra Unit 1');
      expect(model.color, '#5B4FE0');
      expect(model.examCount, 5);
      expect(model.sortOrder, 1);

      final outputJson = model.toJson();
      expect(outputJson['name'], 'Algebra Unit 1');
      expect(outputJson['color'], '#5B4FE0');
      expect(outputJson['sort_order'], 1);
    });

    test('copyWith updates properties correctly', () {
      final folder = ExamFolderEntity(
        id: 'folder-1',
        tenantId: 'tenant-1',
        name: 'Unit 1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = folder.copyWith(name: 'Unit 1: Advanced', examCount: 3);
      expect(updated.name, 'Unit 1: Advanced');
      expect(updated.examCount, 3);
      expect(updated.id, folder.id);
    });
  });

  group('TeacherExamsLoaded Folders Filtering Logic', () {
    final now = DateTime.now();

    final examInFolder1 = ExamEntity(
      id: 'exam-1',
      contentId: 'content-1',
      tenantId: 'tenant-1',
      groupId: 'group-1',
      title: 'Exam 1 (In Folder 1)',
      maxScore: 100,
      questionsCount: 10,
      createdAt: now,
      updatedAt: now,
      folderId: 'folder-1',
      folderName: 'Unit 1',
    );

    final examInFolder2 = ExamEntity(
      id: 'exam-2',
      contentId: 'content-2',
      tenantId: 'tenant-1',
      groupId: 'group-1',
      title: 'Exam 2 (In Folder 2)',
      maxScore: 50,
      questionsCount: 5,
      createdAt: now,
      updatedAt: now,
      folderId: 'folder-2',
      folderName: 'Unit 2',
    );

    final uncategorizedExam = ExamEntity(
      id: 'exam-3',
      contentId: 'content-3',
      tenantId: 'tenant-1',
      groupId: 'group-1',
      title: 'Exam 3 (No Folder)',
      maxScore: 20,
      questionsCount: 2,
      createdAt: now,
      updatedAt: now,
      folderId: null,
      folderName: null,
    );

    final List<ExamEntity> allExams = [
      examInFolder1,
      examInFolder2,
      uncategorizedExam,
    ];

    final folders = [
      ExamFolderEntity(
        id: 'folder-1',
        tenantId: 'tenant-1',
        name: 'Unit 1',
        examCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      ExamFolderEntity(
        id: 'folder-2',
        tenantId: 'tenant-1',
        name: 'Unit 2',
        examCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    test('selectedFolderId == null returns all exams', () {
      final state = TeacherExamsLoaded(
        exams: allExams,
        folders: folders,
        selectedFolderId: null,
      );

      expect(state.filteredExams.length, 3);
      expect(state.filteredExams, containsAll(allExams));
    });

    test('selectedFolderId == "uncategorized" filters to exams with null folderId', () {
      final state = TeacherExamsLoaded(
        exams: allExams,
        folders: folders,
        selectedFolderId: 'uncategorized',
      );

      expect(state.filteredExams.length, 1);
      expect(state.filteredExams.first.id, 'exam-3');
      expect(state.filteredExams.first.folderId, isNull);
    });

    test('selectedFolderId == specific UUID filters to exams in that folder', () {
      final state = TeacherExamsLoaded(
        exams: allExams,
        folders: folders,
        selectedFolderId: 'folder-1',
      );

      expect(state.filteredExams.length, 1);
      expect(state.filteredExams.first.id, 'exam-1');
      expect(state.filteredExams.first.folderId, 'folder-1');
    });

    test('copyWith clearSelectedFolder resets selectedFolderId to null', () {
      final state = TeacherExamsLoaded(
        exams: allExams,
        folders: folders,
        selectedFolderId: 'folder-1',
      );

      final resetState = state.copyWith(clearSelectedFolder: true);
      expect(resetState.selectedFolderId, isNull);
      expect(resetState.filteredExams.length, 3);
    });
  });

  group('StudentExamsLoaded Folders Filtering Logic', () {
    final now = DateTime.now();

    final examInFolder1 = ExamEntity(
      id: 'exam-1',
      contentId: 'content-1',
      tenantId: 'tenant-1',
      groupId: 'group-1',
      title: 'Exam 1 (In Folder 1)',
      maxScore: 100,
      questionsCount: 10,
      createdAt: now,
      updatedAt: now,
      folderId: 'folder-1',
      folderName: 'Unit 1',
    );

    final examInFolder2 = ExamEntity(
      id: 'exam-2',
      contentId: 'content-2',
      tenantId: 'tenant-1',
      groupId: 'group-1',
      title: 'Exam 2 (In Folder 2)',
      maxScore: 50,
      questionsCount: 5,
      createdAt: now,
      updatedAt: now,
      folderId: 'folder-2',
      folderName: 'Unit 2',
    );

    final uncategorizedExam = ExamEntity(
      id: 'exam-3',
      contentId: 'content-3',
      tenantId: 'tenant-1',
      groupId: 'group-1',
      title: 'Exam 3 (No Folder)',
      maxScore: 20,
      questionsCount: 2,
      createdAt: now,
      updatedAt: now,
      folderId: null,
      folderName: null,
    );

    final List<ExamEntity> allExams = [
      examInFolder1,
      examInFolder2,
      uncategorizedExam,
    ];

    final folders = [
      ExamFolderEntity(
        id: 'folder-1',
        tenantId: 'tenant-1',
        groupId: 'group-1',
        name: 'Unit 1',
        examCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      ExamFolderEntity(
        id: 'folder-2',
        tenantId: 'tenant-1',
        groupId: 'group-1',
        name: 'Unit 2',
        examCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    test('StudentExamsLoaded selectedFolderId == null returns all exams', () {
      final state = StudentExamsLoaded(
        exams: allExams,
        folders: folders,
        selectedFolderId: null,
      );

      expect(state.filteredExams.length, 3);
      expect(state.filteredExams, containsAll(allExams));
    });

    test('StudentExamsLoaded selectedFolderId == "uncategorized" returns exams without folder', () {
      final state = StudentExamsLoaded(
        exams: allExams,
        folders: folders,
        selectedFolderId: 'uncategorized',
      );

      expect(state.filteredExams.length, 1);
      expect(state.filteredExams.first.id, 'exam-3');
    });

    test('StudentExamsLoaded selectedFolderId == specific UUID filters to that folder', () {
      final state = StudentExamsLoaded(
        exams: allExams,
        folders: folders,
        selectedFolderId: 'folder-2',
      );

      expect(state.filteredExams.length, 1);
      expect(state.filteredExams.first.id, 'exam-2');
      expect(state.filteredExams.first.folderId, 'folder-2');
    });

    test('StudentExamsLoaded copyWith clearSelectedFolder resets filter', () {
      final state = StudentExamsLoaded(
        exams: allExams,
        folders: folders,
        selectedFolderId: 'folder-1',
      );

      final resetState = state.copyWith(clearSelectedFolder: true);
      expect(resetState.selectedFolderId, isNull);
      expect(resetState.filteredExams.length, 3);
    });
  });
}
