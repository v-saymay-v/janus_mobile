import 'package:chat_ui_kit/chat_ui_kit.dart';

class ChatUser extends UserBase {
  String id;
  String user;
  String group;
  String username;
  String avatarURL;
  DateTime lastPost;
  int unRead;

  ChatUser({this.id, this.user, this.group, this.username,
    this.avatarURL, this.lastPost, this.unRead});

  String get userid => user;
  String get groupid => group;

  @override
  String get name => username;

  @override
  String get avatar => avatarURL;

  DateTime get datetime => lastPost;
  int get unread => unRead;

  Map<String, dynamic> toMap() {
    return {
      "c_id": id,
      "n_user": user,
      "n_group": group,
      "c_name": username,
      "c_photo": avatarURL,
      "d_last": lastPost==null?'':lastPost.toString(),
      "n_unread": unRead
    };
  }
}
