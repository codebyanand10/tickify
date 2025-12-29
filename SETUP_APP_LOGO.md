# Setting Up App Logo

I've configured your project to use the Tickify logo as the app icon. Follow these steps:

## Step 1: Add Your Logo Image

1. Save your Tickify logo image (the one you showed me) as a PNG file
2. Name it: `app_logo.png`
3. Place it in: `assets/logo/app_logo.png`

**Image Requirements:**
- **Size:** 1024x1024 pixels (square, recommended)
- **Format:** PNG
- **Background:** Transparent or solid (black background works well based on your logo)
- **Quality:** High resolution

## Step 2: Generate Icons

Once you've placed the image, run these commands:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

This will automatically:
- Generate all required icon sizes for Android (mipmap folders)
- Generate all required icon sizes for iOS (AppIcon.appiconset)
- Create adaptive icons for Android
- Update all necessary configuration files

## Step 3: Verify

After running the commands:
- **Android:** Check `android/app/src/main/res/mipmap-*/ic_launcher.png` files
- **iOS:** Check `ios/Runner/Assets.xcassets/AppIcon.appiconset/` folder

## Step 4: Rebuild App

Rebuild your app to see the new icon:

```bash
flutter clean
flutter run
```

## Current Configuration

The `pubspec.yaml` is configured with:
- **Android:** Enabled with adaptive icon support (black background)
- **iOS:** Enabled
- **Image path:** `assets/logo/app_logo.png`
- **Adaptive icon background:** Black (#000000) to match your logo

## Notes

- The logo you showed has a black background, which works perfectly with the adaptive icon configuration
- If you want to change the adaptive icon background color, edit `adaptive_icon_background` in `pubspec.yaml`
- The tool automatically handles all the different sizes needed for different devices

