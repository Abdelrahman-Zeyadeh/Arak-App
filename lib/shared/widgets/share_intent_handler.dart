import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../features/downloader/widgets/download_modal_sheet.dart';

class ShareIntentHandler extends StatefulWidget {
  final Widget child;

  const ShareIntentHandler({super.key, required this.child});

  @override
  State<ShareIntentHandler> createState() => _ShareIntentHandlerState();
}

class _ShareIntentHandlerState extends State<ShareIntentHandler> {
  late StreamSubscription<List<SharedMediaFile>> _mediaSubscription;

  @override
  void initState() {
    super.initState();

    // Handle initial share intent (app opened from share)
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        _handleSharedFiles(files);
      }
      ReceiveSharingIntent.instance.reset();
    });

    // Listen for share intents while app is running
    _mediaSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        if (files.isNotEmpty) {
          _handleSharedFiles(files);
        }
        ReceiveSharingIntent.instance.reset();
      },
      onError: (e) {
        debugPrint('[ShareIntentHandler] Media stream error: $e');
      },
    );
  }

  @override
  void dispose() {
    _mediaSubscription.cancel();
    super.dispose();
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    for (final file in files) {
      final path = file.path;
      if (path.isNotEmpty && (path.startsWith('http://') || path.startsWith('https://'))) {
        _showDownloadSheet(path);
        return;
      }
    }
  }

  void _showDownloadSheet(String url) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DownloadModalSheet.show(context, url: url);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
