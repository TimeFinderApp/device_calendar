class RemList {
  String title;
  String id;
  int? color;

  RemList(this.title, {this.id = '', this.color});

  RemList.fromJson(json)
      : title = json['title'],
        id = json['id'],
        color = json['color'];

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'id': id,
      'color': color,
    };
  }
}
