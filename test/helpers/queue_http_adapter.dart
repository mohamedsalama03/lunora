import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef AdapterResponse = ({int statusCode, Object? body});

class QueueHttpAdapter implements HttpClientAdapter {
  final List<AdapterResponse Function(RequestOptions)> _responders;
  final List<RequestOptions> requests = <RequestOptions>[];

  QueueHttpAdapter(List<AdapterResponse Function(RequestOptions)> responders)
    : _responders = List.of(responders);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_responders.isEmpty) {
      throw StateError(
        'No queued response for ${options.method} ${options.path}',
      );
    }

    final response = _responders.removeAt(0)(options);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
