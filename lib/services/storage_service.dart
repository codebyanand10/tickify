import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Upload a file to Supabase Storage
  /// 
  /// [file] - The file to upload
  /// [bucket] - The storage bucket name (default: 'certificates')
  /// [path] - The path within the bucket (e.g., 'certificate_templates/image.jpg')
  /// 
  /// Returns the public URL of the uploaded file
  Future<String> uploadFile({
    required File file,
    required String path,
    String bucket = 'certificates',
  }) async {
    try {
      // Upload the file to Supabase Storage
      final String fullPath = await _supabase.storage
          .from(bucket)
          .upload(
            path,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Get the public URL
      final String publicUrl = _supabase.storage
          .from(bucket)
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Update/Replace an existing file in Supabase Storage
  /// 
  /// [file] - The new file to upload
  /// [bucket] - The storage bucket name
  /// [path] - The path within the bucket
  /// 
  /// Returns the public URL of the uploaded file
  Future<String> updateFile({
    required File file,
    required String path,
    String bucket = 'certificates',
  }) async {
    try {
      // Upload with upsert: true to replace existing file
      await _supabase.storage
          .from(bucket)
          .upload(
            path,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true, // This allows replacing existing files
            ),
          );

      // Get the public URL
      final String publicUrl = _supabase.storage
          .from(bucket)
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to update file: $e');
    }
  }

  /// Delete a file from Supabase Storage
  /// 
  /// [path] - The path of the file to delete
  /// [bucket] - The storage bucket name
  Future<void> deleteFile({
    required String path,
    String bucket = 'certificates',
  }) async {
    try {
      await _supabase.storage
          .from(bucket)
          .remove([path]);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Get the public URL for a file
  /// 
  /// [path] - The path of the file
  /// [bucket] - The storage bucket name
  /// 
  /// Returns the public URL
  String getPublicUrl({
    required String path,
    String bucket = 'certificates',
  }) {
    return _supabase.storage
        .from(bucket)
        .getPublicUrl(path);
  }

  /// List files in a directory
  /// 
  /// [path] - The directory path
  /// [bucket] - The storage bucket name
  /// 
  /// Returns a list of file objects
  Future<List<FileObject>> listFiles({
    required String path,
    String bucket = 'certificates',
  }) async {
    try {
      final List<FileObject> files = await _supabase.storage
          .from(bucket)
          .list(path: path);
      
      return files;
    } catch (e) {
      throw Exception('Failed to list files: $e');
    }
  }
}
