import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  static const String _cloudName = "dwfeh6gkm";
  static const String _uploadPreset = "tender_app";

  static final _cloudinary = CloudinaryPublic(
    _cloudName,
    _uploadPreset,
    cache: false,
  );

  // folder parameter-ti optional kora hoyeche (default: tenders)
  // resourceType Auto kora hoyeche jate Image ebong PDF duto-i upload hoy
  static Future<String?> uploadImage(
    List<int> bytes, {
    String folder = 'tenders',
  }) async {
    try {
      debugPrint("Attempting to upload to Cloudinary folder: $folder...");

      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          bytes,
          identifier: "file_${DateTime.now().millisecondsSinceEpoch}",
          folder: folder, // Ekhane ekhon error hobe na
          resourceType:
              CloudinaryResourceType.Auto, // Auto dile PDF o kaj korbe
        ),
      );

      debugPrint("Upload Success! Secure URL: ${response.secureUrl}");
      return response.secureUrl;
    } catch (e) {
      debugPrint("CLOUDINARY ERROR DETAIL: $e");
      return null;
    }
  }
}
