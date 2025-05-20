import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/payment_service.dart';

class PaymentWebView extends StatefulWidget {
  final String paymentUrl;
  final Function(Map<String, dynamic>) onPaymentComplete;

  const PaymentWebView({
    super.key,
    required this.paymentUrl,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController? controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                isLoading = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                isLoading = false;
              });
            },
            onNavigationRequest: (NavigationRequest request) {
              // Kiểm tra nếu URL là URL return của VNPay
              if (request.url.contains('vnp_ResponseCode')) {
                // Xử lý kết quả thanh toán
                final uri = Uri.parse(request.url);
                PaymentService.handlePaymentReturn(uri).then((orderData) {
                  widget.onPaymentComplete(orderData);
                  Navigator.pop(context);
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi xử lý thanh toán: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.pop(context);
                });
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.paymentUrl));
    } else {
      // For web platform, launch URL in new tab
      _launchWebPayment();
    }
  }

  Future<void> _launchWebPayment() async {
    try {
      final uri = Uri.parse(widget.paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // For web, we'll handle the return URL in the main app
        Navigator.pop(context);
      } else {
        throw Exception('Không thể mở URL thanh toán');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi mở trang thanh toán: $e'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán VNPay'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller!),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
} 