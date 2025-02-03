import 'package:flutter/material.dart';
import '../helpers/launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Item {
  String title;
  String ussCode;

  Item({required this.title, required this.ussCode});

  Map<String, dynamic> toJson() => {'title': title, 'ussCode': ussCode};

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(title: json['title'], ussCode: json['ussCode']);
  }
}

class CodesPage extends StatefulWidget {
  @override
  _CodesPageState createState() => _CodesPageState();
}

class _CodesPageState extends State<CodesPage> {
  List<Item> items = [];
  List<Item> filteredItems = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadItems();
    searchController.addListener(() {
      filterItems();
    });
  }

  Future<void> saveItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> jsonList =
        items.map((item) => json.encode(item.toJson())).toList();
    await prefs.setStringList('items', jsonList);
  }

  Future<void> loadItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? jsonList = prefs.getStringList('items');
    if (jsonList != null) {
      setState(() {
        items =
            jsonList.map((item) => Item.fromJson(json.decode(item))).toList();
        filterItems();
      });
    }
  }

  void filterItems() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredItems = items
          .where((item) =>
              item.title.toLowerCase().contains(query) ||
              item.ussCode.toLowerCase().contains(query))
          .toList();
    });
  }

  void addItem() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController titleController = TextEditingController();
        TextEditingController ussCodeController = TextEditingController();
        return AlertDialog(
          title: Text("Add New USSD Code"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: "Title"),
              ),
              TextField(
                controller: ussCodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "USSD Code"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  items.add(Item(
                      title: titleController.text,
                      ussCode: ussCodeController.text));
                  saveItems();
                  filterItems();
                });
                Navigator.pop(context);
              },
              child: Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void editItem(int index) {
    TextEditingController titleController =
        TextEditingController(text: filteredItems[index].title);
    TextEditingController ussCodeController =
        TextEditingController(text: filteredItems[index].ussCode);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Item"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: "Title"),
              ),
              TextField(
                controller: ussCodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "USSD Code"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  items[index] = Item(
                      title: titleController.text,
                      ussCode: ussCodeController.text);
                  saveItems();
                  filterItems();
                });
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void deleteItem(int index) {
    Item deletedItem = items[index];
    setState(() {
      items.removeAt(index);
      saveItems();
      filterItems();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Item deleted"),
        action: SnackBarAction(
          label: "Undo",
          onPressed: () {
            setState(() {
              items.insert(index, deletedItem);
              saveItems();
              filterItems();
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Text("No items available",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)))
                : ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      return Dismissible(
                        key: Key(filteredItems[index].title),
                        background: Container(
                            color: Colors.red,
                            child: Icon(Icons.delete, color: Colors.white)),
                        onDismissed: (direction) {
                          deleteItem(index);
                        },
                        child: Card(
                          margin:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ListTile(
                            title: Text(filteredItems[index].title,
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(filteredItems[index].ussCode),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => editItem(index),
                                ),
                                IconButton(
                                  icon: Icon(Icons.call, color: Colors.green),
                                  onPressed: () {
                                    launchUSSD(
                                        filteredItems[index].ussCode, context);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addItem,
        child: Icon(Icons.add),
      ),
    );
  }
}
