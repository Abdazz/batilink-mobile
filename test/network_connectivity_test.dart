import 'package:flutter_test/flutter_test.dart';
import 'package:batilink_mobile_app/services/auth_service.dart';

void main() {
  test('Test de connectivité réseau', () async {
    print('🔍 Test de connectivité réseau...');

    // Test du diagnostic de connexion
    final diagnosis = await AuthService.diagnoseConnection();
    print('Résultat du diagnostic: $diagnosis');

    switch (diagnosis) {
      case 'DOMAINE_OK':
        print('✅ Le nom de domaine est accessible');
        break;
      case 'IP_DIRECTE_OK':
        print('✅ L\'IP directe est accessible');
        break;
      case 'PAS_DE_CONNEXION_INTERNET':
        print('❌ Pas de connexion Internet');
        break;
      case 'IP_DIRECTE_ECHEC':
        print('❌ Serveur inaccessible');
        break;
      default:
        print('❓ Diagnostic inconnu: $diagnosis');
    }
  });
}
