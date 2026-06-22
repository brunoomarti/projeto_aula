import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool _supabaseTestReady = false;

/// Inicializa Supabase com valores fictícios (sem rede) para widget/integration tests.
Future<void> ensureSupabaseInitializedForTests() async {
  if (_supabaseTestReady) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://test-project.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );
  _supabaseTestReady = true;
}
