import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/todo_item_widget.dart';
import '../profile/profile_screen.dart';
import 'add_todo_screen.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final todoProvider = context.read<TodoProvider>();
    final appProvider = context.read<AppProvider>();

    if (authProvider.currentUserId != null) {
      await todoProvider.loadTodos(authProvider.currentUserId!);
      await appProvider.updateLocation();
      await appProvider.updateWeather();
    }
  }

  Future<void> _handleRefresh() async {
    final authProvider = context.read<AuthProvider>();
    final todoProvider = context.read<TodoProvider>();
    final appProvider = context.read<AppProvider>();

    if (authProvider.currentUserId != null) {
      await Future.wait([
        todoProvider.refresh(authProvider.currentUserId!),
        appProvider.refreshAll(),
      ]);
    }
  }

  void _showAddTodoDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTodoScreen()),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  // Nouvelle méthode pour afficher la boîte de dialogue de déconnexion
  Future<void> _showLogoutDialog() async {
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

    if (shouldLogout == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();
    }
  }

  // Nouvelle méthode pour la synchronisation forcée
  Future<void> _forceSync() async {
    final authProvider = context.read<AuthProvider>();
    final todoProvider = context.read<TodoProvider>();

    if (authProvider.currentUserId != null) {
      await todoProvider.syncAllTodos(authProvider.currentUserId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synchronisation terminée'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header avec météo, profil et déconnexion
            _buildHeader(),

            // Barre de recherche
            _buildSearchBar(),

            // Statistiques
            _buildStatsRow(),

            // Onglets
            _buildTabBar(),

            // Contenu des onglets
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllTodos(),
                  _buildPendingTodos(),
                  _buildCompletedTodos(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTodoDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingLarge),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppSizes.borderRadiusLarge),
          bottomRight: Radius.circular(AppSizes.borderRadiusLarge),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Section gauche - Titre et email
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        return Text(
                          'Bonjour ${authProvider.currentUser?.email ?? 'Utilisateur'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Section droite - Actions et menu
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Météo
                    Consumer<AppProvider>(
                      builder: (context, appProvider, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.paddingSmall,
                            vertical: AppSizes.paddingSmall,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(AppSizes.borderRadius),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wb_sunny,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                appProvider.currentWeather?.temperatureDisplay ?? 'N/A',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: AppSizes.paddingSmall),

                    // Menu avec profil et déconnexion
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.menu,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'profile':
                            _navigateToProfile();
                            break;
                          case 'sync':
                            _forceSync();
                            break;
                          case 'logout':
                            _showLogoutDialog();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
  value: 'profile',
  child: Consumer<AuthProvider>(
    builder: (context, authProvider, child) {
      return Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            // CORRECTION ICI - Utilisation de FileImage au lieu de AssetImage
            backgroundImage: authProvider.currentUser?.profileImagePath != null
                ? FileImage(File(authProvider.currentUser!.profileImagePath!))
                : null,
            child: authProvider.currentUser?.profileImagePath == null
                ? const Icon(Icons.person, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 12),
          const Text('Voir le profil'),
        ],
      );
    },
  ),
),
                        const PopupMenuItem(
                          value: 'sync',
                          child: Row(
                            children: [
                              Icon(Icons.sync, color: AppColors.primary),
                              SizedBox(width: 12),
                              Text('Synchroniser'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: AppColors.error),
                              SizedBox(width: 12),
                              Text(
                                'Déconnexion',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.paddingMedium),

          // Statut de synchronisation et aide
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Statut de synchronisation
              Consumer<TodoProvider>(
                builder: (context, todoProvider, child) {
                  if (todoProvider.syncStatus != null) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingMedium,
                        vertical: AppSizes.paddingSmall,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            todoProvider.syncStatus!.statusIcon,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: AppSizes.paddingSmall),
                          Text(
                            todoProvider.syncStatus!.statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Aide utilisateur
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingMedium,
                  vertical: AppSizes.paddingSmall,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Menu pour profil et déconnexion',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: AppStrings.searchTodos,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium),
      child: Consumer<TodoProvider>(
        builder: (context, todoProvider, child) {
          final stats = todoProvider.getTodoStats();
          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  stats['total']?.toString() ?? '0',
                  Icons.list_alt,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSizes.paddingSmall),
              Expanded(
                child: _buildStatCard(
                  'En cours',
                  stats['pending']?.toString() ?? '0',
                  Icons.pending_actions,
                  AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSizes.paddingSmall),
              Expanded(
                child: _buildStatCard(
                  'Terminées',
                  stats['completed']?.toString() ?? '0',
                  Icons.check_circle,
                  AppColors.success,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingMedium),
        child: Column(
          children: [
            Icon(icon, color: color, size: AppSizes.iconMedium),
            const SizedBox(height: AppSizes.paddingSmall),
            Text(
              value,
              style: AppStyles.titleMedium.copyWith(color: color),
            ),
            Text(
              title,
              style: AppStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(AppSizes.paddingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        ),
        tabs: const [
          Tab(text: 'Toutes'),
          Tab(text: 'En cours'),
          Tab(text: 'Terminées'),
        ],
      ),
    );
  }

  Widget _buildAllTodos() {
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, child) {
        final todos = _searchController.text.isEmpty
            ? todoProvider.todos
            : todoProvider.searchTodos(_searchController.text);

        return _buildTodoList(todos);
      },
    );
  }

  Widget _buildPendingTodos() {
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, child) {
        final todos = _searchController.text.isEmpty
            ? todoProvider.pendingTodos
            : todoProvider
                .searchTodos(_searchController.text)
                .where((todo) => !todo.isDone)
                .toList();

        return _buildTodoList(todos);
      },
    );
  }

  Widget _buildCompletedTodos() {
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, child) {
        final todos = _searchController.text.isEmpty
            ? todoProvider.completedTodos
            : todoProvider
                .searchTodos(_searchController.text)
                .where((todo) => todo.isDone)
                .toList();

        return _buildTodoList(todos);
      },
    );
  }

  Widget _buildTodoList(List todos) {
    if (todos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: AppSizes.paddingMedium),
            Text(
              AppStrings.noTodos,
              style: AppStyles.bodyLarge,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSizes.paddingMedium),
        itemCount: todos.length,
        itemBuilder: (context, index) {
          return TodoItemWidget(todo: todos[index]);
        },
      ),
    );
  }
}