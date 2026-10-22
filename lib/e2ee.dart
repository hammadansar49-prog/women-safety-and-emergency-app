import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class DecryptFailure implements Exception {
  const DecryptFailure();
}

/// End-to-end encryption for chats. Each account owns an X25519 key pair; the
/// public half is published, the private half never leaves the device (it
/// travels only inside the encrypted account backup). Two friends derive the
/// same secret from their own private key and the other's public key, so the
/// server only ever sees ciphertext.
class E2ee {
  const E2ee();

  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// A new identity: (private, public) as base64.
  Future<({String priv, String pub})> newIdentity() async {
    final pair = await _x25519.newKeyPair();
    final data = await pair.extract();
    return (
      priv: base64Encode(await data.extractPrivateKeyBytes()),
      pub: base64Encode(data.publicKey.bytes),
    );
  }

  /// Rebuilds the public key from a stored private key.
  Future<String> publicFromPrivate(String priv) async {
    final pair = await _x25519.newKeyPairFromSeed(base64Decode(priv));
    return base64Encode((await pair.extractPublicKey()).bytes);
  }

  Future<SecretKey> _chatKey(
    String myPriv,
    String theirPub,
    String pair,
  ) async {
    final mine = await _x25519.newKeyPairFromSeed(base64Decode(myPriv));
    final shared = await _x25519.sharedSecretKey(
      keyPair: mine,
      remotePublicKey: SimplePublicKey(
        base64Decode(theirPub),
        type: KeyPairType.x25519,
      ),
    );
    return _hkdf.deriveKey(
      secretKey: shared,
      nonce: utf8.encode('safeher-chat-v1'),
      info: utf8.encode(pair),
    );
  }

  /// Seals [text] for the friend. [pair] names the conversation and is bound
  /// into the key so a message cannot be replayed into another chat.
  Future<String> encrypt({
    required String myPriv,
    required String theirPub,
    required String pair,
    required String text,
  }) async {
    final key = await _chatKey(myPriv, theirPub, pair);
    final box = await _aes.encrypt(utf8.encode(text), secretKey: key);
    return base64Encode(box.concatenation());
  }

  Future<String> decrypt({
    required String myPriv,
    required String theirPub,
    required String pair,
    required String sealed,
  }) async {
    try {
      final key = await _chatKey(myPriv, theirPub, pair);
      final box = SecretBox.fromConcatenation(
        base64Decode(sealed),
        nonceLength: 12,
        macLength: 16,
      );
      return utf8.decode(await _aes.decrypt(box, secretKey: key));
    } catch (_) {
      throw const DecryptFailure();
    }
  }

  /// The same seal around raw bytes, for a voice note.
  Future<String> encryptBytes({
    required String myPriv,
    required String theirPub,
    required String pair,
    required List<int> bytes,
  }) async {
    final key = await _chatKey(myPriv, theirPub, pair);
    final box = await _aes.encrypt(bytes, secretKey: key);
    return base64Encode(box.concatenation());
  }

  Future<Uint8List> decryptBytes({
    required String myPriv,
    required String theirPub,
    required String pair,
    required String sealed,
  }) async {
    try {
      final key = await _chatKey(myPriv, theirPub, pair);
      final box = SecretBox.fromConcatenation(
        base64Decode(sealed),
        nonceLength: 12,
        macLength: 16,
      );
      return Uint8List.fromList(await _aes.decrypt(box, secretKey: key));
    } catch (_) {
      throw const DecryptFailure();
    }
  }
}
