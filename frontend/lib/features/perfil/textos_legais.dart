// Rascunho para o projeto acadêmico: revisar antes de qualquer uso real.

typedef SecaoTexto = ({String titulo, String texto});

const termosDeUso = <SecaoTexto>[
  (
    titulo: 'Sobre o MedTrack',
    texto:
        'O MedTrack é um aplicativo acadêmico, desenvolvido como projeto '
        'integrador, para organizar tratamentos, acompanhar doses e consultar '
        'o histórico de uso de medicamentos.',
  ),
  (
    titulo: 'Não substitui orientação médica',
    texto:
        'As informações do app, incluindo as sugestões da MIA, não são '
        'diagnóstico nem prescrição. Siga sempre a orientação do seu '
        'profissional de saúde. Em caso de emergência, procure atendimento.',
  ),
  (
    titulo: 'Sua conta',
    texto:
        'Você é responsável por cadastrar dados verdadeiros, manter sua senha '
        'em segredo e conferir os tratamentos que cadastra.',
  ),
  (
    titulo: 'Assistente MIA',
    texto:
        'A MIA usa inteligência artificial para ler receitas e sugerir os '
        'dados do tratamento. Ela pode errar: revise tudo antes de salvar.',
  ),
  (
    titulo: 'Profissionais de saúde',
    texto:
        'Quem se cadastra como profissional deve informar um registro válido. '
        'O acesso aos dados de um paciente depende da autorização dele.',
  ),
  (
    titulo: 'Alterações',
    texto:
        'Estes termos podem ser atualizados. A versão mais recente fica '
        'sempre disponível no app.',
  ),
];

const politicaDePrivacidade = <SecaoTexto>[
  (
    titulo: 'Dados que coletamos',
    texto:
        'Nome, e-mail e senha (guardada de forma criptografada); para '
        'profissionais, profissão, registro e UF; tratamentos e doses '
        'cadastrados; e receitas enviadas à MIA.',
  ),
  (
    titulo: 'Para que usamos',
    texto:
        'Para organizar seus tratamentos, lembrar seus horários, montar seu '
        'histórico e enviar o código de recuperação de senha por e-mail.',
  ),
  (
    titulo: 'Dados de saúde',
    texto:
        'Informações sobre saúde são dados sensíveis pela LGPD (Lei '
        '13.709/2018) e são usadas apenas para as funções do aplicativo.',
  ),
  (
    titulo: 'Serviços externos',
    texto:
        'O envio de e-mails e a leitura de receitas usam serviços externos. '
        'A receita é enviada a eles apenas para extrair as informações.',
  ),
  (
    titulo: 'Compartilhamento',
    texto:
        'Não vendemos seus dados. Eles só são compartilhados com um '
        'profissional de saúde quando você autorizar.',
  ),
  (
    titulo: 'Segurança',
    texto:
        'A senha é guardada criptografada, a sessão expira automaticamente e, '
        'no celular, o login fica em armazenamento seguro.',
  ),
  (
    titulo: 'Seus direitos',
    texto:
        'Você pode pedir para acessar, corrigir ou excluir seus dados falando '
        'com a equipe do projeto.',
  ),
];
