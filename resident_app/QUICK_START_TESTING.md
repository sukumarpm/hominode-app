# Quick Start Testing Guide

**Status**: ✅ Ready to Test  
**Build**: ✅ No Errors  
**Date**: March 13, 2026

---

## How to Run

```bash
cd resident_app
flutter run -d <device_id>
```

---

## Test Marketplace Phone Requests

### Scenario 1: Request Phone Number
1. Login as Buyer (Building A)
2. Go to Marketplace
3. Find a product from another seller in same building
4. Tap "Request Phone Number"
5. **Expected**: Request sent successfully

### Scenario 2: Seller Accepts Request
1. Login as Seller
2. Go to "Your Products"
3. Tap on a product
4. See "Phone Requests" section
5. Tap "Accept" on a request
6. **Expected**: Request status changes to "Accepted"

### Scenario 3: Buyer Sees Seller Phone
1. Login as Buyer
2. Go to Marketplace
3. Find the product where you requested phone
4. Tap on product
5. Scroll to "Seller Contact" section
6. **Expected**: See seller's phone number (not your phone)

### Scenario 4: Cross-Building Prevention
1. Login as Buyer (Building A)
2. Try to request phone from product in Building B
3. **Expected**: Error message "You must be a member of this building"

---

## Test Content Moderation

### Scenario 1: Block Post with Banned Keyword
1. Go to Community Wall
2. Try to post: "I have a gun for sale"
3. **Expected**: 
   - Warning dialog appears
   - Title: "Content Not Allowed"
   - Message about banned keywords
   - Post NOT saved to Firestore

### Scenario 2: Block Comment with Banned Keyword
1. Go to Community Wall
2. Open a post
3. Try to comment: "This is a scam"
4. **Expected**:
   - Warning dialog appears
   - Comment NOT saved to Firestore

### Scenario 3: Block Listing with Banned Keyword
1. Go to Marketplace
2. Tap "Create Listing"
3. Title: "Fake ID"
4. Description: "Counterfeit documents"
5. Tap "Create"
6. **Expected**:
   - Warning dialog appears
   - Listing NOT saved to Firestore

### Scenario 4: Allow Safe Content
1. Go to Community Wall
2. Post: "Looking for a roommate"
3. **Expected**: Post saved successfully, no warning

### Scenario 5: Case-Insensitive Matching
1. Go to Community Wall
2. Try to post: "I HAVE A GUN"
3. **Expected**: Still blocked (case-insensitive)

---

## Console Logs to Check

### Marketplace Phone Requests
```
✅ Phone request created in subcollection from building member
✅ Phone request accepted
✅ Fetched seller phone number for buyer
```

### Content Moderation
```
❌ Banned keyword detected: gun
⛔ Post blocked by moderation: Your post contains banned keywords...
✅ Text content is safe
```

---

## Expected Behavior Summary

| Feature | Action | Expected Result |
|---------|--------|-----------------|
| Phone Request | Request from same building | ✅ Success |
| Phone Request | Request from different building | ❌ Blocked |
| Phone Request | Seller accepts | ✅ Status updated |
| Phone Request | Buyer views seller phone | ✅ Shows seller phone |
| Post | Safe content | ✅ Saved |
| Post | Banned keyword | ❌ Blocked + Warning |
| Comment | Safe content | ✅ Saved |
| Comment | Banned keyword | ❌ Blocked + Warning |
| Listing | Safe content | ✅ Saved |
| Listing | Banned keyword | ❌ Blocked + Warning |

---

## Troubleshooting

### Phone Request Not Showing
- Check seller is in same building as buyer
- Check request was created (check console logs)
- Try refreshing the screen

### Moderation Not Working
- Check console for "Banned keyword detected"
- Verify keyword is in the banned list
- Try exact keyword from list

### Dialog Not Appearing
- Check BuildContext is passed correctly
- Verify showDialog() is called
- Check for navigation issues

---

## Files to Monitor

### Marketplace Phone Requests
- `lib/src/services/listing_firestore_service.dart` - Core logic
- `lib/src/screens/marketplace_your_product_detail_screen.dart` - Seller view
- `lib/src/screens/marketplace_product_detail_screen.dart` - Buyer view

### Content Moderation
- `lib/src/services/content_moderation_service.dart` - Moderation logic
- `lib/src/modals/content_moderation_dialog.dart` - Warning UI
- `lib/src/services/post_firestore_service.dart` - Post integration
- `lib/src/services/listing_firestore_service.dart` - Listing integration

---

## Build Status

✅ No compilation errors  
✅ All diagnostics passed  
✅ Ready for testing  
✅ Ready for deployment

---

## Next Steps

1. Run the app
2. Test scenarios above
3. Check console logs
4. Verify UI/UX
5. Deploy to production

Good luck! 🚀
