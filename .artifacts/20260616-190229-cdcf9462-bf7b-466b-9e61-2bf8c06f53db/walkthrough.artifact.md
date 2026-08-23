# Walkthrough - Crash Detection and Incident Locking

I have implemented an automated crash detection system that protects critical footage during a collision or sudden impact. This ensures that the most important moments are never overwritten by the smart storage manager.

## New Features

### 1. Accelerometer-Based Impact Detection
Using the phone's built-in G-sensor, the app now listens for sudden forces.
- **Threshold**: Set to **2.5G**. This is calibrated to detect actual vehicle impacts or emergency braking while ignoring normal road vibrations.
- **Real-time Monitoring**: The sensor is active only when recording to save battery.

### 2. Automatic File "Locking"
When an impact is detected, the app automatically identifies:
1. The **current** video clip being recorded.
2. The **previous** video clip (to capture the lead-up to the event).
3. These files are renamed with an **`EMG_`** (Emergency) prefix (e.g., `EMG_1718534400.mp4`).

### 3. Protection from Deletion
I have updated the Smart Storage manager to distinguish between regular footage and emergency footage:
- **`VID_` files**: Managed automatically; the oldest are deleted when storage is full.
- **`EMG_` files**: **Protected**. The app will never delete these files. You must manually delete them from your gallery to remove them.

### 4. Visual Confirmation
If an impact is detected, a red **"INCIDENT DETECTED - FILE LOCKED"** alert will appear on the screen for 5 seconds to give you immediate peace of mind that the footage is safe.

## Verification Results

### Automated Analysis
- Verified code integrity with `analyze_file`.
- Successfully added and synced the `sensors_plus` dependency.

### Manual Verification Recommended
1. **Test the Alert**: While recording, give the phone a quick, sharp shake (simulating a 2.5G jolt).
2. **Verify renaming**: Check your `Movies/Dashcam` folder. You should see files starting with `EMG_`.
3. **Verify Protection**: Let the storage get full. You will see that only `VID_` files are deleted, while `EMG_` files remain untouched.
