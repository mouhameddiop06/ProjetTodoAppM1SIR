import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/constants.dart';
import 'dart:io';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pickProfileImage(BuildContext context) async {
    try {
      // Vérifier d'abord les permissions
      final hasPermission = await _checkAndRequestPermissions();
      
      if (!hasPermission) {
        if (context.mounted) {
          _showPermissionDialog(context);
        }
        return;
      }

      // Afficher les options de sélection d'image
      final source = await _showImageSourceDialog(context);
      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (image != null && context.mounted) {
        final authProvider = context.read<AuthProvider>();
        final success = await authProvider.updateProfileImage(image.path);

        if (context.mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo de profil mise à jour avec succès'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authProvider.errorMessage ?? 'Erreur lors de la mise à jour'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Erreur lors de la sélection d\'image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    try {
      // Pour Android 13+ (API 33+), on a besoin de permissions spécifiques
      PermissionStatus photoStatus = PermissionStatus.granted;
      PermissionStatus cameraStatus = PermissionStatus.granted;

      // Vérifier la permission pour les photos
      photoStatus = await Permission.photos.status;
      if (photoStatus.isDenied) {
        photoStatus = await Permission.photos.request();
      }

      // Si photos n'est pas disponible, essayer storage
      if (photoStatus.isPermanentlyDenied || photoStatus.isDenied) {
        PermissionStatus storageStatus = await Permission.storage.status;
        if (storageStatus.isDenied) {
          storageStatus = await Permission.storage.request();
        }
        photoStatus = storageStatus;
      }

      // Vérifier la permission caméra
      cameraStatus = await Permission.camera.status;
      if (cameraStatus.isDenied) {
        cameraStatus = await Permission.camera.request();
      }

      // On a besoin d'au moins une permission (photos ou caméra)
      return (photoStatus.isGranted || photoStatus.isLimited) && 
             (cameraStatus.isGranted);
    } catch (e) {
      print('Erreur lors de la vérification des permissions: $e');
      return false;
    }
  }

  Future<ImageSource?> _showImageSourceDialog(BuildContext context) async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une photo'),
        content: const Text('D\'où souhaitez-vous sélectionner votre photo de profil ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt),
                SizedBox(width: 8),
                Text('Caméra'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library),
                SizedBox(width: 8),
                Text('Galerie'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions requises'),
        content: const Text(
          'Pour changer votre photo de profil, l\'application a besoin d\'accéder à vos photos et à votre caméra. '
          'Veuillez autoriser ces permissions dans les paramètres de votre appareil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Ouvrir paramètres'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.logout),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(AppStrings.logout),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();
    }
  }

  Future<void> _forceSync(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final todoProvider = context.read<TodoProvider>();

    if (authProvider.currentUserId != null) {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Synchronisation en cours...'),
            ],
          ),
        ),
      );

      try {
        await todoProvider.forceSync(authProvider.currentUserId!);
        
        if (context.mounted) {
          Navigator.pop(context); // Fermer le dialog de chargement
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Synchronisation forcée terminée'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Fermer le dialog de chargement
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de synchronisation: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.profile),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          children: [
            // Section profil
            _buildProfileSection(context),

            const SizedBox(height: AppSizes.paddingLarge),

            // Statistiques
            _buildStatsSection(),

            const SizedBox(height: AppSizes.paddingLarge),

            // Section état de l'app
            _buildAppStatusSection(),

            const SizedBox(height: AppSizes.paddingLarge),

            // Actions
            _buildActionsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
  return Card(
    elevation: AppSizes.elevationMedium,
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.paddingLarge),
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return Column(
            children: [
              // Photo de profil avec bouton d'édition
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: authProvider.currentUser?.profileImagePath != null
                          ? FileImage(File(authProvider.currentUser!.profileImagePath!))
                          : null,
                      child: authProvider.currentUser?.profileImagePath == null
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _pickProfileImage(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.paddingMedium),

              // Email
              Text(
                authProvider.currentUser?.email ?? 'Utilisateur',
                style: AppStyles.titleMedium,
              ),

              const SizedBox(height: AppSizes.paddingSmall),

              Text(
                'Membre depuis ${DateTime.now().year}',
                style: AppStyles.caption,
              ),

              const SizedBox(height: AppSizes.paddingMedium),

              // Instructions pour changer la photo
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingMedium),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                    SizedBox(width: AppSizes.paddingSmall),
                    Expanded(
                      child: Text(
                        'Cliquez sur l\'icône caméra pour changer votre photo de profil',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

  Widget _buildStatsSection() {
    return Card(
      elevation: AppSizes.elevationMedium,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Consumer<TodoProvider>(
          builder: (context, todoProvider, child) {
            final stats = todoProvider.getTodoStats();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistiques des tâches',
                  style: AppStyles.titleMedium,
                ),
                const SizedBox(height: AppSizes.paddingMedium),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Total',
                        stats['total']?.toString() ?? '0',
                        Icons.list_alt,
                        AppColors.primary,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Terminées',
                        stats['completed']?.toString() ?? '0',
                        Icons.check_circle,
                        AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.paddingMedium),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'En cours',
                        stats['pending']?.toString() ?? '0',
                        Icons.pending_actions,
                        AppColors.warning,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Aujourd\'hui',
                        stats['today']?.toString() ?? '0',
                        Icons.today,
                        AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      margin: const EdgeInsets.all(AppSizes.paddingSmall),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: AppSizes.iconMedium),
          const SizedBox(height: AppSizes.paddingSmall),
          Text(
            value,
            style: AppStyles.titleMedium.copyWith(color: color),
          ),
          Text(
            label,
            style: AppStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAppStatusSection() {
    return Card(
      elevation: AppSizes.elevationMedium,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'État de l\'application',
              style: AppStyles.titleMedium,
            ),

            const SizedBox(height: AppSizes.paddingMedium),

            // Connectivité
            Consumer<AppProvider>(
              builder: (context, appProvider, child) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    appProvider.isOnline ? Icons.wifi : Icons.wifi_off,
                    color: appProvider.isOnline ? AppColors.success : AppColors.error,
                  ),
                  title: Text(appProvider.connectivityStatus),
                  subtitle: Text(
                    appProvider.isOnline
                        ? 'Connexion internet active'
                        : 'Pas de connexion internet',
                  ),
                );
              },
            ),

            // Synchronisation
            Consumer<TodoProvider>(
              builder: (context, todoProvider, child) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    todoProvider.isSyncing ? Icons.sync : Icons.cloud_done,
                    color: todoProvider.isSyncing ? AppColors.warning : AppColors.success,
                  ),
                  title: Text(todoProvider.syncStatus?.statusMessage ?? 'Synchronisation'),
                  subtitle: Text(
                    todoProvider.unsyncedCount > 0
                        ? '${todoProvider.unsyncedCount} tâches en attente'
                        : 'Toutes les tâches sont synchronisées',
                  ),
                );
              },
            ),

            // Position et météo
            Consumer<AppProvider>(
              builder: (context, appProvider, child) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on, color: AppColors.primary),
                  title: Text(appProvider.locationDisplay),
                  subtitle: Text(appProvider.weatherDisplay),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Column(
      children: [
        // Forcer la synchronisation
        Card(
          elevation: AppSizes.elevationMedium,
          child: ListTile(
            leading: const Icon(Icons.sync, color: AppColors.primary),
            title: const Text('Forcer la synchronisation'),
            subtitle: const Text('Synchroniser manuellement avec le serveur'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _forceSync(context),
          ),
        ),

        const SizedBox(height: AppSizes.paddingMedium),

        // Déconnexion
        Card(
          elevation: AppSizes.elevationMedium,
          child: ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text(
              AppStrings.logout,
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Se déconnecter de l\'application'),
            trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.error),
            onTap: () => _showLogoutDialog(context),
          ),
        ),
      ],
    );
  }
}