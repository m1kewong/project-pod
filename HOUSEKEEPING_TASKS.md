# Housekeeping Tasks for Project-Pod

## Completed Tasks
- Removed test file: `infra/test-gcs-buckets.js`
- Removed test file: `infra/test-upload.txt`
- Removed test file: `client/lib/main_test_upload.dart`
- Removed test file: `client/test_upload.dart`
- Added documentation about GCS bucket implementation in `infra/VIDEO_UPLOAD_GCS_IMPLEMENTATION.md`
- Updated todo.md to mark Step 6 as completed
- Added clarifying comments to the test user creation script

## Future Tasks
- Clean up temporary authentication bypass code:
  - In `client/lib/services/video_upload_service.dart`: Re-enable authentication check
  - In `client/lib/screens/upload_screen.dart`: Re-enable imports and authentication check
- Generate a new Firebase Admin SDK key and update `firebase-admin-key.json`
- Test the upload functionality with authenticated users
- Consider removing the temporary user creation files if not needed for future steps

## Authentication Code Changes Needed
1. **Upload Screen** (`client/lib/screens/upload_screen.dart`):
   - Uncomment imports: `package:provider/provider.dart` and `../services/auth_service.dart`
   - Uncomment authentication check in the build method
   - Uncomment redirection to login screen for unauthenticated users

2. **Video Upload Service** (`client/lib/services/video_upload_service.dart`):
   - Verify authentication check is enabled
   - Remove any temporary test user IDs or bypasses

## Notes
- Authentication functionality should be restored after all upload testing is completed
- The current configuration with temporary authentication bypass should be kept until proper end-to-end testing with authentication is complete
- Before implementing Step 7 (Transcoding Pipeline), ensure the upload functionality works correctly with authentication
