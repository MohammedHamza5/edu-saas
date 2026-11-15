import 'package:edu_saas/features/exams/data/models/exam_model.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_folder_entity.dart';
import 'package:edu_saas/features/exams/presentation/utils/student_exams_filter_helper.dart';
import 'package:edu_saas/features/exams/presentation/widgets/student_exams_overview_hub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Student Exams Folder Resolution & Safe Fallback Tests', () {
    test('ExamModel.fromJson parses flat folder_name and folder_color', () {
      final json = {
        'id': 'exam-1',
        'content_id': 'c-1',
        'group_id': 'g-1',
        'title': 'Test Exam',
        'folder_id': 'folder-abc',
        'folder_name': 'SAT Math 2024',
        'folder_color': '#FF5722',
      };

      final model = ExamModel.fromJson(json);

      expect(model.folderId, 'folder-abc');
      expect(model.folderName, 'SAT Math 2024');
      expect(model.folderColor, '#FF5722');
    });

    test('ExamModel.fromJson parses nested folder object properly', () {
      final json = {
        'id': 'exam-2',
        'content_id': 'c-2',
        'group_id': 'g-1',
        'title': 'Test Exam 2',
        'folder_id': 'folder-xyz',
        'folder': {
          'id': 'folder-xyz',
          'name': 'Algebra Bootcamp',
          'color': '#4CAF50',
        },
      };

      final model = ExamModel.fromJson(json);

      expect(model.folderId, 'folder-xyz');
      expect(model.folderName, 'Algebra Bootcamp');
      expect(model.folderColor, '#4CAF50');
    });

    test('StudentExamsFilterHelper resolves names from masterFolders when exams lack folderName', () {
      final exam = ExamEntity(
        id: 'exam-1',
        contentId: 'c-1',
        tenantId: 't-1',
        groupId: 'g-1',
        title: 'Exam Without Folder Name',
        folderId: 'folder-1',
        folderName: null,
        category: ExamCategory.realTest,
        durationMinutes: 60,
        maxScore: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final masterFolder = ExamFolderEntity(
        id: 'folder-1',
        tenantId: 't-1',
        name: 'Calculus 101',
        color: '#E91E63',
        examCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final summary = StudentExamsFilterHelper.computeSummary(
        rawExams: [exam],
        activeFilter: StudentExamFilter.all,
        masterFolders: [masterFolder],
      );

      expect(summary.studentFolders.length, 1);
      expect(summary.studentFolders.first.name, 'Calculus 101');
      expect(summary.studentFolders.first.color, '#E91E63');
      expect(summary.studentFolders.first.examCount, 1);
    });

    test('StudentExamsFilterHelper enriches folder name if a later exam contains it', () {
      final exam1 = ExamEntity(
        id: 'exam-1',
        contentId: 'c-1',
        tenantId: 't-1',
        groupId: 'g-1',
        title: 'First Exam (Missing folder name)',
        folderId: 'f-shared',
        folderName: null,
        category: ExamCategory.realTest,
        durationMinutes: 60,
        maxScore: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final exam2 = ExamEntity(
        id: 'exam-2',
        contentId: 'c-2',
        tenantId: 't-1',
        groupId: 'g-1',
        title: 'Second Exam (Has folder name)',
        folderId: 'f-shared',
        folderName: 'Geometry Mastery',
        folderColor: '#3F51B5',
        category: ExamCategory.realTest,
        durationMinutes: 60,
        maxScore: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final summary = StudentExamsFilterHelper.computeSummary(
        rawExams: [exam1, exam2],
        activeFilter: StudentExamFilter.all,
      );

      expect(summary.studentFolders.length, 1);
      expect(summary.studentFolders.first.name, 'Geometry Mastery');
      expect(summary.studentFolders.first.examCount, 2);
    });
  });
}
