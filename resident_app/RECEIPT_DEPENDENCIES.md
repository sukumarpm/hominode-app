# Receipt Screen Dependencies

Add these dependencies to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # PDF Generation and Printing
  pdf: ^3.10.7
  printing: ^5.11.1
  
  # File System Access
  path_provider: ^2.1.1
  
  # Sharing Functionality
  share_plus: ^7.2.1

```

## Installation

Run the following command to install dependencies:

```bash
flutter pub get
```

## Platform-Specific Setup

### Android
No additional setup required.

### iOS
Add the following to your `ios/Podfile` if not already present:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_PHOTOS=1',
      ]
    end
  end
end
```

## Package Descriptions

### pdf (^3.10.7)
- Generates PDF documents programmatically
- Supports text, images, tables, and QR codes
- Used for creating the receipt PDF

### printing (^5.11.1)
- Provides printing and PDF preview functionality
- Opens PDF in native viewer
- Supports sharing and saving PDFs

### path_provider (^2.1.1)
- Provides access to commonly used locations on the filesystem
- Used to save PDF files to device storage
- Cross-platform support

### share_plus (^7.2.1)
- Enables sharing files and text via native share sheet
- Supports all major platforms
- Used for sharing receipt PDFs
