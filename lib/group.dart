import 'dart:convert' show json;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:confirm_dialog/confirm_dialog.dart';

import 'globals.dart' as globals;

/*
class Model {
  final int id;
  String name;
  int seq;

  Model({
    @required this.id,
    @required this.name,
    @required this.seq,
  });
}
*/

class GroupPage extends StatefulWidget {
  GroupPage({Key key}) : super(key: key);

  @override
  _GroupPageState createState() => new _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  List<globals.GroupModel> _groups;

  @override
  void initState() {
    super.initState();
    _groups = [];
    getGroupList();
  }

  Future getGroupList() async {
    List<globals.GroupModel>groups = await globals.getGroupList(context);
    setState(() {
      _groups = groups;
    });
    /*
    String companyId = await globals.storage.read(key: "companyID");
    String sess = await globals.storage.read(key: "session");
    if (companyId != null && companyId.isNotEmpty) {
      String session = Uri.encodeQueryComponent(sess);
      var uri = "https://room.yourcompany.com/janusmobile/group_list.php?token=" +
          session + "&company=" + companyId;
      http.Response response = await http.get(Uri.parse(uri));
      if (response.statusCode != 200) {
        await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
        return false;
      }
      var groups = json.decode(response.body);
      if (groups['result'] != 0) {
        print(groups['result_string']);
        await globals.showPopupDialog(context: context, title: "エラー", content: groups['result_string'], cancel: "閉じる");
        return;
      }
      var mt = groups['groups'];
      setState(() {
        for (int i = 0; i < mt.length; ++i) {
          var group = mt[i] as Map<String, dynamic>;
          var id = group['group_id'];
          var name = group['group_name'];
          var seq = group['group_seq'];
          var model = Model(id: id, name: name, seq: seq);
          if (name != null) {
            _groups.add(model);
          }
        }
      });
    }
     */
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text("グループ編集"),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              addNewGroup();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          print('Loading New Data');
        },
        child: ReorderableListView(
          padding: EdgeInsets.all(10.0),
          /*
          header: Container(
            width: MediaQuery.of(context).size.width,
            color: Colors.grey,
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                "This is header",
                style: TextStyle(fontSize: 18.0),
              ),
            ),
          ),
           */
          onReorder: (oldIndex, newIndex) {
            if (oldIndex < newIndex) {
              // removing the item at oldIndex will shorten the list by 1.
              newIndex -= 1;
            }
            final globals.GroupModel oldModel = _groups.removeAt(oldIndex);

            setState(() {
              _groups.insert(newIndex, oldModel);
              for (int idx = 0; idx < _groups.length; idx++) {
                _groups[idx].seq = idx + 1;
              }
              setGroupOrder();
            });
          },
          //children: cards,
          children: _groups.map(
            (globals.GroupModel model) {
              return Card(
                elevation: 2.0,
                key: Key("card"+model.id.toString()),
                child: Dismissible(
                  key: Key("dismiss"+model.id.toString()),
                  background: Container(
                    color: Colors.yellow,
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(10.0, 0.0, 20.0, 0.0),
                      child: Icon(Icons.edit, color: Colors.blueAccent),
                    ),
                  ), // start to endの背景
                  secondaryBackground: Container(
                    color:Colors.red,
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(10.0, 0.0, 20.0, 0.0),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                  ), // end to startの背景
                  confirmDismiss: (direction) async {
                    if (direction != DismissDirection.endToStart) {
                      await changeGroupName(model.id.toString(), model.name);
                      return false;
                    }
                    if (await confirm(
                      context,
                      title: Text('グループ削除'),
                      content: Text('グループ「'+model.name+'」を削除しますか？'),
                      textOK: Text('はい'),
                      textCancel: Text('いいえ'),
                    )) {
                      if (await delGroupById(model.id.toString()) > 0) {
                        setState(() {
                          _groups.remove(model);
                        });
                        return true;
                      }
                    }
                    return false;
                  },
                  onDismissed: (direction) {
                    print(direction);
                    if (direction == DismissDirection.endToStart) {
                      print("end to start"); // (日本語だと)右から左のとき
                    } else {
                      print("start to end"); // (日本語だと?)左から右のとき
                    }
                  },
                  child: ListTile(
                    leading: const Icon(Icons.people),
                    title: Text(model.name),
                    onTap: () {
                    },
                  ),
                )
              );
            }
          ).toList(),
        )
      )
    );
  }

  Future<int> delGroupById(String idx) async {
    String session = Uri.encodeQueryComponent(await globals.storage.read(key: "session"));
    var uri = "https://room.yourcompany.com/janusmobile/delete_group.php?token=" + session + "&id="+idx;
    http.Response response = await http.get(Uri.parse(uri));
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
      return 0;
    }
    var groups = json.decode(response.body);
    if (groups['result'] != 0) {
      await globals.showPopupDialog(context: context, title: "エラー", content: groups['result_string'], cancel: "閉じる");
      return 0;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("グループを削除しました。"),
          backgroundColor: Colors.blueAccent,
          duration: Duration(seconds: 3, milliseconds: 500),
        ),
      );
    }
    return 1;
  }

  Future<int> setGroupOrder() async {
    String session = await globals.storage.read(key: "session");
    var map = Map<String, dynamic>();
    map['token'] = session;
    for (var i = 0; i < _groups.length; ++i) {
      map['order'+(i+1).toString()] = _groups[i].id.toString() + ':' + _groups[i].seq.toString();
    }
    final uri = "https://room.yourcompany.com/janusmobile/set_group_order.php";
    http.Response response = await http.post(Uri.parse(uri), body: map);
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
      return 0;
    }
    final meetings = json.decode(response.body);
    if (meetings['result'] != 0) {
      await globals.showPopupDialog(context: context, title: "エラー", content: meetings['result_string'], cancel: "閉じる");
      return 0;
    }
    return 1;
  }

  Future<int> addNewGroup() async {
    var textController = TextEditingController();
    String groupName = "";
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
              title: Text('グループ追加'),
              actions: <Widget>[
                TextButton(
                  child: Text('キャンセル'),
                  onPressed: () => Navigator.of(context).pop(0),
                ),
                TextButton(
                  child: Text('追加'),
                  onPressed: () {
                    newGroupName(groupName).then((val) => Navigator.of(context).pop(val));
                  },
                ),
              ],
              content: Container(
                width: double.maxFinite,
                //height: double.maxFinite,
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: '追加するグループの名前を指定してください',
                            style: TextStyle(
                              color: Colors.cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          enabled: true,
                          cursorColor: Colors.blueAccent,
                          controller: textController,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          onChanged: (value) {
                            groupName = value;
                          },
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          decoration: new InputDecoration(
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: Colors.grey, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: Colors.blueAccent, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: Colors.redAccent, width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                            ),
                            contentPadding: EdgeInsets.only(
                              left: 16,
                              bottom: 16,
                              top: 16,
                              right: 16,
                            ),
                            hintText: 'グループ名',
                            hintStyle: TextStyle(
                              color: Colors.grey.withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  Future<int> newGroupName(String name) async {
    String session = Uri.encodeQueryComponent(await globals.storage.read(key: "session"));
    var uri = "https://room.yourcompany.com/janusmobile/add_group.php?token=" +
        session + "&group=" + Uri.encodeQueryComponent(name);
    http.Response response = await http.get(Uri.parse(uri));
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
      return 0;
    }
    var groups = json.decode(response.body);
    if (groups['result'] != 0) {
      await globals.showPopupDialog(context: context, title: "エラー", content: groups['result_string'], cancel: "閉じる");
      return 0;
    }
    var gid = groups['group_id'];
    setState(() {
      for (var i = 0; i < _groups.length; i++) {
        if (_groups[i].id == gid) {
          _groups[i].name = name;
          break;
        }
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("グループを追加しました。"),
          backgroundColor: Colors.blueAccent,
          duration: Duration(seconds: 3, milliseconds: 500),
        ),
      );
    }
    return 1;
  }

  Future<int> changeGroupName(String idx, String name) async {
    var textController = TextEditingController();
    String groupName = name;
    textController.text = name;
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
              title: Text('グループ名変更'),
              actions: <Widget>[
                TextButton(
                  child: Text('キャンセル'),
                  onPressed: () => Navigator.of(context).pop(0),
                ),
                TextButton(
                  child: Text('変更'),
                  onPressed: () {
                    for (var i = 0; i < _groups.length; i++) {
                      if (_groups[i].name == groupName) {
                        globals.showPopupDialog(context: context, title: "エラー", content: "「"+groupName+"」はすでに存在します", cancel: "閉じる");
                        return;
                      }
                    }
                    chgGroupName(idx, groupName).then((val) => Navigator.of(context).pop(val));
                  },
                ),
              ],
              content: Container(
                width: double.maxFinite,
                //height: double.maxFinite,
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: 'グループの名前を指定してください',
                            style: TextStyle(
                              color: Colors.cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          enabled: true,
                          cursorColor: Colors.blueAccent,
                          controller: textController,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          onChanged: (value) {
                            groupName = value;
                          },
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          decoration: new InputDecoration(
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: Colors.grey, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: Colors.blueAccent, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: Colors.redAccent, width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                            ),
                            contentPadding: EdgeInsets.only(
                              left: 16,
                              bottom: 16,
                              top: 16,
                              right: 16,
                            ),
                            hintText: 'グループ名',
                            hintStyle: TextStyle(
                              color: Colors.grey.withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  Future<int> chgGroupName(String idx, String name) async {
    String session = Uri.encodeQueryComponent(await globals.storage.read(key: "session"));
    var uri = "https://room.yourcompany.com/janusmobile/change_group_name.php?token=" +
        session + "&id="+idx+"&group=" + Uri.encodeQueryComponent(name);
    http.Response response = await http.get(Uri.parse(uri));
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
      return 0;
    }
    var groups = json.decode(response.body);
    if (groups['result'] != 0) {
      await globals.showPopupDialog(context: context, title: "エラー", content: groups['result_string'], cancel: "閉じる");
      return 0;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("グループ名を変更しました。"),
          backgroundColor: Colors.blueAccent,
          duration: Duration(seconds: 3, milliseconds: 500),
        ),
      );
    }
    setState(() {
      for (var i = 0; i < _groups.length; i++) {
        if (i.toString() == idx) {
          _groups[i].name = name;
          break;
        }
      }
    });
    return 1;
  }
}