import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Full-screen viewer for legal HTML documents from assets (KVKK, EULA, Sales Agreement).
/// Use [LegalDocumentScreen.open] to push with an asset path.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.assetPath,
    this.title,
  });

  final String assetPath;
  final String? title;

  /// Pushes a full-screen legal document. [assetPath] e.g. 'assets/legal/kvkk.html'.
  static Future<void> open(
    BuildContext context, {
    required String assetPath,
    String? title,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(assetPath: assetPath, title: title),
      ),
    );
  }

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            if (mounted) setState(() {
              _loading = false;
              _error = e.description;
            });
          },
        ),
      );
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    try {
      final html = await rootBundle.loadString(widget.assetPath);
      if (!mounted) return;
      await _controller.loadHtmlString(html);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? _defaultTitle),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }

  String get _defaultTitle {
    final name = widget.assetPath.split('/').last;
    if (name == 'kvkk.html') return 'Gizlilik Politikası';
    if (name == 'eula.html') return 'Kullanım Koşulları';
    if (name == 'sales_agreement.html') return 'Mesafeli Satış Sözleşmesi';
    return name;
  }
}
