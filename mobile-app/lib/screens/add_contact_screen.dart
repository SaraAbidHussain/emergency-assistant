import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/emergency_service.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _tabNotifier = ValueNotifier<String>('search');
  Timer? _debounce;

  bool _isLoading = false;
  bool _isAdding = false;
  List<String> _results = [];
  Set<String> _addedIds = <String>{};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadBrowseResults();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadBrowseResults() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await EmergencyService.browseUsers(excludeUserId: userId);
      if (!mounted) return;
      setState(() {
        _results = users;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load users right now.';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final mode = _tabNotifier.value;
      if (mode == 'search') {
        _searchUsers(_searchController.text);
      }
    });
  }

  Future<void> _searchUsers(String query) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return;
    }

    final trimmed = query.trim();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = trimmed.isEmpty
          ? await EmergencyService.browseUsers(excludeUserId: userId)
          : await EmergencyService.searchUsers(
              query: trimmed,
              excludeUserId: userId,
            );

      if (!mounted) return;
      setState(() {
        _results = users;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to search users right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _addContact(String contactId) async {
    final myUserId = FirebaseAuth.instance.currentUser?.uid;
    if (myUserId == null) {
      return;
    }

    setState(() {
      _isAdding = true;
      _errorMessage = null;
    });

    try {
      await EmergencyService.addContact(
        myUserId: myUserId,
        contactId: contactId,
      );

      if (!mounted) return;
      setState(() {
        _addedIds.add(contactId);
        _isAdding = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to add this contact.';
        _isAdding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Contact'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: _tabNotifier,
                builder: (context, activeTab, _) {
                  return Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Search'),
                          selected: activeTab == 'search',
                          onSelected: (_) {
                            _tabNotifier.value = 'search';
                            _searchUsers(_searchController.text);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Browse all'),
                          selected: activeTab == 'browse',
                          onSelected: (_) {
                            _tabNotifier.value = 'browse';
                            _loadBrowseResults();
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users by name or ID',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => _onSearchChanged(),
              ),
              const SizedBox(height: 12),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                )
              else
                Expanded(
                  child: _results.isEmpty
                      ? const Center(
                          child: Text('No users found.'),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final userId = _results[index];
                            final isAdded = _addedIds.contains(userId);

                            return ListTile(
                              title: Text(userId),
                              trailing: isAdded
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : TextButton(
                                      onPressed: _isAdding ? null : () => _addContact(userId),
                                      child: const Text('Add'),
                                    ),
                            );
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
