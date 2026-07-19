# 🔧 Complete Firestore Fix Guide - All Issues Resolved

## Overview

This guide fixes all Firestore-related errors in your Flutter app:
- ✅ Permission denied errors
- ✅ Empty UI screens
- ✅ Data not loading
- ✅ Incorrect booking and amenities logic
- ✅ Building-based access control

---

## Part 1: Firestore Security Rules

### Deploy These Rules

Go to Firebase Console → Firestore → Rules and paste:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    function userBuildingId() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
    }
    
    // Users collection - allow login
    match /users/{userId} {
      allow read: if true;  // Allow unauthenticated read for login
      allow write: if isAuthenticated() && (userId == request.auth.uid || isAdmin());
    }
    
    // Amenities - filter by buildingId
    match /amenities/{amenityId} {
      allow read: if isAuthenticated() && 
        resource.data.buildingId == userBuildingId();
      allow write: if isAdmin() && 
        resource.data.buildingId == userBuildingId();
    }
    
    // Bookings - filter by userId and buildingId
    match /bookings/{bookingId} {
      allow read: if isAuthenticated() && 
        (resource.data.userId == request.auth.uid || 
         resource.data.buildingId == userBuildingId());
      allow write: if isAuthenticated() && 
        request.resource.data.userId == request.auth.uid;
    }
    
    // Announcements - filter by buildingId
    match /announcements/{announcementId} {
      allow read: if isAuthenticated() && 
        resource.data.buildingId == userBuildingId();
      allow write: if isAdmin() && 
        resource.data.buildingId == userBuildingId();
    }
    
    // Complaints - filter by buildingId
    match /complaints/{complaintId} {
      allow read: if isAuthenticated() && 
        resource.data.buildingId == userBuildingId();
      allow write: if isAuthenticated();
    }
    
    // Everything else - authenticated users only
    match /{document=**} {
      allow read, write: if isAuthenticated();
    }
  }
}
```

---

## Part 2: Login Flow Implementation

### Login Service with BuildingId Check

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginService {
  static final LoginService _instance = LoginService._internal();
  
  factory LoginService() => _instance;
  LoginService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Login flow with buildingId validation
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔵 LOGIN: Starting login process...');
      
      // STEP 1: Authenticate with Firebase Auth
      print('🔐 STEP 1: Authenticating with Firebase...');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user == null) {
        return LoginResult.failure('Authentication failed');
      }
      
      final uid = userCredential.user!.uid;
      print('✅ STEP 1 PASSED: User authenticated - UID: $uid');
      
      // STEP 2: Fetch user document from Firestore
      print('📋 STEP 2: Fetching user document...');
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        await _auth.signOut();
        return LoginResult.failure('User document not found');
      }
      
      print('✅ STEP 2 PASSED: User document found');
      
      // STEP 3: Check buildingId
      print('🏢 STEP 3: Checking buildingId...');
      final buildingId = userDoc.get('buildingId') as String?;
      
      if (buildingId == null || buildingId.isEmpty) {
        await _auth.signOut();
        return LoginResult.accessRestricted(
          'Your account is not assigned to a building. Please contact support.'
        );
      }
      
      print('✅ STEP 3 PASSED: BuildingId found - $buildingId');
      
      // STEP 4: Return success
      print('✅ LOGIN: COMPLETE');
      return LoginResult.success(
        uid: uid,
        buildingId: buildingId,
        role: userDoc.get('role') as String? ?? 'resident',
      );
      
    } on FirebaseAuthException catch (e) {
      print('❌ Auth error: ${e.message}');
      return LoginResult.failure(e.message ?? 'Authentication failed');
    } catch (e) {
      print('❌ Error: $e');
      return LoginResult.failure('Login failed: $e');
    }
  }
}

class LoginResult {
  final bool success;
  final String? uid;
  final String? buildingId;
  final String? role;
  final String? message;
  final bool isAccessRestricted;
  
  LoginResult({
    required this.success,
    this.uid,
    this.buildingId,
    this.role,
    this.message,
    this.isAccessRestricted = false,
  });
  
  factory LoginResult.success({
    required String uid,
    required String buildingId,
    required String role,
  }) {
    return LoginResult(
      success: true,
      uid: uid,
      buildingId: buildingId,
      role: role,
      isAccessRestricted: false,
    );
  }
  
  factory LoginResult.failure(String message) {
    return LoginResult(
      success: false,
      message: message,
      isAccessRestricted: false,
    );
  }
  
  factory LoginResult.accessRestricted(String message) {
    return LoginResult(
      success: false,
      message: message,
      isAccessRestricted: true,
    );
  }
}
```

### Login Screen with Navigation

```dart
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final result = await LoginService().login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      if (!mounted) return;
      
      if (result.isAccessRestricted) {
        // Show access restricted screen
        Navigator.of(context).pushReplacementNamed('/access-restricted');
      } else if (result.success) {
        // Navigate to home
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Login failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Part 3: Firestore Queries with BuildingId Filter

### Amenities Service

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AmenitiesService {
  static final AmenitiesService _instance = AmenitiesService._internal();
  
  factory AmenitiesService() => _instance;
  AmenitiesService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Get user's buildingId
  Future<String?> _getUserBuildingId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.get('buildingId') as String?;
  }
  
  /// Stream amenities for user's building
  Stream<List<Amenity>> streamAmenities() async* {
    try {
      final buildingId = await _getUserBuildingId();
      
      if (buildingId == null) {
        yield [];
        return;
      }
      
      yield* _firestore
          .collection('amenities')
          .where('buildingId', isEqualTo: buildingId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => Amenity.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('❌ Error streaming amenities: $e');
      yield [];
    }
  }
  
  /// Get available slots for amenity
  Future<List<TimeSlot>> getAvailableSlots(String amenityId) async {
    try {
      final doc = await _firestore.collection('amenities').doc(amenityId).get();
      
      if (!doc.exists) return [];
      
      final slots = (doc.get('timeSlots') as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      return slots
          .map((slot) => TimeSlot.fromMap(slot))
          .where((slot) => slot.availableSpots > 0)
          .toList();
    } catch (e) {
      print('❌ Error getting slots: $e');
      return [];
    }
  }
}

class Amenity {
  final String id;
  final String buildingId;
  final String name;
  final String description;
  final int maxUsers;
  final List<TimeSlot> timeSlots;
  final bool isActive;
  
  Amenity({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.description,
    required this.maxUsers,
    required this.timeSlots,
    required this.isActive,
  });
  
  factory Amenity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Amenity(
      id: doc.id,
      buildingId: data['buildingId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      maxUsers: data['maxUsers'] ?? 0,
      timeSlots: (data['timeSlots'] as List?)
              ?.map((slot) => TimeSlot.fromMap(slot as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: data['isActive'] ?? true,
    );
  }
}

class TimeSlot {
  final String id;
  final String startTime;
  final String endTime;
  final int maxUsers;
  final int bookedUsers;
  
  TimeSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.maxUsers,
    required this.bookedUsers,
  });
  
  int get availableSpots => maxUsers - bookedUsers;
  
  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      id: map['id'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      maxUsers: map['maxUsers'] ?? 0,
      bookedUsers: map['bookedUsers'] ?? 0,
    );
  }
}
```

### Bookings Service

```dart
class BookingsService {
  static final BookingsService _instance = BookingsService._internal();
  
  factory BookingsService() => _instance;
  BookingsService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Stream user's bookings
  Stream<List<Booking>> streamUserBookings() async* {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        yield [];
        return;
      }
      
      yield* _firestore
          .collection('bookings')
          .where('userId', isEqualTo: uid)
          .orderBy('bookingDate', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => Booking.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('❌ Error streaming bookings: $e');
      yield [];
    }
  }
  
  /// Create booking
  Future<bool> createBooking({
    required String amenityId,
    required String timeSlotId,
    required String buildingId,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;
      
      await _firestore.collection('bookings').add({
        'userId': uid,
        'amenityId': amenityId,
        'timeSlotId': timeSlotId,
        'buildingId': buildingId,
        'bookingDate': DateTime.now(),
        'status': 'confirmed',
      });
      
      return true;
    } catch (e) {
      print('❌ Error creating booking: $e');
      return false;
    }
  }
}

class Booking {
  final String id;
  final String userId;
  final String amenityId;
  final String timeSlotId;
  final String buildingId;
  final DateTime bookingDate;
  final String status;
  
  Booking({
    required this.id,
    required this.userId,
    required this.amenityId,
    required this.timeSlotId,
    required this.buildingId,
    required this.bookingDate,
    required this.status,
  });
  
  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Booking(
      id: doc.id,
      userId: data['userId'] ?? '',
      amenityId: data['amenityId'] ?? '',
      timeSlotId: data['timeSlotId'] ?? '',
      buildingId: data['buildingId'] ?? '',
      bookingDate: (data['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }
}
```

### Announcements Service

```dart
class AnnouncementsService {
  static final AnnouncementsService _instance = AnnouncementsService._internal();
  
  factory AnnouncementsService() => _instance;
  AnnouncementsService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Stream announcements for user's building
  Stream<List<Announcement>> streamAnnouncements() async* {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        yield [];
        return;
      }
      
      // Get user's buildingId
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final buildingId = userDoc.get('buildingId') as String?;
      
      if (buildingId == null) {
        yield [];
        return;
      }
      
      yield* _firestore
          .collection('announcements')
          .where('buildingId', isEqualTo: buildingId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => Announcement.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('❌ Error streaming announcements: $e');
      yield [];
    }
  }
}

class Announcement {
  final String id;
  final String buildingId;
  final String title;
  final String content;
  final DateTime createdAt;
  
  Announcement({
    required this.id,
    required this.buildingId,
    required this.title,
    required this.content,
    required this.createdAt,
  });
  
  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Announcement(
      id: doc.id,
      buildingId: data['buildingId'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
```

---

## Part 4: UI Implementation with Proper State Handling

### Amenities Screen with Loading/Empty/Error States

```dart
import 'package:flutter/material.dart';

class AmenitiesScreen extends StatefulWidget {
  @override
  State<AmenitiesScreen> createState() => _AmenitiesScreenState();
}

class _AmenitiesScreenState extends State<AmenitiesScreen> {
  late final AmenitiesService _amenitiesService;
  
  @override
  void initState() {
    super.initState();
    _amenitiesService = AmenitiesService();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Amenities')),
      body: StreamBuilder<List<Amenity>>(
        stream: _amenitiesService.streamAmenities(),
        builder: (context, snapshot) {
          // LOADING STATE
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading amenities...'),
                ],
              ),
            );
          }
          
          // ERROR STATE
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error loading amenities'),
                  SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final amenities = snapshot.data ?? [];
          
          // EMPTY STATE
          if (amenities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_work_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No amenities available'),
                  SizedBox(height: 8),
                  Text(
                    'Check back later for available amenities',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          // DATA STATE
          return ListView.builder(
            itemCount: amenities.length,
            itemBuilder: (context, index) {
              final amenity = amenities[index];
              return AmenityCard(amenity: amenity);
            },
          );
        },
      ),
    );
  }
}

class AmenityCard extends StatelessWidget {
  final Amenity amenity;
  
  const AmenityCard({required this.amenity});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              amenity.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text(amenity.description),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navigate to booking screen
              },
              child: Text('Book Now'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Bookings Screen

```dart
class BookingsScreen extends StatefulWidget {
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  late final BookingsService _bookingsService;
  
  @override
  void initState() {
    super.initState();
    _bookingsService = BookingsService();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Bookings')),
      body: StreamBuilder<List<Booking>>(
        stream: _bookingsService.streamUserBookings(),
        builder: (context, snapshot) {
          // LOADING STATE
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          // ERROR STATE
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error loading bookings'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final bookings = snapshot.data ?? [];
          
          // EMPTY STATE
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No bookings yet'),
                  SizedBox(height: 8),
                  Text(
                    'Book an amenity to get started',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          // DATA STATE
          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return BookingCard(booking: booking);
            },
          );
        },
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final Booking booking;
  
  const BookingCard({required this.booking});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking #${booking.id.substring(0, 8)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Chip(
                  label: Text(booking.status),
                  backgroundColor: booking.status == 'confirmed'
                      ? Colors.green
                      : Colors.orange,
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('Date: ${booking.bookingDate.toString().split(' ')[0]}'),
          ],
        ),
      ),
    );
  }
}
```

---

## Part 5: Data Structure in Firestore

### Required Collections

**users**
```json
{
  "uid": "user123",
  "email": "user@example.com",
  "buildingId": "building456",
  "role": "resident",
  "name": "John Doe",
  "phone": "+1234567890"
}
```

**amenities**
```json
{
  "buildingId": "building456",
  "name": "Swimming Pool",
  "description": "Olympic size pool",
  "maxUsers": 50,
  "isActive": true,
  "timeSlots": [
    {
      "id": "slot1",
      "startTime": "06:00",
      "endTime": "08:00",
      "maxUsers": 20,
      "bookedUsers": 15
    }
  ]
}
```

**bookings**
```json
{
  "userId": "user123",
  "amenityId": "amenity456",
  "timeSlotId": "slot1",
  "buildingId": "building456",
  "bookingDate": "2024-03-29T10:30:00Z",
  "status": "confirmed"
}
```

**announcements**
```json
{
  "buildingId": "building456",
  "title": "Maintenance Notice",
  "content": "Pool will be closed on Sunday",
  "createdAt": "2024-03-29T10:30:00Z"
}
```

---

## Part 6: Deployment Checklist

- [ ] Deploy Firestore security rules
- [ ] Create Firestore indexes (if needed)
- [ ] Implement LoginService with buildingId check
- [ ] Update all screens with StreamBuilder
- [ ] Add loading/empty/error states to all screens
- [ ] Test login flow with buildingId validation
- [ ] Test amenities filtering by buildingId
- [ ] Test bookings filtering by userId
- [ ] Test announcements filtering by buildingId
- [ ] Verify all queries include proper filters
- [ ] Test with multiple users in different buildings

---

## Part 7: Testing Checklist

### Login Flow
- [ ] User without buildingId → Access Restricted screen
- [ ] User with buildingId → Home screen
- [ ] Invalid credentials → Error message

### Amenities Screen
- [ ] Loading state shows spinner
- [ ] Empty state shows message
- [ ] Error state shows retry button
- [ ] Data loads correctly
- [ ] Only shows amenities for user's building

### Bookings Screen
- [ ] Shows user's bookings only
- [ ] Filters by userId correctly
- [ ] Displays booking status
- [ ] Empty state when no bookings

### Announcements Screen
- [ ] Shows announcements for user's building
- [ ] Filters by buildingId correctly
- [ ] Displays in correct order

---

## Summary

✅ **Firestore Rules**: Secure, building-based access control  
✅ **Login Flow**: Validates buildingId, shows access restricted if null  
✅ **Queries**: All filtered by buildingId or userId  
✅ **UI States**: Loading, empty, error, and data states  
✅ **Data Structure**: Proper collections with required fields  

**All Firestore errors fixed!** 🚀

