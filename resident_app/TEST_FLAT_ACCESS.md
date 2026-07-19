# Test Flat-Based Access Control

## Quick Test Guide

### Test 1: User with Flat (Should Work)

1. **Login**
   ```
   Phone: 7010678124
   Password: 121456
   ```

2. **Expected User Data**
   ```
   Name: Preetham
   Flat: 1402
   Status: active
   ```

3. **Test Community Wall**
   - ✅ Open Community Wall
   - ✅ Should see posts from flat 1402 only
   - ✅ Try creating a new post
   - ✅ Post should be created successfully
   - ✅ New post should appear in the list

4. **Test Marketplace**
   - ✅ Open Marketplace
   - ✅ Should see listings from flat 1402 only
   - ✅ Try creating a new listing
   - ✅ Listing should be created successfully
   - ✅ New listing should appear in the list

5. **Check Console Logs**
   ```
   📥 Fetching posts for flat: 1402
   ✅ Fetched X posts for flat 1402
   
   📥 Fetching listings for flat: 1402
   ✅ Fetched X listings for flat 1402
   ```

---

### Test 2: User without Flat (Should Fail)

1. **Create Test User in Firestore**
   - Go to Firebase Console
   - Open Firestore Database
   - Go to `users` collection
   - Create new document:
     ```json
     {
       "uid": "test_no_flat",
       "name": "Test User",
       "email": "test@example.com",
       "phone": "9999999999",
       "password": "test123",
       "flatId": "",           // Empty or null
       "role": "resident",
       "status": "active"
     }
     ```

2. **Login with Test User**
   ```
   Phone: 9999999999
   Password: test123
   ```

3. **Test Community Wall**
   - ❌ Open Community Wall
   - ❌ Should see empty list (no posts)
   - ❌ Try creating a post
   - ❌ Should show error: "Cannot create post: You must be assigned to a flat"

4. **Test Marketplace**
   - ❌ Open Marketplace
   - ❌ Should see empty list (no listings)
   - ❌ Try creating a listing
   - ❌ Should show error: "Cannot create listing: You must be assigned to a flat"

5. **Check Console Logs**
   ```
   ❌ User has no flat assigned - cannot access posts
   ❌ User has no flat assigned - cannot access listings
   ```

---

### Test 3: Multiple Flats (Isolation Test)

1. **Create User in Different Flat**
   - Go to Firebase Console
   - Create user with `flatId: "1403"` (different from 1402)

2. **Create Test Data**
   - Login as user from flat 1402
   - Create 2-3 posts
   - Create 2-3 listings
   - Note the content

3. **Switch to Different Flat User**
   - Logout
   - Login as user from flat 1403
   - Open Community Wall
   - ❌ Should NOT see posts from flat 1402
   - Open Marketplace
   - ❌ Should NOT see listings from flat 1402

4. **Create Content in Flat 1403**
   - Create new post
   - Create new listing
   - ✅ Should see only flat 1403 content

5. **Verify Isolation**
   - Switch back to flat 1402 user
   - ❌ Should NOT see flat 1403 content
   - ✅ Should only see flat 1402 content

---

## Verification Checklist

### Community Wall
- [ ] Users with flat can see posts from their flat
- [ ] Users with flat can create posts
- [ ] Users without flat see empty list
- [ ] Users without flat cannot create posts
- [ ] Users from different flats don't see each other's posts

### Marketplace
- [ ] Users with flat can see listings from their flat
- [ ] Users with flat can create listings
- [ ] Users without flat see empty list
- [ ] Users without flat cannot create listings
- [ ] Users from different flats don't see each other's listings

### Error Messages
- [ ] Clear error when user has no flat
- [ ] Error message suggests contacting admin
- [ ] No crashes or exceptions

### Console Logs
- [ ] Logs show flatId being used in queries
- [ ] Logs show validation checks
- [ ] Logs show clear error messages

---

## Expected Firestore Data

### Post Document (with flatId)
```json
{
  "postId": "auto-generated",
  "authorId": "user123",
  "authorName": "Preetham",
  "flatId": "1402",           // ← Should be present
  "content": "Hello neighbors!",
  "likes": 0,
  "comments": 0,
  "createdAt": "timestamp"
}
```

### Listing Document (with flatId)
```json
{
  "listingId": "auto-generated",
  "sellerId": "user123",
  "sellerName": "Preetham",
  "flatId": "1402",           // ← Should be present
  "title": "Sofa for sale",
  "price": 5000,
  "category": "Furniture",
  "status": "active",
  "createdAt": "timestamp"
}
```

---

## Troubleshooting

### Issue: Empty lists even with flat assigned

**Check**:
1. User document has `flatId` field
2. `flatId` is not empty string
3. Posts/listings have matching `flatId`
4. Console logs show correct flatId

**Fix**:
```dart
// Check user data
final userData = await UserDataService().getCurrentUserData();
print('User flatId: ${userData?['flatId']}');

// Check posts
final posts = await PostFirestoreService().getAllPosts();
print('Posts count: ${posts.length}');
```

### Issue: Can create but cannot see content

**Check**:
1. Firestore indexes are created
2. Query is using correct field name (`flatId`)
3. Data types match (string vs number)

**Fix**:
- Go to Firebase Console
- Check Firestore indexes
- Verify field names in documents

### Issue: Error messages not showing

**Check**:
1. `UserValidationService` is imported
2. Error handling is in place
3. Context is available for SnackBar

**Fix**:
```dart
try {
  final result = await service.createPost(content: content);
  if (!result.success) {
    // Show error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Error')),
    );
  }
} catch (e) {
  print('Error: $e');
}
```

---

## Run Tests

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Run on device
flutter run -d <device-id>

# Watch console logs
# Look for:
# - "Fetching posts for flat: X"
# - "Fetched X posts for flat Y"
# - "User has no flat assigned"
```

---

**Status**: Ready for Testing
**Priority**: HIGH
**Test Duration**: 15-20 minutes
