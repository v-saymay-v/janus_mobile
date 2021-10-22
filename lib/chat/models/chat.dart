import 'package:chat_ui_kit/chat_ui_kit.dart';

import 'chat_message.dart';
import 'chat_user.dart';
import '../utils/app_const.dart';

class Chat {
  String id; //usually a UUID
  String name;
  String ownerId;
  String groupId;
  int unreadCount;

  Chat({this.id, this.name, this.ownerId, this.groupId, this.unreadCount});
}

class ChatWithMembers extends ChatBase {
  Chat chat;
  List<ChatUser> members;
  ChatMessage lastMessage;

  ChatWithMembers({this.chat, this.members, this.lastMessage});

  @override
  int get unreadCount => chat.unreadCount;

  @override
  String get name {
    final _name = (chat?.name ?? null);
    if (_name != null && _name.isNotEmpty) return chat.name;
    return membersWithoutSelf.map((e) => e.username).toList().join(", ");
  }

  @override
  String get id => chat?.id;

  List<ChatUser> get membersWithoutSelf {
    List<ChatUser> membersWithoutSelf = [];
    for (ChatUser chatUser in members) {
      if (chatUser != null && AppConstants.localUserId != chatUser.id)
        membersWithoutSelf.add(chatUser);
    }
    return membersWithoutSelf;
  }

  bool get isGroupChat => (members?.length ?? 0) > 2;
}
