// No celular (dart:io) registra a dose com o app fechado; no navegador não
// há botões na notificação, então a versão vazia basta.
export 'segundo_plano_web.dart' if (dart.library.io) 'segundo_plano_io.dart';
