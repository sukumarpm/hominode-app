import '../widgets/marketplace_access_gate.dart';
import 'dart:async';
// lib/src/screens/marketplace_your_products_screen.dart
// Your Products management screen

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/listing_model.dart';
import '../services/listing_firestore_service.dart';
import '../constants/app_sizes.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/marketplace_delete_listing_dialog.dart';
import '../components/marketplace_listing_card.dart';

class MarketplaceYourProductsScreen extends StatelessWidget {
  const MarketplaceYourProductsScreen({
    super.key,
    this.accessLoader,
    this.listingService,
  });
  final MarketplaceAccessLoader? accessLoader;
  final ListingFirestoreService? listingService;

  @override
  Widget build(BuildContext context) => MarketplaceAccessGate(
    loader: accessLoader,
    builder: (_) =>
        _MarketplaceYourProductsScreenContent(listingService: listingService),
  );
}

class _MarketplaceYourProductsScreenContent extends StatefulWidget {
  const _MarketplaceYourProductsScreenContent({this.listingService});
  final ListingFirestoreService? listingService;

  @override
  State<_MarketplaceYourProductsScreenContent> createState() =>
      _MarketplaceYourProductsScreenState();
}

class _MarketplaceYourProductsScreenState
    extends State<_MarketplaceYourProductsScreenContent> {
  late final ListingFirestoreService _listingService =
      widget.listingService ?? ListingFirestoreService();
  late final Stream<List<ListingModel>> _myListings = _buildMyListingsStream();
  final _deletingIds = <String>{};
  final _deletedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ListingModel>>(
      stream: _myListings,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SkeletonListLoader(itemCount: 5, itemHeight: 120);
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64.w,
                  color: Colors.red.shade300,
                ),
                SizedBox(height: 16.h),
                const Text('Error loading your products'),
              ],
            ),
          );
        }

        final listings = (snapshot.data ?? [])
            .where((listing) => !_deletedIds.contains(listing.id))
            .toList();

        if (listings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 64.w,
                  color: Colors.grey.shade300,
                ),
                SizedBox(height: 16.h),
                const Text('No products yet'),
                SizedBox(height: 8.h),
                Text(
                  'Create your first listing to get started',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            0,
            AppSizes.pagePadding,
            AppSizes.pagePadding,
          ),
          itemCount: listings.length,
          itemBuilder: (context, index) {
            final listing = listings[index];
            return MarketplaceListingCard(
              listing: listing,
              onOpen: () => _navigateToDetail(context, listing),
              onEdit: () => _editProduct(context, listing),
              onMarkSold: () => _markAsSold(listing),
              onDelete: () => _deleteProduct(listing),
            );
          },
        );
      },
    );
  }

  Stream<List<ListingModel>> _buildMyListingsStream() {
    late final StreamController<List<ListingModel>> controller;
    Timer? polling;
    var loading = false;
    Future<void> refresh() async {
      if (loading || !controller.hasListener) return;
      loading = true;
      try {
        final listings = await _listingService.getMyListings();
        if (controller.hasListener) {
          controller.add(
            listings.where((listing) => listing.status == 'active').toList(),
          );
        }
      } catch (_) {
        if (controller.hasListener) controller.add([]);
      } finally {
        loading = false;
      }
    }

    controller = StreamController<List<ListingModel>>(
      onListen: () {
        refresh();
        polling = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
      },
      onCancel: () => polling?.cancel(),
    );
    return controller.stream;
  }

  void _editProduct(BuildContext context, ListingModel listing) {
    Navigator.pushNamed(
      context,
      '/marketplace_edit_listing',
      arguments: listing,
    );
  }

  Future<void> _navigateToDetail(
    BuildContext context,
    ListingModel listing,
  ) async {
    final deleted = await Navigator.pushNamed(
      context,
      '/marketplace_your_product_detail',
      arguments: listing,
    );
    if (mounted && deleted == true) {
      setState(() => _deletedIds.add(listing.id!));
    }
  }

  Future<void> _markAsSold(ListingModel listing) async {
    if (listing.status == 'sold') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product already marked as sold')),
      );
      return;
    }

    final result = await _listingService.updateListingStatus(
      listing.id!,
      'sold',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Product marked as sold'),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteProduct(ListingModel listing) async {
    final id = listing.id!;
    if (!_deletingIds.add(id)) return;
    try {
      final deleted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MarketplaceDeleteListingDialog(
          onDelete: () => _listingService.deleteListing(id),
        ),
      );
      if (!mounted) return;
      if (deleted == true) {
        setState(() => _deletedIds.add(id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      _deletingIds.remove(id);
    }
  }
}
