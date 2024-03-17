// ignore_for_file: constant_identifier_names, non_constant_identifier_names
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:teledart/model.dart' hide Response, File;
import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';

import 'websocket_models.dart';

/// токен читаем из файла token.txt
late final String BOT_TOKEN;

/// сколько постов кэшировать перед сохранением в датасет
const CACHE_SIZE = 100;

/// ключевое слово для триггера бота
const BOT_CALL_SIGN = 'бот';

/// отвечает на любое упоминание
const ALWAYS_TRIGGER = true;

const CHANNEL_ID = '-1001834786446';
const CHAT_ID = '-1001749440202';
const bool useChat = true;
final int WORKING_ID = useChat ? int.parse(CHAT_ID) : int.parse(CHANNEL_ID);

const BOT_NAME = 'Голос Кабинки';
late final WebSocket socket;
late final TeleDart teledart;

/// сюда будем класть посты из канала
List<String> cachedMessages = [];

/// id поста, на который надо отвечать
/// пишем в это поле, когда видим упоминание бота
int? replyTomessageId;

/// пришел пост - добавляем в кэш
/// пришел пост с упоминанием бота - отвечаем сгенерированным текстом
/// каждые CACHE_SIZE постов отправляем марковифи на сохранение в датасет
void onMessage(Message message) {
  if (message.text == null) return;
  print('Channel post: ${message.text}');
  if (ALWAYS_TRIGGER || message.text!.contains(BOT_CALL_SIGN)) {
    replyTomessageId = message.messageId;
    requestGeneratedText();
  }

  final signature = message.authorSignature ?? '';
  final forwarded = message.forwardFrom?.isBot ?? false;
  if (!signature.contains(BOT_NAME) && !forwarded && message.text != 'бот') {
    print('Adding to cache: ${message.text}');
    cachedMessages.add(message.text!);
  }

  if (cachedMessages.length >= CACHE_SIZE) {
    saveMessagesToDataset();
    cachedMessages.clear();
  }
}

/// объединяем все посты в один текст и отправляем на сервер
void saveMessagesToDataset() {
  final String text = cachedMessages.join('\n');
  final request = SaveToDatasetRequest(text);
  socket.add(jsonEncode(request.toJson()));
  print('Sent to dataset');
}

/// подключаемся к марковифи и слушаем ответы
Future<void> initializeWebsocket() async {
  socket = await WebSocket.connect('ws://127.0.0.1:8765');
  print('Connected to server');

  // слушаем ответы от марковифи
  socket.listen((dynamic data) async {
    onWebsocketResponse(data);
  });

  socket.done.then((_) {
    print('Connection to server closed');
  }).catchError((error) {
    print('Error: $error');
  });
}

// думаем что делать с ответом от марковифи
// если это сгенерированный текст - отправляем в канал
// если это что-то другое - пока ничего не делаем
void onWebsocketResponse(dynamic data) async {
  print('Received data from server');
  final response = Response.fromJson(jsonDecode(data));
  if (response is GenerationResponse) {
    try {
      final messageSent = await teledart.sendMessage(WORKING_ID, response.text,
          replyToMessageId: replyTomessageId);
      replyTomessageId = null;
      print('Message sent to channel: ${messageSent.text.toString()}');
    } catch (e) {
      print('Error sending message: ${e.toString()}');
    }
  }
}

// запрашиваем у марковифи сгенерированный текст
void requestGeneratedText() {
  final request = GenerationRequest();
  socket.add(jsonEncode(request.toJson()));
}

// запускаем вебсокет и телеграм бота
void main(List<String> arguments) async {
  await initializeWebsocket();

  BOT_TOKEN = File('token.txt').readAsStringSync();
  final username = (await Telegram(BOT_TOKEN).getMe()).username;
  teledart = TeleDart(BOT_TOKEN, Event(username!));
  teledart.start();

  teledart.onChannelPost().listen((message) {
    if (useChat) return;
    onMessage(message);
  });
  teledart.onMessage().listen((message) {
    if (!useChat) return;
    if (message.chat.id != WORKING_ID) {
      return;
    }
    onMessage(message);
  });

  Timer.periodic(Duration(seconds: 10), (timer) {
    // requestGeneratedText();
  });
}
