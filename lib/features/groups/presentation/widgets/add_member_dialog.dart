import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../students/domain/entities/student_entity.dart';
import '../../../students/domain/repositories/students_repository.dart';
import '../cubit/groups_cubit.dart';

class AddMemberDialog extends StatefulWidget {
  final String groupId;
  final Set<String>? existingMemberIds;
  final StudentsRepository? studentsRepository;

  const AddMemberDialog({
    super.key,
    required this.groupId,
    this.existingMemberIds,
    this.studentsRepository,
  });

  static Future<bool?> show(
    BuildContext context,
    String groupId, {
    Set<String>? existingMemberIds,
    StudentsRepository? studentsRepository,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocProvider.value(
        value: context.read<GroupsCubit>(),
        child: AddMemberDialog(
          groupId: groupId,
          existingMemberIds: existingMemberIds,
          studentsRepository: studentsRepository,
        ),
      ),
    );
  }

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<StudentEntity> _availableStudents = [];
  StudentEntity? _selectedStudent;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = widget.studentsRepository ?? InjectionContainer.studentsRepository;
      final result = await repo.getStudents(
        status: 'active',
        pageSize: 100,
      );

      if (!mounted) return;

      result.when(
        onSuccess: (students) {
          final existing = widget.existingMemberIds ?? {};
          final filtered = students.where((s) => !existing.contains(s.id)).toList();
          setState(() {
            _availableStudents = filtered;
            _isLoading = false;
          });
        },
        onFailure: (failure) {
          setState(() {
            _errorMessage = failure.message;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedStudent == null) return;

    setState(() => _isSubmitting = true);

    final success = await context.read<GroupsCubit>().addMember(
      groupId: widget.groupId,
      studentId: _selectedStudent!.id,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.studentAddedToGroupSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _availableStudents.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nameMatch = s.fullName.toLowerCase().contains(q);
      final emailMatch = s.email.toLowerCase().contains(q);
      final phoneMatch = s.phone != null && s.phone!.contains(q);
      return nameMatch || emailMatch || phoneMatch;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.addStudentToGroupTitle,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.selectStudentPrompt,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // ── Search Field ─────────────────────────────────────────────
              if (!_isLoading && _availableStudents.isNotEmpty) ...[
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.l10n.searchStudentsPlaceholder,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s10,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
                const SizedBox(height: AppSpacing.s16),
              ],

              // ── Main Content Area ────────────────────────────────────────
              if (_isLoading)
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        context.l10n.loadingAcademyStudents,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(context.l10n.retry),
                        onPressed: _loadStudents,
                      ),
                    ],
                  ),
                )
              else if (_availableStudents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: AppEmptyView(
                    icon: Icons.people_outline_rounded,
                    message: context.l10n.noAvailableStudentsToEnroll,
                    subtitle: context.l10n.noAvailableStudentsToEnrollDesc,
                  ),
                )
              else if (filteredList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      context.l10n.noStudentsMatchSearch,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
                    itemBuilder: (context, index) {
                      final student = filteredList[index];
                      final isSelected = _selectedStudent?.id == student.id;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedStudent = student;
                          });
                        },
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s12,
                            vertical: AppSpacing.s10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isSelected
                                    ? AppColors.primary
                                    : AppColors.primaryLight.withValues(alpha: 0.15),
                                child: Text(
                                  student.initials,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.fullName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${student.email}${student.phone != null && student.phone!.isNotEmpty ? " • ${student.phone}" : ""}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Radio<StudentEntity>(
                                value: student,
                                groupValue: _selectedStudent,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() => _selectedStudent = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: AppSpacing.s20),

              // ── Action Buttons ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(context.l10n.cancel),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  AppButton(
                    text: context.l10n.addSelectedStudentAction,
                    isLoading: _isSubmitting,
                    onPressed: _selectedStudent == null ? null : _submit,
                    icon: Icons.check_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
