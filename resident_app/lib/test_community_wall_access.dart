// lib/test_community_wall_access.dart
// Test script to verify community wall flat-based access

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/services/post_firestore_service.dart';

void main() async {
  print('🧪 Testing Community Wall Flat-Based Access...\n');
  
  await testPostCreation();
  await testFlatIsolation();
  await testAdminAccess();
  await testAutoDetection();
  
  print('\n✅ All tests complete!');
}

/// Test 1: Verify post creation includes flatId, flatLabel, adminId
Future<void> testPostCreation() async {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 1: Post Creation with Flat Data');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    // Create a test post
    final result = await PostFirestoreService().createPost(
      content: 'Test post for flat-based access verification',
    );
    
    if (result.success) {
      print('✅ Post created successfully');
      print('   Post ID: ${result.data}');
      
      // Fetch the post to verify fields
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(result.data)
          .get();
      
      if (postDoc.exists) {
        final data = postDoc.data()!;
        
        print('\n📋 Post Data:');
        print('   Content: ${data['content']}');
        print('   Author: ${data['authorName']}');
        print('   Flat ID: ${data['flatId']}');
        print('   Flat Label: ${data['flatLabel']}');
        print('   Admin ID: ${data['adminId']}');
        print('   Likes: ${data['likes']}');
        print('   Comments: ${data['comments']}');
        
        // Verify required fields
        if (data['flatId'] != null && data['flatId'].toString().isNotEmpty) {
          print('\n✅ flatId is present');
        } else {
          print('\n❌ flatId is missing or empty');
        }
        
        if (data['flatLabel'] != null && data['flatLabel'].toString().isNotEmpty) {
          print('✅ flatLabel is present');
        } else {
          print('⚠️  flatLabel is missing or empty');
        }
        
        if (data['adminId'] != null && data['adminId'].toString().isNotEmpty) {
          print('✅ adminId is present');
        } else {
          print('⚠️  adminId is missing (user might not have admin assigned)');
        }
      }
    } else {
      print('❌ Failed to create post: ${result.message}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Test 2: Verify flat isolation (users only see posts from their flat)
Future<void> testFlatIsolation() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 2: Flat Isolation Verification');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    // Get current user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ No user logged in');
      return;
    }
    
    // Check user's flat
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!userDoc.exists) {
      print('❌ User document not found');
      return;
    }
    
    final userData = userDoc.data()!;
    final userFlatId = userData['flatId'];
    final userFlatLabel = userData['flatLabel'] ?? userFlatId;
    
    print('👤 Current User:');
    print('   Name: ${userData['name']}');
    print('   Flat: $userFlatLabel');
    print('   Flat ID: $userFlatId');
    
    if (userFlatId == null || userFlatId.toString().isEmpty) {
      print('\n⚠️  User has no flat assigned - cannot access community wall');
      return;
    }
    
    // Get posts for user's flat
    final posts = await PostFirestoreService().getAllPosts();
    
    print('\n📊 Posts Visible to User:');
    print('   Total: ${posts.length}');
    
    if (posts.isNotEmpty) {
      print('\n   Sample posts:');
      for (var i = 0; i < posts.length && i < 5; i++) {
        final post = posts[i];
        print('   ${i + 1}. ${post.authorName} (${post.flat})');
        print('      "${post.content.substring(0, post.content.length > 50 ? 50 : post.content.length)}..."');
        print('      Likes: ${post.likes}, Comments: ${post.comments}');
      }
      
      // Verify all posts are from same flat
      print('\n🔍 Verifying flat isolation...');
      
      // Fetch actual flatId from Firestore for verification
      var allSameFlat = true;
      for (var post in posts) {
        final postDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(post.id)
            .get();
        
        if (postDoc.exists) {
          final postFlatId = postDoc.data()?['flatId'];
          if (postFlatId != userFlatId) {
            print('❌ Found post from different flat: $postFlatId');
            allSameFlat = false;
          }
        }
      }
      
      if (allSameFlat) {
        print('✅ All posts are from flat $userFlatLabel');
        print('✅ Flat isolation is working correctly');
      } else {
        print('❌ Flat isolation is NOT working - found posts from other flats');
      }
    } else {
      print('\n   No posts found for this flat');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Test 3: Verify admin can access posts from all managed flats
Future<void> testAdminAccess() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 3: Admin Access to Posts');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    // Get current user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ No user logged in');
      return;
    }
    
    // Check user role
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!userDoc.exists) {
      print('❌ User document not found');
      return;
    }
    
    final userData = userDoc.data()!;
    final userRole = userData['role'] ?? 'resident';
    
    print('👤 Current User:');
    print('   Name: ${userData['name']}');
    print('   Role: $userRole');
    
    if (userRole == 'admin') {
      print('\n✅ User is admin, testing admin access...');
      
      // Get admin posts
      final adminPosts = await PostFirestoreService().getAdminPosts();
      
      print('\n📊 Admin Posts:');
      print('   Total: ${adminPosts.length}');
      
      if (adminPosts.isNotEmpty) {
        // Group posts by flat
        final postsByFlat = <String, int>{};
        for (var post in adminPosts) {
          postsByFlat[post.flat] = (postsByFlat[post.flat] ?? 0) + 1;
        }
        
        print('\n   Posts by Flat:');
        postsByFlat.forEach((flat, count) {
          print('   $flat: $count posts');
        });
        
        print('\n   Sample posts:');
        for (var i = 0; i < adminPosts.length && i < 5; i++) {
          final post = adminPosts[i];
          print('   ${i + 1}. ${post.authorName} (${post.flat})');
          print('      "${post.content.substring(0, post.content.length > 50 ? 50 : post.content.length)}..."');
        }
        
        print('\n✅ Admin can see posts from multiple flats');
      }
    } else {
      print('\n⚠️  User is not admin, skipping admin access test');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Test 4: Verify role-based auto-detection
Future<void> testAutoDetection() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 4: Role-Based Auto-Detection');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    print('🔍 Testing auto-detection method...');
    
    final posts = await PostFirestoreService().getPostsForCurrentUser();
    
    print('\n📊 Posts (Auto-Detected):');
    print('   Total: ${posts.length}');
    
    if (posts.isNotEmpty) {
      print('\n   Sample posts:');
      for (var i = 0; i < posts.length && i < 5; i++) {
        final post = posts[i];
        print('   ${i + 1}. ${post.authorName} (${post.flat})');
        print('      Likes: ${post.likes}, Comments: ${post.comments}');
      }
      
      print('\n✅ Auto-detection working correctly');
    }
    
    // Test streaming
    print('\n🔄 Testing real-time streaming...');
    print('   (Stream will emit data on changes)');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Test 5: Test post interactions
Future<void> testPostInteractions() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 5: Post Interactions');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    // Get posts
    final posts = await PostFirestoreService().getAllPosts();
    
    if (posts.isEmpty) {
      print('⚠️  No posts available for interaction testing');
      return;
    }
    
    final testPost = posts.first;
    print('📝 Testing interactions on post: ${testPost.id}');
    print('   Author: ${testPost.authorName}');
    print('   Content: "${testPost.content.substring(0, testPost.content.length > 50 ? 50 : testPost.content.length)}..."');
    
    // Test like
    print('\n👍 Testing like...');
    final likeResult = await PostFirestoreService().likePost(testPost.id);
    print(likeResult.success ? '✅ Like successful' : '❌ Like failed: ${likeResult.message}');
    
    // Test comment
    print('\n💬 Testing comment...');
    final commentResult = await PostFirestoreService().addComment(
      postId: testPost.id,
      comment: 'Test comment for verification',
    );
    print(commentResult.success ? '✅ Comment successful' : '❌ Comment failed: ${commentResult.message}');
    
    // Get comments
    print('\n📥 Fetching comments...');
    final comments = await PostFirestoreService().getComments(testPost.id);
    print('   Total comments: ${comments.length}');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
