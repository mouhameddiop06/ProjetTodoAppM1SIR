import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/todo_model.dart';
import '../providers/todo_provider.dart';
import '../utils/constants.dart';

class TodoItemWidget extends StatelessWidget {
  final Todo todo;

  const TodoItemWidget({
    super.key,
    required this.todo,
  });

  Future<void> _toggleTodo(BuildContext context) async {
    final todoProvider = context.read<TodoProvider>();
    await todoProvider.toggleTodoCompletion(todo);
  }

  Future<void> _deleteTodo(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteTodo),
        content: Text('Êtes-vous sûr de vouloir supprimer "${todo.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      final todoProvider = context.read<TodoProvider>();
      final success = await todoProvider.deleteTodo(todo);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tâche supprimée'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Color _getStatusColor() {
    if (todo.isDone) {
      return AppColors.success;
    } else if (todo.isPast) {
      return AppColors.error;
    } else if (todo.isToday) {
      return AppColors.warning;
    } else {
      return AppColors.primary;
    }
  }

  IconData _getStatusIcon() {
    if (todo.isDone) {
      return Icons.check_circle;
    } else if (todo.isPast) {
      return Icons.schedule;
    } else if (todo.isToday) {
      return Icons.today;
    } else {
      return Icons.radio_button_unchecked;
    }
  }

  String _getDateText() {
    if (todo.isToday) {
      return "Aujourd'hui";
    } else if (todo.isPast) {
      return "En retard";
    } else if (todo.isFuture) {
      final difference = todo.date.difference(DateTime.now()).inDays;
      if (difference == 1) {
        return "Demain";
      } else {
        return "Dans $difference jours";
      }
    } else {
      return todo.formattedDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingMedium),
      elevation: todo.isDone ? AppSizes.elevationLow : AppSizes.elevationMedium,
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSizes.paddingMedium),
        leading: GestureDetector(
          onTap: () => _toggleTodo(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              border: Border.all(
                color: _getStatusColor(),
                width: 2,
              ),
            ),
            child: Icon(
              _getStatusIcon(),
              color: _getStatusColor(),
              size: AppSizes.iconMedium,
            ),
          ),
        ),
        title: Text(
          todo.title,
          style: AppStyles.bodyLarge.copyWith(
            decoration: todo.isDone ? TextDecoration.lineThrough : null,
            color:
                todo.isDone ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSizes.paddingSmall),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: AppSizes.iconSmall,
                  color: _getStatusColor(),
                ),
                const SizedBox(width: AppSizes.paddingSmall),
                Text(
                  _getDateText(),
                  style: AppStyles.caption.copyWith(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!todo.isSynced)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingSmall,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius:
                          BorderRadius.circular(AppSizes.borderRadiusSmall),
                    ),
                    child: const Text(
                      'Non synchronisé',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'toggle':
                _toggleTodo(context);
                break;
              case 'delete':
                _deleteTodo(context);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    todo.isDone ? Icons.undo : Icons.check,
                    size: AppSizes.iconSmall,
                  ),
                  const SizedBox(width: AppSizes.paddingSmall),
                  Text(todo.isDone
                      ? AppStrings.markAsUndone
                      : AppStrings.markAsDone),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete,
                    size: AppSizes.iconSmall,
                    color: AppColors.error,
                  ),
                  SizedBox(width: AppSizes.paddingSmall),
                  Text(
                    AppStrings.delete,
                    style: TextStyle(color: AppColors.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
