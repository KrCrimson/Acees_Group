import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final double? size;

  const LoadingWidget({Key? key, this.message, this.size}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size ?? 40,
            height: size ?? 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          if (message != null) ...[
            SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;

  const ErrorWidget({Key? key, required this.message, this.onRetry, this.icon})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon ?? Icons.error_outline, size: 64, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}

class SuccessWidget extends StatelessWidget {
  final String message;
  final IconData? icon;
  final VoidCallback? onContinue;
  final String? continueText;

  const SuccessWidget({
    Key? key,
    required this.message,
    this.icon,
    this.onContinue,
    this.continueText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.check_circle_outline,
              size: 64,
              color: Colors.green[400],
            ),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (onContinue != null) ...[
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: onContinue,
                child: Text(continueText ?? 'Continuar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
