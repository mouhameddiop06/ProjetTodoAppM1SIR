import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../utils/constants.dart';

class AddTodoScreen extends StatefulWidget {
  const AddTodoScreen({super.key});

  @override
  State<AddTodoScreen> createState() => _AddTodoScreenState();
}

class _AddTodoScreenState extends State<AddTodoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTodo() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final todoProvider = context.read<TodoProvider>();

    if (authProvider.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur: utilisateur non connecté'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await todoProvider.createTodo(
      accountId: authProvider.currentUserId!,
      title: _titleController.text.trim(),
      date: _selectedDate,
    );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tâche créée avec succès'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(todoProvider.errorMessage ?? 'Erreur lors de la création'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.addTodo),
        actions: [
          Consumer<TodoProvider>(
            builder: (context, todoProvider, child) {
              return TextButton(
                onPressed: todoProvider.isLoading ? null : _saveTodo,
                child: todoProvider.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        AppStrings.save,
                        style: TextStyle(color: Colors.white),
                      ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: AppSizes.elevationMedium,
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Nouvelle tâche',
                        style: AppStyles.titleMedium,
                      ),

                      const SizedBox(height: AppSizes.paddingLarge),

                      // Champ titre
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: AppStrings.todoTitle,
                          prefixIcon: Icon(Icons.task_alt),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppStrings.fieldRequired;
                          }
                          return null;
                        },
                        maxLines: 3,
                        minLines: 1,
                      ),

                      const SizedBox(height: AppSizes.paddingLarge),

                      // Sélecteur de date
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: const Text(AppStrings.todoDate),
                        subtitle: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: _selectDate,
                      ),

                      const Divider(),

                      const SizedBox(height: AppSizes.paddingMedium),

                      // Aperçu
                      Container(
                        padding: const EdgeInsets.all(AppSizes.paddingMedium),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppSizes.borderRadius),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aperçu:',
                              style: AppStyles.bodyMedium,
                            ),
                            const SizedBox(height: AppSizes.paddingSmall),
                            Text(
                              _titleController.text.isEmpty
                                  ? 'Titre de la tâche...'
                                  : _titleController.text,
                              style: AppStyles.bodyLarge.copyWith(
                                color: _titleController.text.isEmpty
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSizes.paddingSmall),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: AppSizes.iconSmall,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: AppSizes.paddingSmall),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: AppStyles.caption,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSizes.paddingLarge),

              // Bouton de sauvegarde
              Consumer<TodoProvider>(
                builder: (context, todoProvider, child) {
                  return SizedBox(
                    height: AppSizes.buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: todoProvider.isLoading ? null : _saveTodo,
                      icon: todoProvider.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text(AppStrings.save),
                    ),
                  );
                },
              ),

              const SizedBox(height: AppSizes.paddingMedium),

              // Bouton annuler
              SizedBox(
                height: AppSizes.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.cancel),
                  label: const Text(AppStrings.cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
