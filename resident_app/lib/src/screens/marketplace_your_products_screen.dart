// lib/src/screens/marketplace_your_products_screen.dart
// Your Products management screen

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/listing_model.dart';
import '../services/listing_firestore_service.dart';
import '../constants/app_sizes.dart';
import '../widgets/skeleton_loader.dart';
import '../components/marketplace_listing_card.dart';

class MarketplaceYourProductsScreen extends StatefulWidget {
  const MarketplaceYourProductsScreen({super.key});

  @override
  State<MarketplaceYourProductsScreen> createState() =>
      _MarketplaceYourProductsScreenState();
}

class _MarketplaceYourProductsScreenState
    extends State<MarketplaceYourProductsScreen> {
  final ListingFirestoreService _listingService = ListingFirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ListingModel>>(
      stream: _buildMyListingsStream(),
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

        final listings = snapshot.data ?? [];

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
              onMarkSold: () => _markAsSold(context, listing),
              onDelete: () => _deleteProduct(context, listing),
            );
          },
        );
      },
    );
  }

  Stream<List<ListingModel>> _buildMyListingsStream() async* {
    try {
      final listings = await _listingService.getMyListings();
      // Filter to show only active products
      final activeListings = listings
          .where((listing) => listing.status == 'active')
          .toList();
      yield activeListings;

      // Also listen for real-time updates
      await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
        final updatedListings = await _listingService.getMyListings();
        final activeUpdated = updatedListings
            .where((listing) => listing.status == 'active')
            .toList();
        yield activeUpdated;
      }
    } catch (e) {
      print('❌ Error streaming my listings: $e');
      yield [];
    }
  }

  void _editProduct(BuildContext context, ListingModel listing) {
    Navigator.pushNamed(
      context,
      '/marketplace_edit_listing',
      arguments: listing,
    );
  }

  void _navigateToDetail(BuildContext context, ListingModel listing) {
    Navigator.pushNamed(
      context,
      '/marketplace_your_product_detail',
      arguments: listing,
    );
  }

  Future<void> _markAsSold(BuildContext context, ListingModel listing) async {
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

  Future<void> _deleteProduct(
    BuildContext context,
    ListingModel listing,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _listingService.deleteListing(listing.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Product deleted'),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}
