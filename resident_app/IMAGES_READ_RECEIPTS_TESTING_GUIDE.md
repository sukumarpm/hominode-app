# Images & Read Receipts - Testing Guide

## Quick Test Scenarios

### Community Wall - Image Sharing

#### Test 1: Create Post with Image
1. Navigate to Community Wall
2. Tap "+" (Create Post) button
3. Enter post text: "Testing image upload"
4. Tap "Add Image" button
5. Select an image from gallery
6. Verify image preview displays
7. Tap "Post" button
8. Verify:
   - Upload progress shows
   - Post appears on wall
   - Image displays in post card
   - Image is properly sized (240px height)

#### Test 2: Remove Image Before Posting
1. Follow steps 1-5 from Test 1
2. Tap the red X button on image preview
3. Verify image is removed
4. Tap "Post" button
5. Verify post created without image

#### Test 3: Large Image Rejection
1. Follow steps 1-4 from Test 1
2. Select an image larger than 10MB
3. Verify error message appears
4. Verify post is not created

#### Test 4: Image Display in Post Card
1. Create a post with image (Test 1)
2. Scroll through community wall
3. Verify:
   - Image displays with rounded corners
   - Image is responsive
   - Image loads properly
   - Error handling works if image fails to load

---

### Messages - Image Sharing

#### Test 5: Send Message with Image
1. Navigate to Messages
2. Open a chat conversation
3. Tap image button (📷) in message composer
4. Select an image from gallery
5. Verify image preview displays above input
6. Tap send button
7. Verify:
   - Upload progress shows
   - Message appears in chat
   - Image displays in message bubble
   - Status shows as "sent" (✓)

#### Test 6: Remove Image Before Sending
1. Follow steps 1-4 from Test 5
2. Tap the red X button on image preview
3. Verify image is removed
4. Tap send button
5. Verify message sent without image

#### Test 7: Multiple Images in Chat
1. Send 3 messages with different images
2. Verify all images display correctly
3. Verify no image overlap or layout issues

---

### Messages - Read Receipts

#### Test 8: Single Check (Sent)
1. Send a text message
2. Immediately check status icon
3. Verify single check (✓) appears in gray
4. Hover over icon to see "Sent" tooltip

#### Test 9: Double Check (Delivered)
1. Send a text message
2. Wait a moment
3. Verify double check (✓✓) appears in gray
4. Hover over icon to see "Delivered" tooltip

#### Test 10: Blue Double Check (Read)
1. Send a text message to another user
2. Have that user open the chat
3. Verify double check (✓✓) turns blue
4. Hover over icon to see "Seen" tooltip

#### Test 11: Read Receipt with Image
1. Send a message with image
2. Verify status progresses: sending → sent → delivered → read
3. Verify blue check appears when recipient reads

#### Test 12: Multiple Messages Status
1. Send 5 messages in sequence
2. Verify each has correct status
3. Verify statuses update independently
4. Verify no status conflicts

---

### Error Scenarios

#### Test 13: Network Error During Upload
1. Start uploading an image
2. Disconnect network (airplane mode)
3. Verify error message appears
4. Verify post/message not created
5. Reconnect network
6. Verify app recovers gracefully

#### Test 14: Invalid Image Format
1. Try to upload a non-image file
2. Verify error message appears
3. Verify file is rejected

#### Test 15: Upload Timeout
1. Upload a large image on slow network
2. If upload times out, verify error message
3. Verify user can retry

---

### UI/UX Tests

#### Test 16: Image Sizing
1. Create posts with images of different sizes
2. Verify all images display at 240px height
3. Verify aspect ratio is maintained
4. Verify no distortion

#### Test 17: Message Bubble Layout
1. Send messages with images
2. Verify image displays inside bubble
3. Verify text displays above/below image
4. Verify status icon displays correctly
5. Verify sender name displays for group chats

#### Test 18: Loading States
1. Send image message on slow network
2. Verify progress indicator shows
3. Verify UI remains responsive
4. Verify user can still interact with app

#### Test 19: Error States
1. Trigger various error scenarios
2. Verify error messages are clear
3. Verify error messages suggest action
4. Verify UI recovers gracefully

---

### Performance Tests

#### Test 20: Multiple Images
1. Create 10 posts with images
2. Scroll through community wall
3. Verify smooth scrolling
4. Verify no lag or jank
5. Verify images load progressively

#### Test 21: Chat with Many Images
1. Send 20 messages with images
2. Scroll through chat
3. Verify smooth scrolling
4. Verify no memory issues
5. Verify images load progressively

---

## Expected Results

### Community Wall
✅ Images upload to Cloudinary successfully
✅ Images display in post cards with proper sizing
✅ Image preview works before posting
✅ Remove button removes image
✅ Error handling works for large/invalid files
✅ Posts without images still work

### Messages
✅ Images upload to Cloudinary successfully
✅ Images display in message bubbles
✅ Image preview works before sending
✅ Remove button removes image
✅ Error handling works for large/invalid files
✅ Messages without images still work
✅ Read receipts show correct status
✅ Status updates in real-time
✅ Blue check appears when message is read

---

## Debugging Tips

### If Images Don't Upload:
1. Check Cloudinary credentials in ImageUploadFlowFunction
2. Verify upload preset is configured
3. Check network connectivity
4. Check file size (max 10MB)
5. Check file format (JPG, PNG, GIF, WebP)

### If Read Receipts Don't Update:
1. Check Firestore rules allow read status updates
2. Verify chat service is marking messages as read
3. Check real-time listeners are active
4. Verify user IDs are correct

### If Images Don't Display:
1. Check image URL is valid
2. Check Cloudinary URL is accessible
3. Check image format is supported
4. Check error handling is working

---

## Test Data

### Sample Images
- Small: 100KB JPG
- Medium: 2MB PNG
- Large: 8MB JPG
- Very Large: 15MB JPG (should fail)

### Sample Text
- Short: "Hello"
- Medium: "This is a test message with some content"
- Long: "Lorem ipsum dolor sit amet, consectetur adipiscing elit..."

---

## Checklist

- [ ] Community Wall image upload works
- [ ] Community Wall image display works
- [ ] Messages image upload works
- [ ] Messages image display works
- [ ] Read receipts show correct status
- [ ] Status updates in real-time
- [ ] Error handling works
- [ ] UI is responsive
- [ ] Performance is good
- [ ] All tests pass

---

**Ready to test!** 🚀
