import 'package:janus_mobile/chat/utils/app_const.dart';
import 'package:chat_ui_kit/chat_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/chat.dart';
import '../models/chat_message.dart';
import '../ui/chat_viewmodel.dart';
import '../utils/date_formatter.dart';
import '../utils/app_colors.dart';
import '../ui/chat_screen.dart';

import '../../drawer_message.dart';
import '../../globals.dart' as globals;

class ChatsScreen extends StatefulWidget {
  @override
  _ChatsScreenSate createState() => _ChatsScreenSate();
}

class _ChatsScreenSate extends State<ChatsScreen> {
  final ChatViewModel _model = ChatViewModel();
  String _cookie;
  bool _reading = false;

  @override
  void initState() {
    getCookie();
    setState(() {
      _reading = true;
    });
    _model.controller = ChatsListController();
    _model.generateChats().then((value) {
      _model.controller.addAll(value);
      setState(() {
        _reading = false;
      });
    });
    super.initState();
  }

  getCookie() async {
    String token = await globals.storage.read(key: "token");
    String snsid = await globals.storage.read(key: "snsID");
    _cookie = "LOGINKEY="+token+"; LOGINID="+snsid;
    AppConstants.localUserId = "user_"+snsid;
  }

  addChatMessage(ChatWithMembers chat) {
    setState(() {
      _model.controller.insertAll(0, [chat]);
    });
  }

  /// Called from [NotificationListener] when the user scrolls
  void handleScrollEvent(ScrollNotification scroll) {
    if (scroll.metrics.pixels == scroll.metrics.maxScrollExtent) {
      //_model.getMoreChats();
    }
  }

  /// Called when the user pressed an item (a chat)
  void onItemPressed(ChatWithMembers chat) {
    //navigate to the chat
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => ChatScreen(ChatScreenArgs(chat: chat, model: _model, cookie: _cookie))));
    //reset unread count
    if (chat.isUnread) {
      chat.chat.unreadCount = 0;
    }
  }

  /// Called when the user long pressed an item (a chat)
  void onItemLongPressed(ChatWithMembers chat) {
    showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
              content: Text(
                  "This chat and any related message will be deleted permanently."),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      //delete in DB, from the current list in memory and update UI
                      _model.controller.removeItem(chat);
                    },
                    child: Text("ok")),
                Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text("cancel")),
                ),
              ]);
        });
  }

  /// Build the last message depending on how many members the Chat has
  /// and on the message type [ChatMessage.type]
  Widget _buildLastMessage(BuildContext context, int index, ChatBase item) {
    final _chat = item as ChatWithMembers;
    //display avatar only if not a 1 to 1 conversation
    final bool displayAvatar = item.members.length > 2;
    //display an icon if there's an attachment
    Widget attachmentIcon;
    if (_chat.lastMessage.hasAttachment) {
      final _type = _chat.lastMessage.type;
      final iconColor = AppColors.chatsAttachmentIconColor(context);
      if (_type == ChatMessageType.audio) {
        attachmentIcon = Icon(Icons.keyboard_voice, color: iconColor);
      } else if (_type == ChatMessageType.video) {
        attachmentIcon = Icon(Icons.videocam, color: iconColor);
      } else if (_type == ChatMessageType.image) {
        attachmentIcon = Icon(Icons.image, color: iconColor);
      }
    }

    //get the message label
    String messageText = _chat.lastMessage.messageText(_model.localUser.id);

    return Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(children: [
          if (displayAvatar)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: ClipOval(
                child:
                  //Image.asset(item.lastMessage.author.avatar,
                  //  width: 24, height: 24, fit: BoxFit.cover))),
                  item.lastMessage.author.avatar!=null ? Image(
                    image: NetworkImage(item.lastMessage.author.avatar, headers: {'Cookie': _cookie}),
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover
                  )
                  :Image.asset("images/avatars/local_user_avatar.png",
                      width: 24, height: 24, fit: BoxFit.cover))),
          if (attachmentIcon != null)
            Padding(padding: EdgeInsets.only(right: 8), child: attachmentIcon),
          Expanded(
              child: Text(
            messageText,
            overflow: TextOverflow.ellipsis,
          ))
        ]));
  }

  Widget _buildTileWrapper(
      BuildContext context, int index, ChatBase item, Widget child) {
    return InkWell(
        onTap: () => onItemPressed(item),
        onLongPress: () => onItemLongPressed(item),
        child: Column(children: [
          Padding(padding: EdgeInsets.only(right: 16), child: child),
          Divider(
            height: 1.5,
            thickness: 1.5,
            color: AppColors.chatsSeparatorLineColor(context),
            //56 default GroupAvatar size + 32 padding
            indent: 56.0 + 32.0,
            endIndent: 16.0,
          )
        ]));
  }

  @override
  Widget build(BuildContext context) {
    if(_reading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("メッセージ"),
          actions: <Widget>[],
          //automaticallyImplyLeading: false,
        ),
        /*
        drawer: new Drawer(
          child: ListView(
            children: <Widget>[
            ],
          ),
        ),
         */
        body: Center(
          child: const CircularProgressIndicator(),
        )
      );
    } else {
      return new Scaffold(
        appBar: AppBar(
          title: Text("メッセージ"),
          actions: <Widget>[],
          //automaticallyImplyLeading: false,
        ),
        drawerEdgeDragWidth: 0,
        drawer: MessageDrawer(model: _model, addChatMessage: addChatMessage),
        body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _reading = true;
                    });
                    await _model.sqlite3.delete('bt_user');
                    setState(() {
                      _model.chatUsers.clear();
                      _model.chatUsers.add(ChatViewModel.initialUser);
                      _model.readMemberList();
                      _reading = false;
                    });
                  },
                  child: ChatsList(
                    controller: _model.controller,
                    appUserId: _model.localUser.id,
                    scrollHandler: handleScrollEvent,
                    groupAvatarStyle: GroupAvatarStyle(
                      withSeparator: true, separatorColor: Colors.white),
                    builders: ChatsListTileBuilders(
                      groupAvatarBuilder:
                        (context, imageIndex, itemIndex, size, item) {
                        final chat = item as ChatWithMembers;
                        return Image(
                          image: NetworkImage(
                            chat.membersWithoutSelf[imageIndex].avatar,
                            headers: {'Cookie': _cookie}),
                            width: size.width,
                            height: size.height,
                            fit: BoxFit.cover
                        );
                      },
                    lastMessageBuilder: _buildLastMessage,
                    wrapper: _buildTileWrapper,
                    dateBuilder: (context, date) =>
                      Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Text(
                          DateFormatter.getVerboseDateTimeRepresentation(
                            context, date)))),
                    areItemsTheSame: (ChatBase oldItem, ChatBase newItem) {
                      if (oldItem == null || newItem == null)
                        return false;
                      return oldItem.id == newItem.id;
                    }))),
      ]));
    }
  }

  @override
  void dispose() {
    _model.controller.dispose();
    _model.sqlite3.close();
    super.dispose();
  }
}
