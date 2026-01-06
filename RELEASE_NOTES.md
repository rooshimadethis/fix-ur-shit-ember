# Release Notes - More Colors Branch

**Release Date:** January 6, 2026  
**Branch:** more-colors  
**Commits:** 13

<p align="center">
  <img src="https://github.com/rooshimadethis/fix-ur-shit-ember/releases/download/v1.0.5/1.0.5.png" alt="v1.0.5 Screenshot" />
</p>

---

## 🎨 New Features

### Color Picker
- **Added custom LED color picker** for Ember mug customization
- Allows users to select from a wide range of colors for their mug's LED

### Temperature Presets
- **Introduced temperature preset system** for quick temperature selection
- Presets display both name and temperature value
- Added character limit to preset text for consistent UI
- **Reset presets functionality** with confirmation dialog to prevent accidental resets
- Preset selection now includes haptic feedback for better user experience

### Half-Degree Celsius Support
- **Celsius temperature control now supports half-degree increments** (e.g., 50.5°C, 51.0°C)
- Provides more precise temperature control for Celsius users

---

## 🎯 UI/UX Improvements

### Visual Design
- **Implemented glassmorphism design** replacing previous paper-style cards
- Added **animated background wave effect** for a more dynamic, premium feel
- **Smooth liquid level transitions** - the wave animation now smoothly transitions between levels instead of jumping
- **Improved liquid level visualization** - uses a hybrid approach that combines liquid state with sensor readings for more realistic display
  - Maps the sensor's 0-30 range to a 40-80% visual range when liquid is present
  - Shows 0% only when the mug is actually empty
  - Accounts for the capacitive sensor being optimized for empty detection rather than precise fill measurement
- Increased font sizes across the app for better readability
- Rounded icon buttons for a more modern aesthetic
- Refined overall styling for a cleaner, more polished appearance

### Accessibility Enhancements
- Improved accessibility features throughout the app
- Enhanced contrast and readability
- Better support for assistive technologies
- Added haptic feedback to temperature slider for tactile confirmation

---

## 🐛 Bug Fixes

### Temperature Control
- **Fixed temperature range validation** to ensure proper min/max bounds
- **Fixed Celsius vibration feedback** - haptic feedback now works correctly when using Celsius units
- Resolved issues with temperature conversion and display

### LED Color Management
- **Fixed LED color persistence during green cycle** - the app now correctly saves and restores the user's preferred LED color
- When the app is closed during the "perfect temperature" green light cycle and reopened, it now restores the user's original color choice instead of defaulting to green
- LED color preference is now stored persistently across app sessions

### General Fixes
- Applied initial error handling improvements
- Code cleanup and style standardization
- Various stability improvements

---

## 🔧 Technical Improvements

- Cleaned up codebase styling and formatting
- Improved code organization and maintainability
- Enhanced error handling mechanisms
- Optimized UI rendering performance


