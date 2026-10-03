import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:reinos_server/relay_server.dart';
import 'package:reinos_server/room_registry.dart';
import 'package:reinos_server/server_content_repository.dart';

/// Entry point for the REINOS online-multiplayer relay (section 36/37).
/// Reads the port from `$PORT` (the convention every major host — Fly.io,
/// Render, Railway — injects), defaulting to 8080 for local runs.
Future<void> main(List<String> args) async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = RelayServer(rooms: RoomRegistry(), content: ServerContentRepository());

  final pipeline = const Pipeline().addMiddleware(logRequests()).addHandler(
    (Request request) {
      if (request.url.path == 'health') {
        return Response.ok('ok');
      }
      return server.handler(request);
    },
  );

  final httpServer = await shelf_io.serve(pipeline, InternetAddress.anyIPv4, port);
  print('REINOS relay server listening on ws://${httpServer.address.host}:${httpServer.port}');
}
