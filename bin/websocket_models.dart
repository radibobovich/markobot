abstract class Request {
  abstract final String command;
  Request();
}

abstract class Response {
  abstract final String command;
  Response();

  factory Response.fromJson(Map<String, dynamic> json) {
    switch (json['command']) {
      case 'generate':
        return GenerationResponse.fromJson(json);
      default:
        throw Exception('Unknown command');
    }
  }
}

class GenerationRequest extends Request {
  @override
  final String command = 'generate';

  GenerationRequest();

  Map<String, dynamic> toJson() {
    return {'command': command};
  }
}

class GenerationResponse extends Response {
  @override
  final String command = 'generate';
  final String text;

  GenerationResponse(this.text);

  // from json
  GenerationResponse.fromJson(Map<String, dynamic> json) : text = json['text'];
}

class SaveToDatasetRequest extends Request {
  @override
  final String command = 'save';
  final String text;

  SaveToDatasetRequest(this.text);

  Map<String, dynamic> toJson() {
    return {'command': command, 'text': text};
  }
}
