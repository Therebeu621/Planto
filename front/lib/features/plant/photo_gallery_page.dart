import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planto/core/constants/app_constants.dart';
import 'package:planto/core/services/photo_gallery_service.dart';
import 'package:planto/core/theme/app_theme.dart';

class PhotoGalleryPage extends StatefulWidget {
  final String plantId;
  final String plantName;
  final PhotoGalleryService? photoGalleryService;

  const PhotoGalleryPage({super.key, required this.plantId, required this.plantName, this.photoGalleryService});

  @override
  State<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  late final PhotoGalleryService _service = widget.photoGalleryService ?? PhotoGalleryService();
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    _photos = await _service.getPhotos(widget.plantId);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final image = await _picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();
      await _service.uploadPhoto(widget.plantId, bytes, image.name);
      _loadPhotos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo ajoutee')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _deletePhoto(String photoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la photo ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deletePhoto(widget.plantId, photoId);
      _loadPhotos();
    }
  }

  Future<void> _setPrimary(String photoId) async {
    await _service.setPrimary(widget.plantId, photoId);
    _loadPhotos();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo principale mise a jour')));
    }
  }

  void _viewFullscreen(int index) {
    Navigator.push(context, MaterialPageRoute(
      builder: (ctx) => _FullscreenGallery(photos: _photos, initialIndex: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photos - ${widget.plantName}'),
        actions: [
          IconButton(icon: const Icon(Icons.add_a_photo), onPressed: _addPhoto),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Aucune photo', style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _addPhoto,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Ajouter'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPhotos,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _photos.length,
                    itemBuilder: (ctx, i) {
                      final photo = _photos[i];
                      final url = _resolvePhotoUrl(photo['photoUrl'] as String?);
                      final isPrimary = photo['isPrimary'] == true;

                      return GestureDetector(
                        onTap: () => _viewFullscreen(i),
                        onLongPress: () => _showPhotoOptions(photo),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: url != null
                                  ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                                      Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)))
                                  : Container(color: Colors.grey.shade200, child: const Icon(Icons.image)),
                            ),
                            if (isPrimary)
                              Positioned(
                                top: 4, left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Principal', style: TextStyle(color: Colors.white, fontSize: 10)),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showPhotoOptions(Map<String, dynamic> photo) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('Definir comme principale'),
              onTap: () {
                Navigator.pop(ctx);
                _setPrimary(photo['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deletePhoto(photo['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _resolvePhotoUrl(String? url) {
    if (url == null) return null;
    if (url.startsWith('http')) return url;
    return '${AppConstants.apiBaseUrl}$url';
  }
}

class _FullscreenGallery extends StatelessWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;

  const _FullscreenGallery({required this.photos, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: photos.length,
        itemBuilder: (ctx, i) {
          final url = photos[i]['photoUrl'] as String?;
          final resolvedUrl = url != null && !url.startsWith('http')
              ? '${AppConstants.apiBaseUrl}$url'
              : url;
          return Center(
            child: resolvedUrl != null
                ? InteractiveViewer(
                    child: Image.network(resolvedUrl, fit: BoxFit.contain),
                  )
                : const Icon(Icons.image, color: Colors.white54, size: 64),
          );
        },
      ),
    );
  }
}
