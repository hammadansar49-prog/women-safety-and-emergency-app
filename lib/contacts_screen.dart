import 'auth_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'social_controller.dart';
import 'theme/tokens.dart';
import 'ui/design.dart';

/// A buddy row. A deliberate 1500ms hold (or the star) opens SOS options.
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
    child: RowCard(
      leading: AvatarDot(name: name),
      title: name,
      detail: subtitle,
      onTap: onOpenChat,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (favorite)
            Icon(
              Icons.star_rounded,
              color: AppColors.primary,
              size: 22,
              semanticLabel: 'SOS buddy',
            ),
          IconButton(
            tooltip: 'Options for $name',
            onPressed: onOptions,
            icon: Icon(Icons.more_vert, color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    super.key,
    required this.social,
    this.safetyBannerBuilder,
    this.searchRemote,
  });
  final SocialController social;

  /// Searches accounts across the whole service (null = local only).
  final Future<List<RemoteProfile>> Function(String prefix)? searchRemote;
  final WidgetBuilder? safetyBannerBuilder;
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String query = '';
  final _searchController = TextEditingController();
  List<RemoteProfile> _remote = [];
  int _searchToken = 0;
  SocialController get social => widget.social;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onQuery(String value) async {
    setState(() => query = value);
    final token = ++_searchToken;
    final search = widget.searchRemote;
    if (search == null || value.trim().isEmpty) {
      setState(() => _remote = []);
      return;
    }
    // Short debounce so typing does not fire a query per keystroke.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (token != _searchToken) return;
    try {
      final found = await search(value);
      if (mounted && token == _searchToken) setState(() => _remote = found);
    } catch (_) {
      if (mounted && token == _searchToken) setState(() => _remote = []);
    }
  }

  void _action(VoidCallback action) {
    try {
      action();
    } on StateError catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openChat(String friendId) => Navigator.of(context).push(
    SafeRoute<void>(
      builder: (_) => ChatScreen(
        social: social,
        friendId: friendId,
        safetyBannerBuilder: widget.safetyBannerBuilder,
      ),
    ),
  );

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
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                social.isFavorite(friend.id)
                    ? 'Remove this person to stop including them in your SOS recipients.'
                    : 'Only SOS buddies who approve receive your alerts. Being a buddy alone does not share your location.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              BerryButton(
                icon: social.isFavorite(friend.id)
                    ? Icons.star_border
                    : Icons.star,
                label: social.isFavorite(friend.id)
                    ? 'Remove from SOS buddies'
                    : 'Add to SOS buddies',
                onTap: () {
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
                child: const Text('Remove buddy'),
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
      final local = social.search(query);
      final known = {for (final p in local) p.username.toLowerCase()};
      final results = [
        ...local,
        for (final r in _remote)
          if (r.uid != social.currentUserId &&
              !known.contains(r.username.toLowerCase()))
            DemoPerson(id: r.uid, name: r.username, username: r.username),
      ];
      return HeaderPage(
        animate: false,
        headerHeight: 190,
        overlap: 30,
        header: const HeaderTitle(
          'Buddies',
          subtitle: 'Find people by username. Tap a buddy to chat.',
        ),
        children: [
          DesignField(
            key: ValueKey('search-${social.currentUserId}'),
            controller: _searchController,
            hint: 'Find by username',
            icon: Icons.search,
            pill: true,
            shadow: true,
            onChanged: _onQuery,
          ),
          if (query.trim().isNotEmpty) ...[
            const SectionLabel('Search results'),
            if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'No matching user.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            for (final person in results) _resultRow(person),
          ],
          if (social.pendingIncoming.isNotEmpty)
            const SectionLabel('Buddy requests'),
          for (final request in social.pendingIncoming)
            RowCard(
              leading: AvatarDot(name: social.person(request.fromId).name),
              title: '@${social.person(request.fromId).username}',
              detail: 'wants to be your buddy',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PillButton(
                    label: 'Accept',
                    filled: true,
                    onTap: () => _action(
                      () => social.respondToFriendRequest(request.id, true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PillButton(
                    label: 'Decline',
                    tone: (AppColors.surface, AppColors.textMuted),
                    onTap: () => _action(
                      () => social.respondToFriendRequest(request.id, false),
                    ),
                  ),
                ],
              ),
            ),
          if (social.incomingSosRequests.isNotEmpty)
            const SectionLabel('SOS approval'),
          for (final request in social.incomingSosRequests)
            RowCard(
              leading: AvatarDot(name: social.person(request.senderId).name),
              title: '${social.person(request.senderId).name} chose you',
              detail: 'Approve to receive their SOS. You can revoke any time.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PillButton(
                    label: 'Approve',
                    filled: true,
                    onTap: () => _action(
                      () => social.respondToSosRequest(request.senderId, true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PillButton(
                    label: 'Decline',
                    tone: (AppColors.surface, AppColors.textMuted),
                    onTap: () => _action(
                      () => social.respondToSosRequest(request.senderId, false),
                    ),
                  ),
                ],
              ),
            ),
          SectionLabel('Your buddies (${social.friends.length})'),
          if (social.friends.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Your circle starts here. Search a username and send your first request.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          for (final friend in social.friends)
            FriendContactTile(
              key: ValueKey('friend-${friend.id}'),
              name: friend.name,
              subtitle: social.isApprovedFavorite(friend.id)
                  ? 'SOS buddy · approved'
                  : social.isFavorite(friend.id)
                  ? social.hasPendingSosRequest(friend.id)
                        ? 'SOS buddy · awaiting approval'
                        : 'SOS buddy · approval needed'
                  : '@${friend.username} · Tap to chat',
              favorite: social.isFavorite(friend.id),
              onOpenChat: () => _openChat(friend.id),
              onOptions: () => _options(friend),
            ),
          if (social.approvedSenders.isNotEmpty)
            const SectionLabel('People whose SOS you receive'),
          for (final person in social.approvedSenders)
            RowCard(
              leading: AvatarDot(name: person.name),
              title: '${person.name} can send you SOS',
              detail: 'Revoke to stop receiving their alerts.',
              trailing: PillButton(
                label: 'Revoke',
                onTap: () =>
                    _action(() => social.revokeSosPermission(person.id)),
              ),
            ),
        ],
      );
    },
  );

  /// One search result: the state sits beside the username (Message,
  /// Requested, Add buddy), like the rest of the app's rows.
  Widget _resultRow(DemoPerson person) {
    final Widget action;
    final String detail;
    if (social.areFriends(social.currentUserId, person.id)) {
      detail = 'Buddy';
      action = PillButton(label: 'Message', onTap: () => _openChat(person.id));
    } else if (social.pendingOutgoing.any((r) => r.toId == person.id)) {
      detail = 'Request sent';
      action = PillButton(
        label: 'Requested',
        tone: (
          AppColors.light ? const Color(0xFFFFEDE5) : AppColors.tint,
          AppColors.light ? const Color(0xFF8C3A1E) : AppColors.text,
        ),
        onTap: () => _action(() {
          final sent = social.pendingOutgoing.firstWhere(
            (r) => r.toId == person.id,
          );
          social.cancelFriendRequest(sent.id);
        }),
      );
    } else if (social.pendingIncoming.any((r) => r.fromId == person.id)) {
      detail = 'Sent you a request';
      action = const PillButton(label: 'Request received');
    } else {
      detail = 'Not a buddy yet';
      action = PillButton(
        label: 'Add buddy',
        filled: true,
        onTap: () => _action(() {
          social.adoptRemote(person.id, person.username);
          social.requestFriend(person.id);
        }),
      );
    }
    return RowCard(
      leading: AvatarDot(name: person.name),
      title: '@${person.username}',
      detail: detail,
      trailing: AnimatedSwitcher(
        duration: Motion.standard,
        child: KeyedSubtree(key: ValueKey(detail), child: action),
      ),
    );
  }
}
