import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:random_string/random_string.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import 'package:chat_ui_kit/chat_ui_kit.dart' hide ChatMessageImage;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/chat.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../ui/chat_viewmodel.dart';
import '../utils/date_formatter.dart';
import '../utils/switch_appbar.dart';
import '../utils/chat_message_image.dart';
import '../utils/chat_message_other.dart';

//import '../../webview.dart';
//import '../../video.dart';
import '../../pdftron.dart';
import '../../globals.dart' as globals;

part 'chat_screen.g.dart';

class ChatScreenArgs {
  /// Pass the chat for an already existing chat
  final ChatWithMembers chat;
  final ChatViewModel model;
  final String cookie;

  ChatScreenArgs({this.chat, this.model, this.cookie}) : assert(chat != null);
}

class ChatScreen extends StatefulWidget {
  final ChatScreenArgs args;

  ChatScreen(this.args);

  @override
  _ChatScreenSate createState() => _ChatScreenSate();
}

class _ChatScreenSate extends State<ChatScreen> with TickerProviderStateMixin {
  //final ChatViewModel _model = ChatViewModel();
  String get _cookie => widget.args.cookie;

  final TextEditingController _textController = TextEditingController();

  /// The data controller
  final MessagesListController _controller = MessagesListController();

  /// Whether at least 1 message is selected
  int _selectedItemsCount = 0;

  ChatViewModel get _model => widget.args.model;

  /// Whether it's a group chat (more than 2 users)
  bool get _isGroupChat => (widget.args.chat?.members?.length ?? 0) > 2;

  ChatWithMembers get _chat => widget.args.chat;

  ChatUser get _currentUser => _model.localUser;

  @override
  void initState() {
    _controller.addAll(_model.chatMessages[_chat.id]);

    _controller.selectionEventStream.listen((event) {
      setState(() {
        _selectedItemsCount = event.currentSelectionCount;
      });
    });

    super.initState();
  }

  getUnread() async {
    var mess = await _model.readMemberListForUser(_chat.membersWithoutSelf.first, all: false);
    if (mess != null)
      _model.chatMessages[_chat.membersWithoutSelf.first.id].insertAll(0, mess);
  }

  /// Called when the user pressed the top right corner icon
  void onChatDetailsPressed() {
    print("Chat details pressed");
  }

  /// Called when a user tapped an item
  void onItemPressed(int index, MessageBase message) {
    print(
        "item pressed, you could display images in full screen or play videos with this callback");
    final _chatMessage = message as ChatMessage;
    readFileURL(_chatMessage).then((value) => {
      if (value != null) {
        Navigator.of(context).push(MaterialPageRoute(
        builder: (context) =>
            PdfPage(
                filePath: value,
                fileName: _chatMessage.fileName,)))
      }
    });
    /*
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) =>
            MyWebView(
                fileUrl: _chatMessage.attachment,
                fileName: _chatMessage.fileName,
                cookie: _cookie)));
     */
    /*
    if (_chatMessage.mimeType.indexOf('image/') >= 0) {
      //Navigator.of(context).push(MaterialPageRoute(
      //    builder: (context) => ImagePage(
      //        imageUrl: _chatMessage.attachment, cookie: _cookie)));
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) =>
            PdfPage(
              fileUrl: _chatMessage.attachment,
              fileName: _chatMessage.fileName,
              cookie: _cookie)));
    } else if (_chatMessage.mimeType.indexOf('video/') >= 0) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) =>
              VideoPage(
                  videoUrl: _chatMessage.attachment,
                  videoName: _chatMessage.fileName,
                  cookie: _cookie)));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) =>
              PdfPage(
                  fileUrl: _chatMessage.attachment,
                  fileName: _chatMessage.fileName,
                  cookie: _cookie)));
    }
     */
  }

  Future<String>readFileURL(ChatMessage message) async {
    var uri = Uri.parse(message.attachment);
    http.Response response = await http.get(uri, headers: {'Cookie': _cookie});
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: context, title: 'エラー', content: 'ファイルを読み込めませんでした', cancel: '閉じる');
      return null;
    }
    var pairs = message.fileName.split(".");
    var types = message.mimeType.split('/');
    var fileName = randomAlpha(8)+'.'+(pairs.length>0?pairs[1]:types[1]);
    String dirName;
    if (defaultTargetPlatform == TargetPlatform.android) {
      dirName = (await getExternalStorageDirectory()).path+'/janusmobile/temp';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      dirName = (await getApplicationDocumentsDirectory()).path+'/janusmobile/temp';
    }
    Directory dir = Directory(dirName);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    var fp = "${dir.path}/$fileName";
    File file = File(fp);
    if (await File(fp).exists()) {
      await file.delete();
    }
    await file.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes.buffer.asUint8List(), flush: true);
    return fp;
  }

  void onMessageSend(String text) {
    final _mess = ChatMessage(
        author: _currentUser,
        owner: _chat.membersWithoutSelf.first,
        text: text,
        creationTimestamp: DateTime.now());
    _controller.insertAll(0, [_mess]);
    _model.chatMessages[_chat.membersWithoutSelf.first.id].insert(0, _mess);
    _chat.membersWithoutSelf.first.lastPost = DateTime.now();
    _model.sqlite3.update(
      'bt_user',
      _chat.membersWithoutSelf.first.toMap(),
      where: "c_id = ?",
      whereArgs: [_chat.membersWithoutSelf.first.id],
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
    _model.sqlite3.insert(
      'bt_message',
      _mess.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void onTypingEvent(TypingEvent event) {
    print("typing event received: $event");
  }

  /// Copy the selected comment's comment to the clipboard.
  /// Reset selection once copied.
  void copyContent() {
    String text = "";
    _controller.selectedItems.forEach((element) {
      text += element.text;
      text += '\n';
    });
    Clipboard.setData(ClipboardData(text: text)).then((value) {
      print("text selected");
      _controller.unSelectAll();
    });
  }

  void deleteSelectedMessages() {
    _controller.removeSelectedItems();
    //update app bar
    setState(() {});
  }

  Widget _buildChatTitle() {
    if (_isGroupChat) {
      return Text(_chat.name);
    } else {
      final _user = _chat.membersWithoutSelf.first;
      return Row(children: [
        ClipOval(
            child:
                //Image.asset(_user.avatar,
                //  width: 32, height: 32, fit: BoxFit.cover)),
                Image(
                  image: NetworkImage(_user.avatar, headers: {'Cookie': _cookie}),
                  width: 32, height: 32, fit: BoxFit.cover)),
        Expanded(
            child: Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(_user.username, overflow: TextOverflow.ellipsis)))
      ]);
    }
  }

  Widget _buildMessageBody(
      context, index, item, messagePosition, MessageFlow messageFlow) {
    final _chatMessage = item as ChatMessage;
    Widget _child;

    if (_chatMessage.type == ChatMessageType.text) {
      _child = _ChatMessageText(index, item, messagePosition, messageFlow);
    } else if (_chatMessage.type == ChatMessageType.image) {
      if (_chatMessage.mimeType.indexOf('image/') >= 0) {
        _child = ChatMessageImage(index, item, messagePosition, messageFlow,
            cookie: _cookie, callback: () => onItemPressed(index, item));
      } else {
        _child = ChatMessageOther(index, item, messagePosition, messageFlow,
            callback: () => onItemPressed(index, item));
      }
    } else if (_chatMessage.type == ChatMessageType.video) {
      _child = ChatMessageVideo(index, item, messagePosition, messageFlow);
    } else if (_chatMessage.type == ChatMessageType.audio) {
      _child = ChatMessageAudio(index, item, messagePosition, messageFlow);
    } else {
      //return text message as default
      //_child = _ChatMessageText(index, item, messagePosition, messageFlow);
      _child = ChatMessageOther(index, item, messagePosition, messageFlow,
          callback: () => onItemPressed(index, item));
    }

    if (messageFlow == MessageFlow.incoming) return _child;
    return SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Align(alignment: Alignment.centerRight, child: _child));
  }

  Widget _buildDate(BuildContext context, DateTime date) {
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Align(
                child: Text(
                    DateFormatter.getVerboseDateTimeRepresentation(
                        context, date),
                    style:
                        TextStyle(color: Theme.of(context).disabledColor)))));
  }

  Widget _buildEventMessage(context, animation, index, item, messagePosition) {
    final _chatMessage = item as ChatMessage;
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Align(
                child: Text(
              _chatMessage.messageText(_currentUser.id),
              style: TextStyle(color: Theme.of(context).disabledColor),
              textAlign: TextAlign.center,
            ))));
  }

  Widget _buildMessagesList() {
    IncomingMessageTileBuilders incomingBuilders = _isGroupChat
        ? IncomingMessageTileBuilders(
            bodyBuilder: (context, index, item, messagePosition) =>
                _buildMessageBody(context, index, item, messagePosition,
                    MessageFlow.incoming),
            avatarBuilder: (context, index, item, messagePosition) {
              final _chatMessage = item as ChatMessage;
              return Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: ClipOval(
                      child:
                        //Image.asset(_chatMessage.author.avatar,
                        //  width: 32, height: 32, fit: BoxFit.cover)));
                        Image(
                            image: NetworkImage(_chatMessage.author.avatar, headers: {'Cookie': _cookie}),
                            width: 32, height: 32, fit: BoxFit.cover)));
            })
        : IncomingMessageTileBuilders(
            bodyBuilder: (context, index, item, messagePosition) =>
                _buildMessageBody(context, index, item, messagePosition,
                    MessageFlow.incoming),
            titleBuilder: null);

    return Expanded(
        child: RefreshIndicator(
            onRefresh: () async {
              print('Loading New Data');
              //await _loadData();
              await _model.sqlite3.delete(
                'bt_message',
                where: "c_owner = ?",
                whereArgs: [_chat.membersWithoutSelf.first.user],
              );
              var messages = await _model.readMemberListForUser(_chat.membersWithoutSelf.first, all: true);
              if (messages != null) {
                setState(() {
                  _controller.insertAll(0, messages);
                  _model.chatMessages[_chat.membersWithoutSelf.first.id] =
                      messages;
                });
              }
            },
            child: MessagesList(
                controller: _controller,
                appUserId: _currentUser.id,
                useCustomTile: (i, item, pos) {
                  final msg = item as ChatMessage;
                  return msg.isTypeEvent;
                },
                messagePosition: _messagePosition,
                builders: MessageTileBuilders(
                    customTileBuilder: _buildEventMessage,
                    customDateBuilder: _buildDate,
                    incomingMessageBuilders: incomingBuilders,
                    outgoingMessageBuilders: OutgoingMessageTileBuilders(
                        bodyBuilder: (context, index, item, messagePosition) =>
                            _buildMessageBody(context, index, item, messagePosition,
                                MessageFlow.outgoing)))))
    );
  }

  /// Override [MessagePosition] to return [MessagePosition.isolated] when
  /// our [ChatMessage] is an event
  MessagePosition _messagePosition(
      MessageBase previousItem,
      MessageBase currentItem,
      MessageBase nextItem,
      bool Function(MessageBase currentItem) shouldBuildDate) {
    ChatMessage _previousItem = previousItem;
    final ChatMessage _currentItem = currentItem;
    ChatMessage _nextItem = nextItem;

    if (shouldBuildDate(_currentItem)) {
      _previousItem = null;
    }

    if (_nextItem?.isTypeEvent == true) _nextItem = null;
    if (_previousItem?.isTypeEvent == true) _previousItem = null;

    if (_previousItem?.author?.id == _currentItem?.author?.id &&
        _nextItem?.author?.id == _currentItem?.author?.id) {
      return MessagePosition.surrounded;
    } else if (_previousItem?.author?.id == _currentItem?.author?.id &&
        _nextItem?.author?.id != _currentItem?.author?.id) {
      return MessagePosition.surroundedTop;
    } else if (_previousItem?.author?.id != _currentItem?.author?.id &&
        _nextItem?.author?.id == _currentItem?.author?.id) {
      return MessagePosition.surroundedBot;
    } else {
      return MessagePosition.isolated;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: SwitchAppBar(
          showSwitch: _controller.isSelectionModeActive,
          switchLeadingCallback: () => _controller.unSelectAll(),
          primaryAppBar: AppBar(
            title: _buildChatTitle(),
            actions: [
              IconButton(
                  icon: Icon(Icons.more_vert), onPressed: onChatDetailsPressed)
            ],
          ),
          switchTitle: Text(_selectedItemsCount.toString(),
              style: TextStyle(color: Colors.black)),
          switchActions: [
            IconButton(
                icon: Icon(Icons.content_copy),
                color: Colors.black,
                onPressed: copyContent),
            IconButton(
                color: Colors.black,
                icon: Icon(Icons.delete),
                onPressed: deleteSelectedMessages),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessagesList(),
            MessageInput(
                textController: _textController,
                sendCallback: onMessageSend,
                typingCallback: onTypingEvent),
          ],
        ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }
}

///************************************************ Functional widgets used in the screen ***************************************

@swidget
Widget _chatMessageText(BuildContext context, int index, ChatMessage message,
    MessagePosition messagePosition, MessageFlow messageFlow) {
  return MessageContainer(
      decoration: messageDecoration(context,
          messagePosition: messagePosition, messageFlow: messageFlow),
      child: Wrap(runSpacing: 4.0, alignment: WrapAlignment.end, children: [
        Text(message.text),
        ChatMessageFooter(index, message, messagePosition, messageFlow)
      ]));
}

@swidget
Widget chatMessageFooter(BuildContext context, int index, ChatMessage message,
    MessagePosition messagePosition, MessageFlow messageFlow) {
  final Widget _date = _ChatMessageDate(index, message, messagePosition);
  return messageFlow == MessageFlow.incoming
      ? _date
      : Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
              _date,
            ]);
}

@swidget
Widget _chatMessageDate(BuildContext context, int index, ChatMessage message,
    MessagePosition messagePosition) {
  final color =
      message.isTypeMedia ? Colors.white : Theme.of(context).disabledColor;
  return Padding(
      padding: EdgeInsets.only(left: 8),
      child: Text(
          DateFormatter.getVerboseDateTimeRepresentation(
              context, message.createdAt,
              timeOnly: true),
          style: TextStyle(color: color)));
}
