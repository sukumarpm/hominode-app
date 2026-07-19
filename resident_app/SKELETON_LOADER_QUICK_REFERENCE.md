# Skeleton Loader - Quick Reference Guide

## How to Use Skeleton Loaders

### 1. Import the Widget
```dart
import '../widgets/skeleton_loader.dart';
```

### 2. Use in StreamBuilder/FutureBuilder

#### For Single Items
```dart
StreamBuilder<Data>(
  stream: dataStream,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SkeletonLoader(
        width: double.infinity,
        height: 120,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      );
    }
    // Show actual content
    return actualContent;
  },
)
```

#### For Lists
```dart
StreamBuilder<List<Item>>(
  stream: itemsStream,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return SkeletonListLoader(
        itemCount: 5,
        itemHeight: 80,
      );
    }
    // Show actual list
    return actualList;
  },
)
```

#### For Chat Screens
```dart
if (snapshot.connectionState == ConnectionState.waiting) {
  return const SkeletonChatLoader();
}
```

#### For Dashboard
```dart
if (snapshot.connectionState == ConnectionState.waiting) {
  return const SkeletonDashboardLoader();
}
```

## Available Components

| Component | Use Case | Properties |
|-----------|----------|-----------|
| `SkeletonLoader` | Individual placeholder | width, height, borderRadius, margin |
| `SkeletonCardLoader` | Card item | height, padding |
| `SkeletonListLoader` | Multiple items | itemCount, itemHeight |
| `SkeletonDashboardLoader` | Full dashboard | None (fixed layout) |
| `SkeletonChatLoader` | Chat screen | None (fixed layout) |
| `SkeletonProfileLoader` | Profile screen | None (fixed layout) |

## Common Patterns

### Pattern 1: Simple Loading State
```dart
if (snapshot.connectionState == ConnectionState.waiting) {
  return const SkeletonLoader(height: 100);
}
```

### Pattern 2: List Loading State
```dart
if (snapshot.connectionState == ConnectionState.waiting) {
  return SkeletonListLoader(itemCount: 5);
}
```

### Pattern 3: Complex Screen Loading
```dart
if (snapshot.connectionState == ConnectionState.waiting) {
  return const SkeletonDashboardLoader();
}
```

### Pattern 4: Error Handling
```dart
if (snapshot.hasError) {
  return ErrorWidget();
}
if (snapshot.connectionState == ConnectionState.waiting) {
  return SkeletonLoader();
}
return ActualContent();
```

## Customization

### Custom Size
```dart
const SkeletonLoader(
  width: 200,
  height: 50,
)
```

### Custom Border Radius
```dart
const SkeletonLoader(
  borderRadius: BorderRadius.all(Radius.circular(20)),
)
```

### Custom Margin
```dart
const SkeletonLoader(
  margin: EdgeInsets.all(16),
)
```

### Custom List Item Count
```dart
SkeletonListLoader(
  itemCount: 10,
  itemHeight: 120,
)
```

## Animation Details

- **Duration**: 1500ms
- **Effect**: Shimmer gradient (left to right)
- **Colors**: Gray → Light Gray → Gray
- **Repeat**: Continuous loop
- **Performance**: 60fps on most devices

## Best Practices

✅ **DO**:
- Use skeleton loaders for all async data loading
- Match skeleton layout to actual content
- Use appropriate component for the use case
- Keep loading time under 3 seconds
- Show error state if loading fails

❌ **DON'T**:
- Mix skeleton loaders with spinners
- Use skeleton loaders for instant data
- Forget to handle error states
- Use wrong component type
- Customize colors (use defaults)

## Integration Checklist

When adding skeleton loaders to a new screen:

- [ ] Import `skeleton_loader.dart`
- [ ] Identify loading states in StreamBuilder/FutureBuilder
- [ ] Choose appropriate skeleton component
- [ ] Add skeleton in `ConnectionState.waiting` condition
- [ ] Test on slow network (DevTools throttling)
- [ ] Verify smooth transition to actual content
- [ ] Test error states
- [ ] Test empty states

## Troubleshooting

### Skeleton not showing
- Check if `ConnectionState.waiting` is being reached
- Verify import statement
- Check if data loads too fast

### Animation not smooth
- Ensure device supports 60fps
- Check for other heavy animations
- Verify no blocking operations

### Skeleton doesn't match content
- Adjust height and width
- Adjust border radius
- Use correct component type

## Files Modified

- `resident_app/lib/src/screens/admin_dashboard_screen.dart`
- `resident_app/lib/src/screens/chat_conversation_screen.dart`
- `resident_app/lib/src/screens/messages_screen_enhanced.dart`

## Next Steps

To add skeleton loaders to more screens:

1. Identify async data loading screens
2. Import `skeleton_loader.dart`
3. Add skeleton in loading state
4. Test on slow network
5. Verify smooth transitions

## Support

For questions or issues:
- Check `SKELETON_LOADER_INTEGRATION_COMPLETE.md` for detailed info
- Review existing implementations in modified files
- Test with DevTools network throttling
