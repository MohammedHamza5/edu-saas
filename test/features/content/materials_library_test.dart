import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/content/data/models/library_material_model.dart';
import 'package:edu_saas/features/content/data/models/material_folder_model.dart';
import 'package:edu_saas/features/content/domain/entities/library_material_entity.dart';
import 'package:edu_saas/features/content/domain/entities/material_folder_entity.dart';
import 'package:edu_saas/features/content/domain/repositories/materials_library_repository.dart';
import 'package:edu_saas/features/content/presentation/cubit/materials_library_cubit.dart';
import 'package:edu_saas/features/content/presentation/cubit/materials_library_state.dart';
import 'package:edu_saas/features/content/presentation/dialogs/select_material_from_library_dialog.dart';

class _FakeMaterialsLibraryRepository implements MaterialsLibraryRepository {
  List<MaterialFolderEntity> folders;
  List<LibraryMaterialEntity> materials;

  _FakeMaterialsLibraryRepository({
    this.folders = const [],
    this.materials = const [],
  });

  @override
  Future<Result<List<MaterialFolderEntity>>> getFolders({String? parentId}) async {
    return Success(folders.where((f) => f.parentId == parentId).toList());
  }

  @override
  Future<Result<List<MaterialFolderEntity>>> getAllFolders() async {
    return Success(folders);
  }

  @override
  Future<Result<MaterialFolderEntity>> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
  }) async {
    final newFolder = MaterialFolderEntity(
      id: 'f-new-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: 'tenant-1',
      name: name,
      parentId: parentId,
      color: color ?? '#5B4FE0',
      icon: icon ?? 'folder',
      filesCount: 0,
      totalSizeBytes: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    folders = [...folders, newFolder];
    return Success(newFolder);
  }

  @override
  Future<Result<MaterialFolderEntity>> updateFolder({
    required String id,
    required String name,
    String? color,
    String? icon,
  }) async {
    final idx = folders.indexWhere((f) => f.id == id);
    if (idx == -1) return Success(folders.first);
    final updated = MaterialFolderEntity(
      id: folders[idx].id,
      tenantId: folders[idx].tenantId,
      name: name,
      parentId: folders[idx].parentId,
      color: color ?? folders[idx].color,
      icon: icon ?? folders[idx].icon,
      filesCount: folders[idx].filesCount,
      totalSizeBytes: folders[idx].totalSizeBytes,
      createdAt: folders[idx].createdAt,
      updatedAt: DateTime.now(),
    );
    folders[idx] = updated;
    return Success(updated);
  }

  @override
  Future<Result<void>> deleteFolder(String id) async {
    folders = folders.where((f) => f.id != id).toList();
    return const Success(null);
  }

  @override
  Future<Result<List<LibraryMaterialEntity>>> getMaterials({
    String? folderId,
    String? search,
    String? mimeTypeFilter,
    int page = 0,
    int pageSize = 30,
  }) async {
    var list = materials.where((m) => m.folderId == folderId).toList();
    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      list = list.where((m) => m.title.toLowerCase().contains(q) || m.fileName.toLowerCase().contains(q)).toList();
    }
    return Success(list);
  }

  @override
  Future<Result<LibraryMaterialEntity>> getMaterialById(String id) async {
    final item = materials.firstWhere((m) => m.id == id);
    return Success(item);
  }

  @override
  Future<Result<LibraryMaterialEntity?>> checkDuplicate({
    String? fileHash,
    String? fileName,
    int? fileSize,
  }) async {
    for (final m in materials) {
      if (fileHash != null && m.fileHash == fileHash) return Success(m);
      if (fileName != null && fileSize != null && m.fileName == fileName && m.fileSize == fileSize) {
        return Success(m);
      }
    }
    return const Success(null);
  }

  @override
  Future<Result<LibraryMaterialEntity>> uploadMaterial({
    required String title,
    String? description,
    String? folderId,
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
    String? fileHash,
  }) async {
    final item = LibraryMaterialEntity(
      id: 'm-new-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: 'tenant-1',
      title: title,
      fileName: fileName,
      fileSize: fileBytes.length,
      mimeType: mimeType,
      storagePath: 'materials/tenant-1/$fileName',
      storageProvider: 'supabase',
      fileHash: fileHash,
      folderId: folderId,
      assignedLecturesCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    materials = [...materials, item];
    return Success(item);
  }

  @override
  Future<Result<LibraryMaterialEntity>> updateMaterial({
    required String id,
    required String title,
    String? description,
    String? folderId,
  }) async {
    final idx = materials.indexWhere((m) => m.id == id);
    if (idx == -1) return Success(materials.first);
    final updated = LibraryMaterialEntity(
      id: materials[idx].id,
      tenantId: materials[idx].tenantId,
      title: title,
      fileName: materials[idx].fileName,
      fileSize: materials[idx].fileSize,
      mimeType: materials[idx].mimeType,
      storagePath: materials[idx].storagePath,
      storageProvider: materials[idx].storageProvider,
      fileHash: materials[idx].fileHash,
      folderId: folderId ?? materials[idx].folderId,
      assignedLecturesCount: materials[idx].assignedLecturesCount,
      createdAt: materials[idx].createdAt,
      updatedAt: DateTime.now(),
    );
    materials[idx] = updated;
    return Success(updated);
  }

  @override
  Future<Result<LibraryMaterialEntity>> moveMaterial({
    required String id,
    String? targetFolderId,
  }) async {
    return updateMaterial(id: id, title: materials.firstWhere((m) => m.id == id).title, folderId: targetFolderId);
  }

  @override
  Future<Result<void>> deleteMaterial(String id) async {
    materials = materials.where((m) => m.id != id).toList();
    return const Success(null);
  }

  @override
  Future<Result<String>> getSignedUrl(
    String storagePath, {
    String? storageProvider,
    int expiresInSeconds = 3600,
  }) async {
    return const Success('https://storage.test.com/signed/sheet.pdf');
  }

  @override
  Future<Result<String>> linkToLecture({
    required String libraryMaterialId,
    required String contentId,
    required String tenantId,
  }) async {
    return const Success('file-linked-123');
  }
}

Widget _wrapWithLocalization(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('ar'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  final sampleFolder1 = MaterialFolderEntity(
    id: 'f-1',
    tenantId: 'tenant-1',
    name: 'Algebra Chapter 1',
    color: '#3B82F6',
    icon: 'folder',
    filesCount: 2,
    totalSizeBytes: 2048576,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleMaterial1 = LibraryMaterialEntity(
    id: 'm-1',
    tenantId: 'tenant-1',
    title: 'Algebra Handout 01',
    fileName: 'algebra_01.pdf',
    fileSize: 1048576,
    mimeType: 'application/pdf',
    storagePath: 'materials/tenant-1/algebra_01.pdf',
    storageProvider: 'supabase',
    fileHash: 'sha256-abc12345',
    assignedLecturesCount: 2,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('Materials Library Models Unit Tests', () {
    test('MaterialFolderModel converts from and to JSON cleanly', () {
      final json = {
        'id': 'f-test-1',
        'tenant_id': 'tenant-1',
        'name': 'Calculus',
        'parent_id': null,
        'color': '#5B4FE0',
        'icon': 'folder',
        'files_count': 5,
        'total_size_bytes': 10240,
        'created_at': '2026-10-13T10:00:00.000Z',
        'updated_at': '2026-10-13T10:00:00.000Z',
      };

      final model = MaterialFolderModel.fromJson(json);
      expect(model.id, 'f-test-1');
      expect(model.name, 'Calculus');
      expect(model.filesCount, 5);
      expect(model.formattedTotalSize, isNotEmpty);

      final outJson = model.toJson();
      expect(outJson['name'], 'Calculus');
      expect(outJson['tenant_id'], 'tenant-1');
    });

    test('LibraryMaterialModel correctly computes file attributes', () {
      final json = {
        'id': 'm-test-1',
        'tenant_id': 'tenant-1',
        'title': 'Trigonometry Sheet',
        'file_name': 'trig.pdf',
        'file_size': 2097152, // 2MB
        'mime_type': 'application/pdf',
        'storage_path': 'materials/tenant-1/trig.pdf',
        'storage_provider': 'supabase',
        'file_hash': 'hash-999',
        'folder_id': null,
        'assigned_lectures_count': 3,
        'created_at': '2026-10-13T10:00:00.000Z',
        'updated_at': '2026-10-13T10:00:00.000Z',
      };

      final model = LibraryMaterialModel.fromJson(json);
      expect(model.isPdf, isTrue);
      expect(model.isAssigned, isTrue);
      expect(model.formattedFileSize, contains('MB'));
    });
  });

  group('MaterialsLibraryCubit Unit Tests', () {
    test('Initial state is correct and loadFolder populates folders & materials', () async {
      final repo = _FakeMaterialsLibraryRepository(
        folders: [sampleFolder1],
        materials: [sampleMaterial1],
      );
      final cubit = MaterialsLibraryCubit(repository: repo);

      expect(cubit.state.status, MaterialsLibraryStatus.initial);

      await cubit.loadFolder();

      expect(cubit.state.status, MaterialsLibraryStatus.loaded);
      expect(cubit.state.folders.length, 1);
      expect(cubit.state.materials.length, 1);
      expect(cubit.state.currentFolder, isNull);
      expect(cubit.state.breadcrumbs.isEmpty, isTrue);

      await cubit.close();
    });

    test('Navigating into folder updates breadcrumbs and filters materials', () async {
      final subMaterial = LibraryMaterialEntity(
        id: 'm-sub-1',
        tenantId: 'tenant-1',
        title: 'Sub Chapter Worksheet',
        fileName: 'sub.pdf',
        fileSize: 512,
        mimeType: 'application/pdf',
        storagePath: 'materials/sub.pdf',
        storageProvider: 'supabase',
        folderId: 'f-1',
        assignedLecturesCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repo = _FakeMaterialsLibraryRepository(
        folders: [sampleFolder1],
        materials: [sampleMaterial1, subMaterial],
      );
      final cubit = MaterialsLibraryCubit(repository: repo);

      await cubit.loadFolder(folder: sampleFolder1);

      expect(cubit.state.currentFolder?.id, 'f-1');
      expect(cubit.state.breadcrumbs.length, 1);
      expect(cubit.state.breadcrumbs.first.id, 'f-1');
      expect(cubit.state.materials.length, 1);
      expect(cubit.state.materials.first.title, 'Sub Chapter Worksheet');

      // Navigate back to root
      await cubit.navigateToBreadcrumb(-1);
      expect(cubit.state.currentFolder, isNull);
      expect(cubit.state.breadcrumbs.isEmpty, isTrue);
      expect(cubit.state.materials.first.title, 'Algebra Handout 01');

      await cubit.close();
    });

    test('Duplicate check detects matching file hash', () async {
      final repo = _FakeMaterialsLibraryRepository(
        materials: [sampleMaterial1],
      );
      final cubit = MaterialsLibraryCubit(repository: repo);

      final duplicate = await cubit.checkDuplicate(fileHash: 'sha256-abc12345');
      expect(duplicate, isNotNull);
      expect(duplicate?.id, 'm-1');

      final notDuplicate = await cubit.checkDuplicate(fileHash: 'non-existing-hash');
      expect(notDuplicate, isNull);

      await cubit.close();
    });
  });

  group('SelectMaterialFromLibraryDialog Widget Tests', () {
    testWidgets('Renders folder, material item, and allows selection', (tester) async {
      final repo = _FakeMaterialsLibraryRepository(
        folders: [sampleFolder1],
        materials: [sampleMaterial1],
      );
      final cubit = MaterialsLibraryCubit(repository: repo);
      await cubit.loadFolder();

      LibraryMaterialEntity? chosenItem;

      await tester.pumpWidget(
        _wrapWithLocalization(
          Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    chosenItem = await showDialog<LibraryMaterialEntity>(
                      context: context,
                      builder: (_) => BlocProvider.value(
                        value: cubit,
                        child: const SelectMaterialFromLibraryDialog(),
                      ),
                    );
                  },
                  child: const Text('Open Picker'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Dialog
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Verify folder and file are rendered
      expect(find.text('Algebra Chapter 1'), findsOneWidget);
      expect(find.text('Algebra Handout 01'), findsOneWidget);

      // Tap select button on material
      final selectButton = find.text('اختيار الملف');
      expect(selectButton, findsWidgets);

      await tester.tap(selectButton.first);
      await tester.pumpAndSettle();

      expect(chosenItem, isNotNull);
      expect(chosenItem?.id, 'm-1');

      await cubit.close();
    });
  });
}
