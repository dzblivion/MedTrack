import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/formatos.dart';
import 'package:frontend/features/mia/anuncio_premiado.dart';
import 'package:frontend/features/mia/medicamento_lido.dart';

import 'helpers.dart';

/// Fluxo da MIA: câmera (sem câmera nos testes, então escolhe arquivo) →
/// janela do anúncio → leitura → revisar cada remédio no formulário.
void main() {
  final daquiUmaHora = DateTime.now().add(const Duration(hours: 1));
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);

  // Um PNG de 1x1 pixel: a MIA falsa não olha o conteúdo, mas a tela mostra.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8'
    'AAAAASUVORK5CYII=',
  );
  Future<({Uint8List bytes, String nome})?> umaFoto() async =>
      (bytes: png, nome: 'receita.png');

  const amoxicilina = MedicamentoLido(
    medicamento: 'Amoxicilina',
    dosagemValor: 500,
    dosagemUnidade: 'mg',
    quantidadePorDose: 1,
    formaConsumo: 'oral',
    frequenciaTexto: 'de 8 em 8 horas',
    duracaoTexto: 'por 7 dias',
    camposDuvidosos: ['quantidade_por_dose'],
  );
  const colirio = MedicamentoLido(medicamento: 'Colírio X');

  Future<void> abrirCamera(
    WidgetTester tester, {
    MiaFake? mia,
    AnuncioFake? anuncio,
    TratamentoFake? tratamentos,
  }) =>
      abrirApp(
        tester,
        storage: storageComSessao(daquiUmaHora),
        mia: mia,
        anuncio: anuncio,
        tratamentos: tratamentos,
        escolherArquivo: umaFoto,
        rota: Rotas.mia,
      );

  /// Escolhe a foto e toca em "Usar esta foto" (abre a janela da MIA).
  Future<void> usarFoto(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Escolher foto ou PDF'));
    await tester.pumpAndSettle();
    await tocar(tester, 'Usar esta foto');
  }

  testWidgets('sem câmera, avisa e deixa escolher um arquivo', (tester) async {
    await abrirCamera(tester);

    expect(find.text('Digitalizar prescrição'), findsOneWidget);
    expect(find.textContaining('Câmera indisponível'), findsOneWidget);

    await tester.tap(find.byTooltip('Escolher foto ou PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Usar esta foto'), findsOneWidget);
    await tocar(tester, 'Tirar outra');
    expect(find.text('Usar esta foto'), findsNothing);
  });

  testWidgets('assistir ao anúncio manda a foto e mostra o que a MIA leu', (
    tester,
  ) async {
    final mia = MiaFake(
      const ResultadoMia(
        textoExtraido: 'Amoxicilina 500 mg...',
        medicamentos: [amoxicilina, colirio],
      ),
    );
    final anuncio = AnuncioFake();
    await abrirCamera(tester, mia: mia, anuncio: anuncio);

    await usarFoto(tester);
    expect(find.text('Assista a um anúncio para ganhar uma análise com a MIA.'),
        findsOneWidget);

    await tocar(tester, 'Assistir anúncio');

    expect(anuncio.exibicoes, 1);
    expect(mia.enviados, ['receita.png']);
    expect(find.text('A MIA encontrou 2 medicamentos.'), findsOneWidget);
    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('500 mg · Oral · de 8 em 8 horas'), findsOneWidget);
    expect(find.text('1 campo para conferir'), findsOneWidget);
    expect(find.text('Colírio X'), findsOneWidget);
  });

  testWidgets('enquanto a MIA lê, mostra quanto tempo já passou', (
    tester,
  ) async {
    final mia = _MiaLenta();
    await abrirCamera(tester, mia: mia);

    await usarFoto(tester);
    await tester.tap(find.text('Assistir anúncio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('A MIA está lendo sua receita...'), findsOneWidget);
    expect(find.text('Isso pode levar até 1 minuto.'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('0:03'), findsOneWidget);

    mia.terminar();
    await tester.pumpAndSettle();
    expect(find.text('A MIA encontrou 1 medicamento.'), findsOneWidget);
  });

  testWidgets('sair do anúncio antes do fim não manda para a MIA', (
    tester,
  ) async {
    final mia = MiaFake();
    await abrirCamera(tester, mia: mia, anuncio: AnuncioFake(assistiu: false));

    await usarFoto(tester);
    await tocar(tester, 'Assistir anúncio');

    expect(mia.enviados, isEmpty);
    expect(find.text('Usar esta foto'), findsOneWidget);
  });

  testWidgets('revisar um remédio: formulário preenchido e salvo', (
    tester,
  ) async {
    final tratamentos = TratamentoFake();
    await abrirCamera(
      tester,
      tratamentos: tratamentos,
      mia: MiaFake(
        const ResultadoMia(textoExtraido: '', medicamentos: [amoxicilina]),
      ),
    );
    await usarFoto(tester);
    await tocar(tester, 'Assistir anúncio');

    await tocar(tester, 'Revisar ›');

    // Etapa 1: preenchida, com o aviso do que conferir.
    expect(find.text('Revisar tratamento'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Amoxicilina'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '500'), findsOneWidget);
    expect(find.textContaining('Preenchido pela MIA'), findsOneWidget);
    expect(find.text('Confira com atenção: quantidade por dose.'),
        findsOneWidget);
    await tocar(tester, 'Continuar');

    // Etapa 2: "de 8 em 8 horas" virou "Em intervalos", a cada 8 horas.
    expect(find.text('Na receita: "de 8 em 8 horas"'), findsOneWidget);
    expect(find.text('Em intervalos'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '8'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    await tocar(tester, 'Continuar');

    // Etapa 3: "por 7 dias".
    expect(find.text('Na receita: "por 7 dias"'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '7'), findsOneWidget);
    await tocar(tester, 'Salvar tratamento');

    final dataApi = formatarDataApi(hoje);
    expect(tratamentos.criado, {
      'medicamento': 'Amoxicilina',
      'dosagem_valor': 500.0,
      'dosagem_unidade': 'mg',
      'quantidade_por_dose': 1.0,
      'forma_consumo': 'oral',
      'data_inicio': dataApi,
      'duracao_dias': 7,
      'frequencia': {
        'tipo': 'intervalo_horas',
        'ancora_em': '${dataApi}T08:00:00-03:00',
        'horarios': <String>[],
        'dias_semana': <int>[],
        'intervalo_valor': 8,
      },
    });

    // Confirma e volta para a leitura (pode haver outros remédios),
    // com o remédio marcado.
    expect(find.text('Tratamento cadastrado!'), findsOneWidget);
    await tocar(tester, 'Continuar');
    expect(find.text('Cadastrado'), findsOneWidget);
    expect(find.text('Revisar ›'), findsNothing);
  });

  testWidgets('se a MIA falhar, dá para tentar de novo sem outro anúncio', (
    tester,
  ) async {
    final mia = MiaFake(
      const ResultadoMia(textoExtraido: '', medicamentos: [colirio]),
    )..erro = const ApiException('Não foi possível ler a prescrição.', 500);
    final anuncio = AnuncioFake();
    await abrirCamera(tester, mia: mia, anuncio: anuncio);

    await usarFoto(tester);
    await tocar(tester, 'Assistir anúncio');

    expect(find.text('A MIA não conseguiu ler'), findsOneWidget);
    expect(find.text('Não foi possível ler a prescrição.'), findsOneWidget);

    await tocar(tester, 'Tentar de novo');

    expect(anuncio.exibicoes, 1);
    expect(mia.enviados, hasLength(2));
    expect(find.text('Colírio X'), findsOneWidget);
  });

  testWidgets('cadastrar manualmente abre o formulário vazio', (tester) async {
    await abrirCamera(tester);

    await usarFoto(tester);
    await tocar(tester, 'Cadastrar manualmente');

    expect(find.text('Novo tratamento'), findsOneWidget);
    expect(find.textContaining('Preenchido pela MIA'), findsNothing);
  });

  testWidgets('Conheça o MedTrack Plus abre o plano, só visual', (
    tester,
  ) async {
    final mia = MiaFake();
    await abrirCamera(tester, mia: mia);

    await usarFoto(tester);
    await tocar(tester, 'Conheça o MedTrack Plus');

    expect(find.text('Assinar o Plus'), findsOneWidget);
    await tocar(tester, 'Assinar o Plus');
    expect(find.text('A assinatura chega em breve!'), findsOneWidget);
    expect(mia.enviados, isEmpty);
  });

  testWidgets('receita sem remédios mostra como tentar de novo', (
    tester,
  ) async {
    await abrirCamera(tester);

    await usarFoto(tester);
    await tocar(tester, 'Assistir anúncio');

    expect(find.text('A MIA não encontrou medicamentos nesta imagem.'),
        findsOneWidget);
    expect(find.text('Tirar outra foto'), findsOneWidget);
  });

  testWidgets('o anúncio simulado só dá a recompensa no fim', (tester) async {
    bool? assistiu;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                assistiu = await const AnuncioSimulado(segundos: 3)
                    .exibir(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Recompensa em 3s'), findsOneWidget);
    expect(find.byTooltip('Fechar anúncio'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byTooltip('Fechar anúncio'));
    await tester.pumpAndSettle();

    expect(assistiu, isTrue);
  });
}

/// MIA que só responde quando o teste mandar (para ver o "lendo...").
class _MiaLenta extends MiaFake {
  final _resposta = Completer<ResultadoMia>();

  void terminar() => _resposta.complete(
        const ResultadoMia(
          textoExtraido: '',
          medicamentos: [MedicamentoLido(medicamento: 'Dipirona')],
        ),
      );

  @override
  Future<ResultadoMia> lerPrescricao({
    required List<int> bytes,
    required String nomeArquivo,
  }) =>
      _resposta.future;
}
