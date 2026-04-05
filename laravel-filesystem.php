<?php

// ============================================
// Laravel GCS Filesystem Setup
// ============================================
//
// 1. Install the Flysystem GCS adapter:
//
//    composer require league/flysystem-google-cloud-storage
//
// 2. Add the GCS disk to config/filesystems.php:

'disks' => [
    // ... existing disks ...

    'gcs' => [
        'driver'                  => 'gcs',
        'project_id'              => env('GOOGLE_CLOUD_PROJECT_ID'),
        'bucket'                  => env('GOOGLE_CLOUD_STORAGE_BUCKET'),
        // No credentials needed — Cloud Run's service account
        // is used automatically via Application Default Credentials.
        // Locally, use: gcloud auth application-default login
    ],
],

// 3. Set the default disk in .env:
//
//    FILESYSTEM_DISK=gcs
//    GOOGLE_CLOUD_STORAGE_BUCKET=my-app-production-uploads
//
// Both vars are set automatically by Terraform via Cloud Run env vars.
//
// ============================================
// Usage
// ============================================
//
// Storing files:
//    Storage::put('avatars/user-1.jpg', $file);
//
// Getting URLs:
//    // Public bucket:
//    Storage::url('avatars/user-1.jpg');
//    // → https://storage.googleapis.com/my-app-production-uploads/avatars/user-1.jpg
//
//    // Private bucket (signed URL, expires in 5 min):
//    Storage::temporaryUrl('avatars/user-1.jpg', now()->addMinutes(5));
//
// ============================================
// Local Development
// ============================================
//
// Option A: Use GCS in dev too (recommended for parity)
//    - Run: gcloud auth application-default login
//    - Set FILESYSTEM_DISK=gcs in .env
//    - Point to a dev/staging bucket
//
// Option B: Use local disk in dev
//    - Set FILESYSTEM_DISK=local in .env
//    - Files go to storage/app
//
// ============================================
// docker-compose.yml addition (Option B)
// ============================================
//
// If using local disk in dev, no changes needed.
// If using GCS in dev, mount your ADC credentials:
//
//   app:
//     volumes:
//       - ~/.config/gcloud:/home/www-data/.config/gcloud:ro
