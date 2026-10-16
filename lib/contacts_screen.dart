import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'social_controller.dart';

/// A deliberate 1500ms gesture, with a keyboard/screen-reader menu alternative.
class FriendContactTile extends StatelessWidget {
  const FriendContactTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.favorite,
    required this.onOpenChat,
    required this.onOptions,
  });
  final String name;
  final String subtitle;
  final bool favorite;
  final VoidCallback onOpenChat;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              duration: const Duration(milliseconds: 1500),
            ),
            (recognizer) => recognizer.onLongPress = onOptions,
          ),
    },
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onOpenChat,
        leading: CircleAvatar(child: Text(name.substring(0, 1))),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (favorite)
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFAE7900),
                semanticLabel: 'Favorite SOS contact',
              ),
            IconButton(
              tooltip: 'Contact options for $name',
              onPressed: onOptions,
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    ),
  );
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    super.key,
    required this.social,
    this.safetyBannerBuilder,
  });
  final SocialController social;
  final WidgetBuilder? safetyBannerBuilder;
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String query = '';
  SocialController get social => widget.social;

  void _action(VoidCallback action) {
    try {
      action();
    } on StateError catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _options(DemoPerson friend) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                friend.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                social.isFavorite(friend.id)
                    ? 'Remove this person to stop including them in your SOS recipients.'
                    : 'Only favorite contacts who approve SOS access receive your alerts. Friendship alone does not share your location.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: Icon(
                  social.isFavorite(friend.id) ? Icons.star_border : Icons.star,
                ),
                label: Text(
                  social.isFavorite(friend.id)
                      ? 'Remove from favorite SOS contacts'
                      : 'Add to favorite SOS contact',
                ),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _action(
                    () => social.isFavorite(friend.id)
                        ? social.unfavorite(friend.id)
                        : social.favorite(friend.id),
                  );
                },
              ),
              if (social.isFavorite(friend.id) &&
                  !social.isApprovedFavorite(friend.id) &&
                  !social.hasPendingSosRequest(friend.id))
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _action(() => social.favorite(friend.id));
                  },
                  child: const Text('Request SOS approval again'),
                ),
              TextButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _action(() => social.removeFriend(friend.id));
                },
                child: const Text('Remove friend'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: social,
    builder: (context, _) {
      final results = social.search(query);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Friends & chats',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap a friend to chat. Hold for 1.5 seconds to choose favorite SOS contacts, or use the three-dot menu.',
          ),
          const SizedBox(height: 20),
          TextField(
            key: ValueKey('search-${social.currentUserId}'),
            decoration: const InputDecoration(
              labelText: 'Find by username',
              hintText: 'Enter a username',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          if (query.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            if (results.isEmpty) const Text('No matching user.'),
            for (final person in results)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text('${person.name}  @${person.username}'),
                      if (social.areFriends(social.currentUserId, person.id))
                        const Chip(label: Text('Friend'))
                      else if (social.pendingOutgoing.any(
                        (r) => r.toId == person.id,
                      ))
                        const Chip(label: Text('Request sent'))
                      else if (social.pendingIncoming.any(
                        (r) => r.fromId == person.id,
                      ))
                        const Chip(label: Text('Request received'))
                      else
                        FilledButton.tonal(
                          onPressed: () =>
                              _action(() => social.requestFriend(person.id)),
                          child: const Text('Send request'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          if (social.pendingIncoming.isNotEmpty) _section('Friend requests'),
          for (final request in social.pendingIncoming)
            _request(
              '${social.person(request.fromId).name} wants to be friends',
              'Friendship opens chat. SOS access is a separate choice.',
              [
                TextButton(
                  onPressed: () => _action(
                    () => social.respondToFriendRequest(request.id, false),
                  ),
                  child: const Text('Decline'),
                ),
                FilledButton(
                  onPressed: () => _action(
                    () => social.respondToFriendRequest(request.id, true),
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ),
          if (social.pendingOutgoing.isNotEmpty) _section('Sent requests'),
          for (final request in social.pendingOutgoing)
            _request(
              'Waiting for ${social.person(request.toId).name}',
              'Your friend request is awaiting a response.',
              [
                TextButton(
                  onPressed: () =>
                      _action(() => social.cancelFriendRequest(request.id)),
                  child: const Text('Cancel request'),
                ),
              ],
            ),
          if (social.incomingSosRequests.isNotEmpty)
            _section('SOS contact approval'),
          for (final request in social.incomingSosRequests)
            _request(
              '${social.person(request.senderId).name} chose you for SOS',
              'Approve to receive their SOS alerts. You can revoke this any time.',
              [
                TextButton(
                  onPressed: () => _action(
                    () => social.respondToSosRequest(request.senderId, false),
                  ),
                  child: const Text('Decline SOS'),
                ),
                FilledButton(
                  onPressed: () => _action(
                    () => social.respondToSosRequest(request.senderId, true),
                  ),
                  child: const Text('Approve SOS'),
                ),
              ],
            ),
          _section('Your friends (${social.friends.length})'),
          if (social.friends.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Your circle starts here. Search a username and send your first request.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final friend in social.friends)
            FriendContactTile(
              key: ValueKey('friend-${friend.id}'),
              name: friend.name,
              subtitle: social.isApprovedFavorite(friend.id)
                  ? 'Favorite SOS contact · approved'
                  : social.isFavorite(friend.id)
                  ? social.hasPendingSosRequest(friend.id)
                        ? 'Favorite SOS contact · awaiting approval'
                        : 'Favorite SOS contact · approval needed'
                  : '@${friend.username} · Tap to chat',
              favorite: social.isFavorite(friend.id),
              onOpenChat: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(
                    social: social,
                    friendId: friend.id,
                    safetyBannerBuilder: widget.safetyBannerBuilder,
                  ),
                ),
              ),
              onOptions: () => _options(friend),
            ),
          if (social.approvedSenders.isNotEmpty)
            _section('People whose SOS you receive'),
          for (final person in social.approvedSenders)
            _request(
              '${person.name} can send you SOS alerts',
              'Revoke to stop receiving their SOS and remove access to their active events.',
              [
                TextButton(
                  onPressed: () =>
                      _action(() => social.revokeSosPermission(person.id)),
                  child: const Text('Revoke SOS approval'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Text(
            'Manage SOS access through your approved favorite contacts.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    },
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
    ),
  );
  Widget _request(String title, String detail, List<Widget> actions) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(detail),
          const SizedBox(height: 10),
          Wrap(alignment: WrapAlignment.end, spacing: 8, children: actions),
        ],
      ),
    ),
  );
}
