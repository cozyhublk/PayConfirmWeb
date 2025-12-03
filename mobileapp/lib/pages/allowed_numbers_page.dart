import 'package:flutter/material.dart';
import '../models/allowed_number.dart';
import '../services/allowed_numbers_service.dart';
import '../widgets/number_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/custom_dialog.dart';

class AllowedNumbersPage extends StatefulWidget {
  const AllowedNumbersPage({super.key});

  @override
  State<AllowedNumbersPage> createState() => _AllowedNumbersPageState();
}

class _AllowedNumbersPageState extends State<AllowedNumbersPage> {
  List<AllowedNumber> _numbers = [];
  List<AllowedNumber> _filteredNumbers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNumbers();
  }

  Future<void> _loadNumbers() async {
    setState(() => _isLoading = true);
    try {
      final numbers = await AllowedNumbersService.getAllAllowedNumbers();
      setState(() {
        _numbers = numbers;
        _filteredNumbers = numbers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading numbers: $e')),
        );
      }
    }
  }

  void _filterNumbers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredNumbers = _numbers;
      } else {
        _filteredNumbers = _numbers.where((number) {
          final nameMatch = number.name.toLowerCase().contains(query.toLowerCase());
          final phoneMatch = number.phoneNumber.contains(query);
          return nameMatch || phoneMatch;
        }).toList();
      }
    });
  }

  Future<void> _addNumber() async {
    final result = await showDialog<AllowedNumber>(
      context: context,
      builder: (context) => NumberDialog(
        onSave: (number) async {
          final success = await AllowedNumbersService.addAllowedNumber(number);
          if (success && mounted) {
            Navigator.of(context).pop(number);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Number already exists or failed to add')),
            );
          }
        },
      ),
    );

    if (result != null) {
      _loadNumbers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Number added successfully')),
        );
      }
    }
  }

  Future<void> _editNumber(AllowedNumber number) async {
    final result = await showDialog<AllowedNumber>(
      context: context,
      builder: (context) => NumberDialog(
        number: number,
        onSave: (updatedNumber) async {
          final success = await AllowedNumbersService.updateAllowedNumber(updatedNumber);
          if (success && mounted) {
            Navigator.of(context).pop(updatedNumber);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update number')),
            );
          }
        },
      ),
    );

    if (result != null) {
      _loadNumbers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Number updated successfully')),
        );
      }
    }
  }

  Future<void> _deleteNumber(AllowedNumber number) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Number'),
        content: Text('Are you sure you want to delete ${number.name}?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await AllowedNumbersService.deleteAllowedNumber(number.id);
      if (success) {
        _loadNumbers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${number.name} deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await AllowedNumbersService.addAllowedNumber(number);
                  _loadNumbers();
                },
              ),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete number')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.purple.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Allowed Numbers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: _filterNumbers,
                  decoration: InputDecoration(
                    hintText: 'Search by name or number...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _filterNumbers(''),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // List
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredNumbers.isEmpty
                          ? EmptyState(
                              icon: _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.phone_android,
                              title: _searchQuery.isNotEmpty
                                  ? 'No results found'
                                  : 'No allowed numbers',
                              message: _searchQuery.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'Add numbers to filter SMS messages',
                              action: _searchQuery.isEmpty
                                  ? ElevatedButton.icon(
                                      onPressed: _addNumber,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add First Number'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    )
                                  : null,
                            )
                          : RefreshIndicator(
                              onRefresh: _loadNumbers,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 80),
                                itemCount: _filteredNumbers.length,
                                itemBuilder: (context, index) {
                                  final number = _filteredNumbers[index];
                                  return NumberCard(
                                    number: number,
                                    onEdit: () => _editNumber(number),
                                    onDelete: () => _deleteNumber(number),
                                  );
                                },
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNumber,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Number',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

