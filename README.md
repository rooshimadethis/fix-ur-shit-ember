> **Special Thanks**: Thank you to the team behind [python-ember-mug](https://github.com/sopelj/python-ember-mug) for their work in reverse-engineering the Ember Mug Bluetooth protocol

# Fix Ur Shit Ember

A functional replacement app for the Ember Mug, built with Flutter.

<p align="center">
  <img src="on.jpg" width="45%" alt="Heating On" />
  <img src="off.jpg" width="45%" alt="Heating Off" />
</p>

## Features

### Connection
*   **Bluetooth Low Energy (BLE)**: Scans for and connects to Ember Mugs.
*   **Auto-Scan**: Attempts to find the mug automatically on app startup.

### Temperature Control
*   **Read/Write**: View current liquid temperature and set a target temperature.
*   **Range**: Supports temperature setting between 50°C - 65°C (122°F - 149°F).
*   **Heating Toggle**: Manually turn the heater on or off. The app remembers the last used target temperature when turning heating back on.
*   **Unit Support**: Switch between Celsius and Fahrenheit.

### Notifications & Indicators
*   **Status Notification**: A persistent notification displays the current temperature, battery level, and heating status (e.g., "Heating", "Cooling", "Off") in the system tray.
*   **Drink Ready Alert**: Sends a specific "Drink Ready" notification when the liquid reaches the target temperature.
*   **Visual Indicator**: The Mug's LED pulses green for 60 seconds when the "Perfect" temperature is reached to provide a visual cue.

### Tools
*   **Steep Timer**: A built-in timer (default 5 minutes) for tea steeping. Triggers a notification when the timer expires.
*   **LED Color Picker**: Change the Ember Mug's LED indicator color.
*   **Liquid Level**: Monitors liquid level to detect if the mug is empty. Automatically disables heating when empty to conserve battery.

## Disclaimer

This software is provided "as is", without warranty of any kind, express or implied. Use this application at your own risk. The developers of this project are not affiliated with Ember® or any of its subsidiaries. This application interacts with hardware (Ember Mug) using reverse-engineered protocols; the user assumes all responsibility for any potential damage to their device, mug, or voiding of warranties.
