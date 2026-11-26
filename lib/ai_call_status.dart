import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class AiCallStatus extends StatelessWidget {
  const AiCallStatus({super.key, required this.sender, required this.eventId});
  final String sender;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final key = sha256
        .convert(utf8.encode(jsonEncode([sender, eventId])))
        .toString();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.doc('aiCalls/$key').snapshots(),
      builder: (context, snapshot) {
        final status = snapshot.data?.data()?['status'];
        final message = snapshot.data?.data()?['voiceError'] == true
            ? 'AI conversation failed. Use the dialer if needed.'
            : snapshot.hasError
            ? 'AI call status unavailable. Use the dialer if needed.'
            : status == null
            ? 'Automatic AI test calling is not confirmed or enabled.'
            : [
                'failed',
                'busy',
                'no-answer',
                'unknown',
                'rate-limited',
              ].contains(status)
            ? 'AI test call: $status. Use the dialer if needed.'
            : 'AI test call: $status. This does not confirm police contact or dispatch.';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(message),
        );
      },
    );
  }
}
