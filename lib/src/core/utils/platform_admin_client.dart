import 'package:firebase_auth/firebase_auth.dart';

/// E-mails com acesso de operador ao painel /admin **no cliente** (antes/resposta à API).
const _platformAdminEmails = {
  'fabianoeugenio96@gmail.com',
};

/// UIDs Firebase Auth autorizados (manter sincronizado com `ADMIN_UID_LEGACY` em `functions/index.js`).
const _platformAdminUids = <String>{
  '7rNwYcg61hcGgg6IeCRBjSytyBq1',
  'JWiiOV3Q6aZ5vSQSJCybNFmP92H2',
};

/// Se o utilizador atual é administrador da plataforma pelo que o Auth já expõe localmente.
bool isPlatformAdminLocally(User? user) {
  if (user == null) return false;
  if (_platformAdminUids.contains(user.uid)) return true;
  final e = user.email?.trim().toLowerCase();
  if (e != null && _platformAdminEmails.contains(e)) return true;
  return false;
}
